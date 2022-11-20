defmodule PapaVisitsWeb.Api.UserControllerTest do
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

    [conn: conn_with_auth, xconn: conn, user_params: params]
  end

  describe "GET /user => show/2" do
    test "given a request, returns current user details", %{conn: conn, user_params: user_params} do
      path = Routes.api_user_path(conn, :show)

      expected_first_name = user_params["first_name"]
      expected_last_name = user_params["last_name"]
      expected_email = user_params["email"]

      assert %{
               "data" => user
             } =
               conn
               |> get(path)
               |> json_response(200)

      assert %{
               "id" => _,
               "first_name" => ^expected_first_name,
               "last_name" => ^expected_last_name,
               "email" => ^expected_email
             } = user

      refute Map.has_key?(user, "password")
      refute Map.has_key?(user, "password_hash")

      # TODO - assert visits once those are wired in
    end

    test "unauthenticated users are not allowed", %{xconn: conn} do
      path = Routes.api_user_path(conn, :show)

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
