defmodule PapaVisitsWeb.Api.VisitControllerTest do
  use PapaVisitsWeb.ConnCase

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

    [conn: conn_with_auth, xconn: conn]
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

    test "unauthenticated users are not authorized", %{xconn: conn} do
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