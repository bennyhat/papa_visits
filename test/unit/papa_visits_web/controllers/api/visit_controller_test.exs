defmodule PapaVisitsWeb.Api.VisitControllerTest do
  use PapaVisitsWeb.ConnCase
  import Assertions

  def user_and_conn(%{conn: conn}) do
    params = Factory.string_params_for(:user_creation)
    path = Routes.api_auth_registration_path(conn, :create)

    %{
      "data" => %{
        "access_token" => token
      }
    } =
      conn
      |> post(path, params)
      |> json_response(200)

    conn_with_auth = put_req_header(conn, "authorization", token)

    user_path = Routes.api_user_path(conn, :show)

    %{"data" => user} =
      conn_with_auth
      |> get(user_path)
      |> json_response(200)

    %{conn: conn_with_auth, xconn: conn, user: user}
  end

  setup :user_and_conn

  # TODO - drive in that token must match pal_id
  # TODO - actually just drive in having the pal_id be from the header
  describe "PUT /visit/:id/complete => update_completed/2" do
    setup %{conn: papa_conn, user: papa_user} do
      %{user: pal_user} = user_and_conn(%{conn: papa_conn})

      params =
        Factory.string_params_for(:visit_params, minutes: papa_user["minutes"], user_id: nil)

      path = Routes.api_visit_path(papa_conn, :create)

      assert %{"data" => visit} =
               papa_conn
               |> post(path, params)
               |> json_response(200)

      %{pal_user: pal_user, visit: visit}
    end

    test "given a valid request it completes the visit", %{
      conn: conn,
      user: papa_user,
      pal_user: pal_user,
      visit: visit
    } do
      params =
        Factory.string_params_for(
          :transaction_params,
          visit_id: visit["id"],
          pal_id: pal_user["id"]
        )

      path = Routes.api_visit_path(conn, :update_completed, params["visit_id"])

      expected_visit_id = visit["id"]
      expected_pal_id = pal_user["id"]
      expected_papa_id = papa_user["id"]
      expected_pal_minutes = round(pal_user["minutes"] + visit["minutes"] * 0.85)
      expected_papa_minutes = papa_user["minutes"] - visit["minutes"]

      assert %{
               "data" => %{
                 "id" => _,
                 "pal" => %{
                   "id" => ^expected_pal_id,
                   "minutes" => ^expected_pal_minutes
                 },
                 "visit" => %{
                   "id" => ^expected_visit_id,
                   "user" => %{
                     "id" => ^expected_papa_id,
                     "minutes" => ^expected_papa_minutes
                   }
                 }
               }
             } =
               conn
               |> put(path, params)
               |> json_response(200)
    end

    test "given syntactically invalid data it indicates that", %{conn: conn} do
      params =
        Factory.string_params_for(
          :transaction_params,
          visit_id: "not-a-uuid",
          pal_id: nil
        )

      path = Routes.api_visit_path(conn, :update_completed, params["visit_id"])

      assert %{
               "error" => %{
                 "status" => 422,
                 "message" => "Parameter validation failed.",
                 "errors" => %{
                   "visit_id" => ["is invalid"],
                   "pal_id" => ["can't be blank"]
                 }
               }
             } =
               conn
               |> put(path, params)
               |> json_response(422)
    end

    test "given semantically invalid data it indicates that", %{conn: conn} do
      params =
        Factory.string_params_for(
          :transaction_params,
          visit_id: Faker.UUID.v4()
        )

      path = Routes.api_visit_path(conn, :update_completed, params["visit_id"])

      assert %{
               "error" => %{
                 "status" => 422,
                 "message" => "Validation failed.",
                 "errors" => %{
                   "visit_id" => ["visit not found"]
                 }
               }
             } =
               conn
               |> put(path, params)
               |> json_response(422)
    end
  end

  describe "POST /visit => create/2" do
    test "given valid visit params, creates visit", %{conn: conn, user: user} do
      params = Factory.string_params_for(:visit_params, minutes: user["minutes"], user_id: nil)
      path = Routes.api_visit_path(conn, :create)

      expected_user_id = user["id"]

      expected_date =
        to_string(%Date{
          day: params["date"]["day"],
          month: params["date"]["month"],
          year: params["date"]["year"]
        })

      expected_tasks = params["tasks"]
      expected_minutes = params["minutes"]
      expected_status = "requested"

      assert %{
               "data" => %{
                 "id" => _,
                 "date" => ^expected_date,
                 "tasks" => actual_tasks,
                 "minutes" => ^expected_minutes,
                 "status" => ^expected_status,
                 "user" => %{
                   "id" => ^expected_user_id
                 }
               }
             } =
               conn
               |> post(path, params)
               |> json_response(200)

      assert Enum.count(expected_tasks) == Enum.count(actual_tasks)

      for expected_task <- expected_tasks do
        comparison = fn a, b ->
          name = a["name"]
          description = a["description"]

          match?(
            %{
              "id" => _,
              "name" => ^name,
              "description" => ^description
            },
            b
          )
        end

        assert_map_in_list(expected_task, actual_tasks, comparison)
      end
    end

    test "given syntactic validation failures, reflects those", %{conn: conn} do
      params =
        Factory.string_params_for(
          :visit_params,
          user_id: nil,
          minutes: "-A",
          date: "not-a-date",
          tasks: [%{"missing" => "name"}]
        )

      path = Routes.api_visit_path(conn, :create)

      assert %{
               "error" => %{
                 "status" => 422,
                 "message" => "Parameter validation failed.",
                 "errors" => %{
                   "minutes" => ["is invalid"],
                   "date" => ["is invalid"],
                   "tasks" => [
                     %{
                       "name" => ["can't be blank"]
                     }
                   ]
                 }
               }
             } =
               conn
               |> post(path, params)
               |> json_response(422)
    end

    test "given semantic validation failure reflects those errors", %{conn: conn, user: user} do
      exceeding_minutes = user["minutes"] + 1
      params = Factory.string_params_for(:visit_params, minutes: exceeding_minutes, user_id: nil)
      path = Routes.api_visit_path(conn, :create)

      assert %{
               "error" => %{
                 "status" => 422,
                 "message" => "Validation failed.",
                 "errors" => %{
                   "minutes" => ["exceeds budget"]
                 }
               }
             } =
               conn
               |> post(path, params)
               |> json_response(422)
    end

    test "unauthenticated users are not allowed", %{xconn: conn, user: user} do
      params = Factory.string_params_for(:visit_params, minutes: user["minutes"], user_id: nil)
      path = Routes.api_visit_path(conn, :create)

      assert %{
               "error" => %{
                 "status" => 401,
                 "message" => "Not authenticated"
               }
             } =
               conn
               |> post(path, params)
               |> json_response(401)
    end
  end

  describe "GET /visit => index/2" do
    setup do
      users = Factory.insert_list(3, :user, minutes: 1_000_000)

      requested_visits =
        for papa <- users do
          Factory.insert(:visit, user: papa, minutes: 10, status: :requested)
        end

      completed_visits =
        for papa <- users do
          Factory.insert(:visit, user: papa, minutes: 10, status: :completed)
        end

      [
        users: users,
        visits: requested_visits ++ completed_visits,
        requested_visits: requested_visits,
        completed_visits: completed_visits
      ]
    end

    test "given a request with no params, returns all visits", %{conn: conn, visits: visits} do
      path = Routes.api_visit_path(conn, :index)

      expected_visits = Enum.sort_by(visits, &Map.get(&1, :date), Date)
      expected_visit_ids = for v <- expected_visits, do: v.id
      expected_user_ids = for v <- expected_visits, do: v.user.id
      expected_task_ids = for v <- expected_visits, t <- v.tasks, do: t.id

      assert %{
               "data" => actual_visits
             } =
               conn
               |> get(path)
               |> json_response(200)

      actual_visit_ids = for v <- actual_visits, do: v["id"]
      actual_user_ids = for v <- actual_visits, do: get_in(v, ["user", "id"])
      actual_task_ids = for v <- actual_visits, t <- v["tasks"], do: t["id"]

      assert expected_visit_ids == actual_visit_ids
      assert expected_user_ids == actual_user_ids
      assert Enum.sort(expected_task_ids) == Enum.sort(actual_task_ids)
    end

    test "properly passes along filter params", %{conn: conn, users: users} do
      %{id: user_id, visits: visits} =
        users
        |> Enum.random()
        |> PapaVisits.Repo.preload([:visits])

      %{status: status} = Enum.random(visits)

      path = Routes.api_visit_path(conn, :index, user_id: user_id, status: status)

      assert %{
               "data" => [actual_visit]
             } =
               conn
               |> get(path)
               |> json_response(200)

      assert user_id == get_in(actual_visit, ["user", "id"])
      assert to_string(status) == actual_visit["status"]
    end

    test "unauthenticated users are not allowed", %{xconn: conn} do
      path = Routes.api_visit_path(conn, :index)

      assert %{
               "error" => %{
                 "status" => 401,
                 "message" => "Not authenticated"
               }
             } =
               conn
               |> get(path)
               |> json_response(401)
    end
  end
end
