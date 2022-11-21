defmodule PapaVisitsWebTest do
  use ExUnit.Case

  alias PapaVisits.Test.Support.Clients.Cleanup
  alias PapaVisits.Test.Support.Clients.Primary
  alias PapaVisits.Test.Support.Clients.Secondary

  alias PapaVisits.Factory

  setup do
    start_supervised(Primary)
    start_supervised(Secondary)

    :ok
  end

  setup do
    %{token: token} = context = register_user()

    on_exit(fn ->
      unregister_user!(token)
    end)

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
      %{visit: visit} = request_visit!(papa, papa_token)
      %{token: pal_token} = register_user()

      on_exit(fn ->
        unregister_user!(pal_token)
      end)

      [token: pal_token, visit: visit]
    end

    test "given valid params the visit is completed", %{token: token, visit: visit} do
      assert {:ok, %{"id" => _}} = Primary.complete_visit(visit["id"], token)
    end

    test "two concurrent completions will only honor what completes first", %{
      token: token,
      visit: visit
    } do
      task_one = Task.async(fn -> Primary.complete_visit(visit["id"], token) end)
      task_two = Task.async(fn -> Secondary.complete_visit(visit["id"], token) end)

      result_one = Task.await(task_one)
      result_two = Task.await(task_two)

      assert {:error,
              %{
                "visit_id" => ["visit not active"]
              }} in [result_one, result_two]

      refute result_one == result_two
    end
  end

  describe "request and complete visit race conditions" do
    @visit_count 6

    setup do
      %{token: papa_token, user: papa_user} = register_user()
      %{token: pal_token} = register_user()

      on_exit(fn ->
        unregister_user!(papa_token)
      end)

      on_exit(fn ->
        unregister_user!(pal_token)
      end)

      minutes = papa_user["minutes"]

      visit_minutes = minutes / @visit_count
      assert visit_minutes == Float.round(visit_minutes)
      visit_minutes = round(visit_minutes)

      visits =
        for _i <- Range.new(1, @visit_count) do
          %{visit: visit} = request_visit!(%{"minutes" => visit_minutes}, papa_token)
          visit
        end

      [
        papa_token: papa_token,
        pal_token: pal_token,
        visits: visits
      ]
    end

    for placement <- Range.new(1, @visit_count) do
      test "a visit requested in the midst of completions does not slip in. Placement: #{placement}",
           %{
             papa_token: papa_token,
             pal_token: pal_token,
             visits: visits
           } do
        request_placement = unquote(placement) - 1
        [minutes_config | _] = visits

        request_function = fn ->
          request_visit(minutes_config, papa_token, Primary)
        end

        completion_functions =
          for {visit, index} <- Enum.with_index(visits) do
            fn ->
              client = Enum.at([Primary, Secondary], rem(index, 2))
              complete_visit(visit, pal_token, client)
            end
          end

        functions = List.insert_at(completion_functions, request_placement, request_function)

        tasks =
          for function <- functions do
            Task.async(function)
          end

        results =
          for task <- tasks do
            Task.await(task)
          end

        expected_request_error =
          {:error,
           %{
             "minutes" => ["exceeds budget"]
           }}

        assert expected_request_error in results
        assert Enum.count(tasks) == Enum.count(Enum.uniq(results))

        results = List.delete(results, expected_request_error)

        assert Enum.all?(results, fn result ->
                 match?(
                   {:ok, _},
                   result
                 )
               end)

        assert {:ok, %{"minutes" => 0}} = Primary.get_user(papa_token)
      end
    end
  end

  describe "register_user/1" do
    test "given valid params it registers a user" do
      params = Factory.params_for(:user_creation)

      assert {:ok, %{"access_token" => token}} = Primary.register_user(params)

      unregister_user!(token)
    end
  end

  describe "create_session/1" do
    test "given valid params it creates a session for a user" do
      %{params: params, token: token} = register_user()

      on_exit(fn ->
        unregister_user!(token)
      end)

      login = Map.take(params, [:email, :password])

      assert {:ok, %{"access_token" => _}} = Primary.create_session(login)
    end
  end

  defp request_visit!(user, token) do
    {:ok, visit} = request_visit(user, token)

    %{visit: visit}
  end

  defp request_visit(user, token, client \\ Primary) do
    minutes = user["minutes"]
    params = Factory.params_for(:visit_params, minutes: minutes)
    client.request_visit(params, token)
  end

  defp complete_visit(visit, token, client) do
    client.complete_visit(visit["id"], token)
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

  defp unregister_user!(token) do
    {:ok, exit_supervisor} = Supervisor.start_link([], strategy: :one_for_one)
    child_spec = Supervisor.child_spec(Cleanup, [])

    case Supervisor.start_child(exit_supervisor, child_spec) do
      {:error, {:already_started, _pid}} ->
        :ok

      {:error, {{:already_started, _pid}, _}} ->
        :ok

      {:error, error} ->
        raise "Unable to start supervisor for test client #{inspect(error)} - database will need some cleaning"

      other ->
        other
    end

    case Cleanup.unregister_user(token) do
      {:ok, _} ->
        :ok

      other ->
        raise "Unable to unregister user: #{inspect(other)} - database will need some cleaning"
    end
  end
end
