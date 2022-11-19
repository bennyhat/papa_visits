defmodule PapaVisitsWeb.Api.SessionControllerTest do
  use PapaVisitsWeb.ConnCase

  describe "POST /session => create/2" do
    setup %{conn: conn} do
      params = Factory.string_params_for(:user_creation, minutes: nil)
      path = Routes.registration_path(conn, :create)

      conn
      |> post(path, params)
      |> json_response(200)

      login = Map.take(params, ["email", "password"])

      [login: login]
    end

    test "given a user with all required fields, creates it", %{conn: conn, login: params} do
      path = Routes.session_path(conn, :create)

      assert %{
               "data" => %{
                 "access_token" => _
               }
             } =
               conn
               |> post(path, params)
               |> json_response(200)
    end

    test "given a user with missing fields, sends error", %{conn: conn} do
      path = Routes.session_path(conn, :create)

      assert %{
               "error" => %{
                 "message" => "Invalid email or password",
                 "status" => 401
               }
             } =
               conn
               |> post(path, %{})
               |> json_response(401)
    end

    test "given a user invalid password, sends error", %{conn: conn, login: params} do
      path = Routes.session_path(conn, :create)
      params = Map.put(params, "password", "wrong")

      assert %{
               "error" => %{
                 "message" => "Invalid email or password",
                 "status" => 401
               }
             } =
               conn
               |> post(path, params)
               |> json_response(401)
    end
  end
end
