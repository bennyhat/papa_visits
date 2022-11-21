defmodule PapaVisitsWeb.Api.Auth.RegistrationControllerTest do
  use PapaVisitsWeb.ConnCase

  describe "POST /auth/registration => create/2" do
    test "given a user with all required fields, creates it", %{conn: conn} do
      params = Factory.string_params_for(:user_creation)

      path = Routes.api_auth_registration_path(conn, :create)

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
          password: nil,
          first_name: nil,
          last_name: nil,
          email: nil
        )

      path = Routes.api_auth_registration_path(conn, :create)

      assert %{
               "error" => %{
                 "errors" => %{
                   "email" => ["can't be blank"],
                   "first_name" => ["can't be blank"],
                   "last_name" => ["can't be blank"],
                   "password" => ["can't be blank"]
                 },
                 "message" => "Validation failed.",
                 "status" => 422
               }
             } =
               conn
               |> post(path, params)
               |> json_response(422)
    end

    test "given a user with invalid fields, sends error", %{conn: conn} do
      params =
        Factory.string_params_for(
          :user_creation,
          password: "easy",
          email: "not-an-email"
        )

      path = Routes.api_auth_registration_path(conn, :create)

      assert %{
               "error" => %{
                 "errors" => %{
                   "email" => ["has invalid format"],
                   "password" => ["should be at least 8 character(s)"]
                 },
                 "message" => "Validation failed.",
                 "status" => 422
               }
             } =
               conn
               |> post(path, params)
               |> json_response(422)
    end

    test "given a user with duplicate email, makes that obvious", %{conn: conn} do
      %{email: existing_email} = Factory.insert(:user)

      params =
        Factory.params_for(
          :user_creation,
          email: existing_email
        )

      path = Routes.api_auth_registration_path(conn, :create)

      assert %{
               "error" => %{
                 "errors" => %{
                   "email" => ["has already been taken"]
                 },
                 "message" => "Validation failed.",
                 "status" => 422
               }
             } =
               conn
               |> post(path, params)
               |> json_response(422)
    end
  end

  describe "DELETE /auth/registration => delete/2" do
    setup %{conn: conn} do
      pal_conn = create_user(conn)
      papa_conn = create_user(conn)

      papa = get_user(papa_conn)
      pal = get_user(pal_conn)

      visit = request_visit(papa_conn, papa)
      transaction = complete_visit(pal_conn, visit, pal)

      [
        papa_conn: papa_conn,
        pal_conn: pal_conn,
        visit: visit,
        transaction: transaction
      ]
    end

    test "deregistering only deletes things that belong to the papa", %{
      papa_conn: conn,
      pal_conn: pal_conn,
      visit: visit,
      transaction: tx
    } do
      path = Routes.api_auth_registration_path(conn, :delete)

      assert get_user(conn)
      assert get_visit(conn, visit["id"])
      assert get_transaction(conn, tx["id"])

      assert %{"data" => "success"} =
               conn
               |> delete(path)
               |> json_response(200)

      refute get_user(conn)
      refute get_visit(pal_conn, visit["id"])
      refute get_transaction(pal_conn, tx["id"])
    end

    test "deregistering a pal does not delete visits they transacted on", %{
      pal_conn: conn,
      papa_conn: papa_conn,
      visit: visit,
      transaction: tx
    } do
      path = Routes.api_auth_registration_path(conn, :delete)
      visit_id = visit["id"]

      assert get_user(conn)
      assert get_visit(conn, visit_id)
      assert get_transaction(conn, tx["id"])

      assert %{"data" => "success"} =
               conn
               |> delete(path)
               |> json_response(200)

      refute get_user(conn)
      assert get_visit(papa_conn, visit_id)
      assert %{visit_id: ^visit_id, pal_id: nil} = get_transaction(papa_conn, tx["id"])
    end
  end

  defp create_user(conn) do
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

    put_req_header(conn, "authorization", token)
  end

  defp get_user(conn) do
    path = Routes.api_user_path(conn, :show)

    conn
    |> get(path)
    |> handle_user_response()
  end

  defp handle_user_response(%{status: status} = response) do
    response
    |> json_response(status)
    |> handle_user()
  end

  defp handle_user(%{"data" => user}), do: user
  defp handle_user(_), do: nil

  defp request_visit(conn, user) do
    path = Routes.api_visit_path(conn, :create)
    params = Factory.string_params_for(:visit_params, minutes: user["minutes"], user_id: nil)

    %{"data" => visit} =
      conn
      |> post(path, params)
      |> json_response(200)

    visit
  end

  defp complete_visit(conn, visit, pal) do
    params =
      Factory.string_params_for(
        :transaction_params,
        visit_id: visit["id"],
        pal_id: pal["id"]
      )

    path = Routes.api_visit_path(conn, :update_completed, params["visit_id"])

    %{"data" => transaction} =
      conn
      |> put(path, params)
      |> json_response(200)

    transaction
  end

  defp get_visit(_conn, id) do
    # until there is an endpoint for this just use repo
    PapaVisits.Repo.get(PapaVisits.Visits.Visit, id)
  end

  defp get_transaction(_conn, id) do
    # until there is an endpoint for this just use repo
    PapaVisits.Repo.get(PapaVisits.Visits.Transaction, id)
  end
end
