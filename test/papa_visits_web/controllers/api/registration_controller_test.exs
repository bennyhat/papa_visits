defmodule PapaVisitsWeb.API.RegistrationControllerTest do
  use PapaVisitsWeb.ConnCase

  describe "POST /registration => create/2" do
    test "given a user with all required fields, creates it", %{conn: conn} do
      params = Factory.string_params_for(:user_creation, minutes: nil)

      path = Routes.registration_path(conn, :create)

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
      params =
        Factory.string_params_for(
          :user_creation,
          minutes: nil,
          password: nil,
          first_name: nil,
          last_name: nil,
          email: nil
        )

      path = Routes.registration_path(conn, :create)

      assert %{
               "error" => %{
                 "errors" => %{
                   "email" => ["can't be blank"],
                   "first_name" => ["can't be blank"],
                   "last_name" => ["can't be blank"],
                   "password" => ["can't be blank"]
                 },
                 "message" => "Couldn't create user",
                 "status" => 500
               }
             } =
               conn
               |> post(path, params)
               |> json_response(500)
    end

    test "given a user with invalid fields, sends error", %{conn: conn} do
      params =
        Factory.string_params_for(
          :user_creation,
          minutes: nil,
          password: "easy",
          email: "not-an-email"
        )

      path = Routes.registration_path(conn, :create)

      assert %{
               "error" => %{
                 "errors" => %{
                   "email" => ["has invalid format"],
                   "password" => ["should be at least 8 character(s)"]
                 },
                 "message" => "Couldn't create user",
                 "status" => 500
               }
             } =
               conn
               |> post(path, params)
               |> json_response(500)
    end
  end
end
