defmodule PapaVisitsWebTest do
  use ExUnit.Case

  alias PapaVisits.Test.Support.Clients.Primary
  alias PapaVisits.Test.Support.Clients.Secondary

  alias PapaVisits.Factory

  setup do
    start_supervised!(Primary)
    start_supervised!(Secondary)

    :ok
  end

  setup do
    %{user: %{"id" => _id}} = context = register_user()

    # TODO - add an unregister endpoint, which may or may not be a legit thing

    context
  end

  describe "request_visit/1" do
    test "given valid params the visit is made and returned", %{user: user, token: token} do
      minutes = user["minutes"]
      params = Factory.params_for(:visit_params, minutes: minutes)

      assert {:ok, %{"id" => _}} = Primary.request_visit(params, token)
    end

    test "two concurrent requests will only honor what is in budget", %{user: user, token: token} do
      minutes = user["minutes"]
      params = Factory.params_for(:visit_params, minutes: minutes)

      task_one = Task.async(fn -> Primary.request_visit(params, token) end)
      task_two = Task.async(fn -> Secondary.request_visit(params, token) end)

      result_one = Task.await(task_one)
      result_two = Task.await(task_two)

      assert {:error,
              %{
                "minutes" => ["exceeds budget"]
              }} in [result_one, result_two]

      refute result_one == result_two
    end
  end

  describe "complete_visit/1" do
    setup %{user: papa, token: papa_token} do
      %{visit: visit} = request_visit(papa, papa_token)
      %{user: user, token: token} = register_user()

      [user: user, token: token, visit: visit]
    end

    test "given valid params the visit is completed", %{user: user, token: token, visit: visit} do
      params =
        Factory.params_for(
          :transaction_params,
          visit_id: visit["id"],
          pal_id: user["id"]
        )

      assert {:ok, %{"id" => _}} = Primary.complete_visit(params, token)
    end

    test "two concurrent completions will only honor what completes first", %{
      user: user,
      token: token,
      visit: visit
    } do
      params =
        Factory.params_for(
          :transaction_params,
          visit_id: visit["id"],
          pal_id: user["id"]
        )

      task_one = Task.async(fn -> Primary.complete_visit(params, token) end)
      task_two = Task.async(fn -> Secondary.complete_visit(params, token) end)

      result_one = Task.await(task_one)
      result_two = Task.await(task_two)

      assert {:error,
              %{
                "visit_id" => ["visit not active"]
              }} in [result_one, result_two]

      refute result_one == result_two
    end
  end

  describe "register_user/1" do
    test "given valid params it registers a user" do
      params = Factory.params_for(:user_creation)

      assert {:ok, %{"access_token" => _}} = Primary.register_user(params)
    end
  end

  describe "create_session/1" do
    test "given valid params it creates a session for a user" do
      %{params: params} = register_user()
      login = Map.take(params, [:email, :password])

      assert {:ok, %{"access_token" => _}} = Primary.create_session(login)
    end
  end

  defp request_visit(user, token) do
    minutes = user["minutes"]
    params = Factory.params_for(:visit_params, minutes: minutes)
    {:ok, visit} = Primary.request_visit(params, token)

    %{visit: visit}
  end

  defp register_user do
    params = Factory.params_for(:user_creation)
    {:ok, %{"access_token" => token}} = Primary.register_user(params)
    {:ok, user} = Primary.get_user(token)

    %{
      user: user,
      token: token,
      params: params
    }
  end
end
