defmodule PapaVisitsWeb.Api.AuthPlugTest do
  use PapaVisitsWeb.ConnCase
  import Assertions

  alias PapaVisitsWeb.Api.AuthPlug

  @plug_config [
    otp_app: :papa_visits,
    token_namespace: "test_token_namespace"
  ]

  describe "create/3" do
    test "given a user with an id, generates an access token", %{conn: conn} do
      %{id: id} = user = Factory.build(:user)

      assert {%{private: %{access_token: token}}, ^user} =
               AuthPlug.create(conn, user, @plug_config)

      assert {:ok, ^id} =
               Phoenix.Token.verify(
                 PapaVisitsWeb.Endpoint,
                 @plug_config[:token_namespace],
                 token
               )
    end
  end

  describe "fetch/2" do
    test "given no token, sets user to nil", %{conn: conn} do
      assert {_conn, nil} = AuthPlug.fetch(conn, @plug_config)
    end

    test "given a user, but one who doesn't exist, sets user to nil", %{conn: conn} do
      user = Factory.build(:user)

      assert {%{private: %{access_token: token}}, _user} =
               AuthPlug.create(conn, user, @plug_config)

      assert {_conn, nil} =
               conn
               |> put_req_header("authorization", token)
               |> AuthPlug.fetch(@plug_config)
    end

    test "given an existing user in the token, sets it", %{conn: conn} do
      user = Factory.insert(:user)

      assert {%{private: %{access_token: token}}, _user} =
               AuthPlug.create(conn, user, @plug_config)

      assert {_conn, ^user} =
               conn
               |> put_req_header("authorization", token)
               |> AuthPlug.fetch(@plug_config)
    end

    test "given a token not signed by us, sets user to nil", %{conn: conn} do
      user = Factory.insert(:user)

      token =
        Phoenix.Token.sign(
          "some_other_secret_string_that_has_to_be_really_long",
          "some_other_namespace",
          user.id
        )

      assert {_conn, nil} =
               conn
               |> put_req_header("authorization", token)
               |> AuthPlug.fetch(@plug_config)
    end

    test "given a non-phoenix token, sets user to nil", %{conn: conn} do
      assert {_conn, nil} =
               conn
               |> put_req_header("authorization", "1234567890")
               |> AuthPlug.fetch(@plug_config)
    end

    test "given token that has maxed out in age, sets user to nil", %{conn: conn} do
      max_age = 1
      plug_config = Keyword.put(@plug_config, :token_max_age, max_age)
      user = Factory.insert(:user)

      assert {%{private: %{access_token: token}}, _user} =
               AuthPlug.create(conn, user, plug_config)

      timeout = max_age * 2 * 1_000
      # this will spin in failure faster but it pauses tests less
      sleep = 200

      assert_async(timeout: timeout, sleep_time: sleep) do
        assert {_conn, nil} =
                 conn
                 |> put_req_header("authorization", token)
                 |> AuthPlug.fetch(plug_config)
      end
    end
  end
end
