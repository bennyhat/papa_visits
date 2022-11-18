defmodule PapaVisitsWeb.ApiAuthPlugTest do
  use PapaVisitsWeb.ConnCase

  alias PapaVisitsWeb.ApiAuthPlug

  @plug_config [otp_app: :papa_visits]

  describe "create/3" do
    test "given a user with an id, generates an access token", %{conn: conn} do
      user = Factory.build(:user)

      assert {%{private: %{access_token: _token}}, ^user} =
               ApiAuthPlug.create(conn, user, @plug_config)
    end
  end

  describe "fetch/2" do
    test "given no token, sets user to nil", %{conn: conn} do
      assert {_conn, nil} = ApiAuthPlug.fetch(conn, @plug_config)
    end

    test "given a user, but one who doesn't exist, sets user to nil", %{conn: conn} do
      user = Factory.build(:user)

      assert {%{private: %{access_token: token}}, _user} =
               ApiAuthPlug.create(conn, user, @plug_config)

      assert {_conn, nil} =
               conn
               |> put_req_header("authorization", token)
               |> ApiAuthPlug.fetch(@plug_config)
    end

    test "given an existing user in the token, sets it", %{conn: conn} do
      user = Factory.insert(:user)

      assert {%{private: %{access_token: token}}, _user} =
               ApiAuthPlug.create(conn, user, @plug_config)

      assert {_conn, ^user} =
               conn
               |> put_req_header("authorization", token)
               |> ApiAuthPlug.fetch(@plug_config)
    end
  end
end
