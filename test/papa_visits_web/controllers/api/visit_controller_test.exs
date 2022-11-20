defmodule PapaVisitsWeb.Api.VisitControllerTest do
  use PapaVisitsWeb.ConnCase
  import Assertions

  setup %{conn: conn} do
    params = Factory.string_params_for(:user_creation, minutes: nil)
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

    [conn: conn_with_auth, xconn: conn, user: user]
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
