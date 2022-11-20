defmodule PapaVisitsTest do
  use PapaVisits.DataCase

  alias PapaVisits.Params.VisitFilter, as: VisitFilterParams
  alias PapaVisits.Visits.Visit
  alias PapaVisits.Visits.Transaction
  alias PapaVisitsWeb.ErrorHelpers

  describe "request_visit/1" do
    setup do
      member = Factory.insert(:user, minutes: 100)

      [member: member]
    end

    test "given valid visit params it creates a visit", %{member: member} do
      member_id = member.id
      minutes = member.minutes
      params = Factory.build(:visit_params, user_id: member_id, minutes: minutes)

      assert {:ok, %Visit{status: :requested, user_id: ^member_id, minutes: ^minutes}} =
               PapaVisits.request_visit(params)
    end

    test "given a missing user it reflects that" do
      minutes = 100
      %{id: member_id} = Factory.build(:user, minutes: minutes)
      params = Factory.build(:visit_params, user_id: member_id, minutes: minutes)

      assert %{
               user_id: ["user not found"]
             } = convert_error(PapaVisits.request_visit(params))
    end

    test "given semantically invalid parameters it reflects them", %{member: member} do
      # the idea here is that required fields and casting will have
      # been handled by the params structs
      params =
        Factory.build(
          :visit_params,
          user_id: member.id,
          minutes: -10,
          date: Faker.Date.backward(1)
        )

      assert %{
               minutes: ["must be greater than 0"],
               date: ["must be at least today"]
             } = convert_error(PapaVisits.request_visit(params))
    end

    test "given request that exceeds available minutes, returns error", %{member: member} do
      requested = member.minutes + 1

      params = Factory.build(:visit_params, user_id: member.id, minutes: requested)

      assert %{
               minutes: ["exceeds budget"]
             } = convert_error(PapaVisits.request_visit(params))
    end

    test "given request that exceeds available minutes (including current requests), returns error",
         %{member: member} do
      requested = Integer.floor_div(member.minutes, 3) + 1

      params = Factory.build(:visit_params, user_id: member.id, minutes: requested)

      assert {:ok, _} = PapaVisits.request_visit(params)
      assert {:ok, _} = PapaVisits.request_visit(params)

      assert %{
               minutes: ["exceeds budget"]
             } = convert_error(PapaVisits.request_visit(params))
    end

    test "given concurrent requests for all minutes, only one succeeds", %{member: member} do
      params = Factory.build(:visit_params, user_id: member.id, minutes: member.minutes)

      task_one = Task.async(fn -> PapaVisits.request_visit(params) end)
      task_two = Task.async(fn -> PapaVisits.request_visit(params) end)

      result_one = Task.await(task_one)
      result_two = Task.await(task_two)

      assert %{
               minutes: ["exceeds budget"]
             } in convert_errors([result_one, result_two])

      refute result_one == result_two
    end
  end

  describe "complete_visit/1" do
    setup do
      %{id: papa_id} = papa = Factory.insert(:user, minutes: 100)
      params = Factory.build(:visit_params, user_id: papa_id, minutes: 100)

      pal = Factory.insert(:user, minutes: 100)

      {:ok, visit} = PapaVisits.request_visit(params)

      [visit: visit, papa: papa, pal: pal]
    end

    test "given valid transaction parameters it transfers minutes", %{
      visit: visit,
      papa: papa,
      pal: pal
    } do
      params =
        Factory.build(
          :transaction_params,
          pal_id: pal.id,
          visit_id: visit.id
        )

      expected_pal_minutes = round(pal.minutes + visit.minutes * 0.85)
      expected_papa_minutes = papa.minutes - visit.minutes

      assert {:ok,
              %Transaction{
                pal: %{minutes: ^expected_pal_minutes},
                visit: %{
                  status: :completed,
                  user: %{minutes: ^expected_papa_minutes}
                }
              }} = PapaVisits.complete_visit(params)
    end

    test "given non-integer overhead removal it rounds (down)", %{
      pal: pal
    } do
      minutes_that_will_round_down = 33
      papa = Factory.insert(:user, minutes: 100)

      request_params =
        Factory.build(:visit_params, user_id: papa.id, minutes: minutes_that_will_round_down)

      {:ok, visit} = PapaVisits.request_visit(request_params)

      params =
        Factory.build(
          :transaction_params,
          pal_id: pal.id,
          visit_id: visit.id
        )

      expected_pal_minutes = round(pal.minutes + visit.minutes * 0.85)

      assert {:ok,
              %Transaction{
                pal: %{minutes: ^expected_pal_minutes}
              }} = PapaVisits.complete_visit(params)
    end

    test "given non-integer overhead removal it rounds (up)", %{
      pal: pal
    } do
      minutes_that_will_round_up = 35
      papa = Factory.insert(:user, minutes: 100)

      request_params =
        Factory.build(:visit_params, user_id: papa.id, minutes: minutes_that_will_round_up)

      {:ok, visit} = PapaVisits.request_visit(request_params)

      params =
        Factory.build(
          :transaction_params,
          pal_id: pal.id,
          visit_id: visit.id
        )

      expected_pal_minutes = round(pal.minutes + visit.minutes * 0.85)

      assert {:ok,
              %Transaction{
                pal: %{minutes: ^expected_pal_minutes}
              }} = PapaVisits.complete_visit(params)
    end

    test "given concurrent completions of same transaction, rejects one", %{
      visit: visit,
      pal: pal
    } do
      params =
        Factory.build(
          :transaction_params,
          pal_id: pal.id,
          visit_id: visit.id
        )

      task_one = Task.async(fn -> PapaVisits.complete_visit(params) end)
      task_two = Task.async(fn -> PapaVisits.complete_visit(params) end)

      result_one = Task.await(task_one)
      result_two = Task.await(task_two)

      assert %{
               visit_id: ["visit not active"]
             } in convert_errors([result_one, result_two])

      refute result_one == result_two
    end

    test "given already complete visit, it rejects it", %{
      visit: visit,
      pal: pal
    } do
      params =
        Factory.build(
          :transaction_params,
          pal_id: pal.id,
          visit_id: visit.id
        )

      assert {:ok, _} = PapaVisits.complete_visit(params)

      assert %{
               visit_id: ["visit not active"]
             } = convert_error(PapaVisits.complete_visit(params))
    end

    test "given a missing pal, it rejects it", %{visit: visit} do
      pal = Factory.build(:user)

      params =
        Factory.build(
          :transaction_params,
          pal_id: pal.id,
          visit_id: visit.id
        )

      assert %{
               pal_id: ["pal not found"]
             } = convert_error(PapaVisits.complete_visit(params))
    end

    test "given a missing visit, it rejects it", %{pal: pal} do
      visit = Factory.build(:visit)

      params =
        Factory.build(
          :transaction_params,
          pal_id: pal.id,
          visit_id: visit.id
        )

      assert %{
               visit_id: ["visit not found"]
             } = convert_error(PapaVisits.complete_visit(params))
    end
  end

  describe "list_visits/1" do
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

    test "given no filters, returns all visits, ordered by closest date", %{visits: visits} do
      params = %VisitFilterParams{}

      # verifying ordering and preloads
      expected_visits = Enum.sort_by(visits, &Map.get(&1, :date), Date)
      expected_visit_ids = for v <- expected_visits, do: v.id
      expected_user_ids = for v <- expected_visits, do: v.user.id
      expected_task_ids = for v <- expected_visits, t <- v.tasks, do: t.id

      assert actual_visits = PapaVisits.list_visits(params)

      actual_visit_ids = for v <- actual_visits, do: v.id
      actual_user_ids = for v <- actual_visits, do: v.user.id
      actual_task_ids = for v <- actual_visits, t <- v.tasks, do: t.id

      assert expected_visit_ids == actual_visit_ids
      assert expected_user_ids == actual_user_ids
      assert Enum.sort(expected_task_ids) == Enum.sort(actual_task_ids)
    end

    test "given a user id filter, returns only visits for that user", %{users: users} do
      for user <- users do
        params = %VisitFilterParams{user_id: user.id}

        %{visits: visits} = PapaVisits.Repo.preload(user, [:visits])
        expected_visit_ids = for v <- visits, do: v.id

        assert actual_visits = PapaVisits.list_visits(params)

        actual_visit_ids = for v <- actual_visits, do: v.id

        assert Enum.sort(expected_visit_ids) == Enum.sort(actual_visit_ids)
      end
    end

    test "given a status filter, returns only visits for that status", %{visits: visits} do
      for status <- [:completed, :requested] do
        params = %VisitFilterParams{status: status}

        expected_visit_ids = for v <- visits, v.status == status, do: v.id

        assert actual_visits = PapaVisits.list_visits(params)

        actual_visit_ids = for v <- actual_visits, do: v.id

        assert Enum.sort(expected_visit_ids) == Enum.sort(actual_visit_ids)
      end
    end

    test "given all filters, returns applicable results", %{users: users} do
      for user <- users do
        for status <- [:completed, :requested] do
          params = %VisitFilterParams{user_id: user.id, status: status}

          %{visits: visits} = PapaVisits.Repo.preload(user, [:visits])
          expected_visit_ids = for v <- visits, v.status == status, do: v.id

          assert actual_visits = PapaVisits.list_visits(params)

          actual_visit_ids = for v <- actual_visits, do: v.id

          assert Enum.sort(expected_visit_ids) == Enum.sort(actual_visit_ids)
        end
      end
    end

    test "given filters that return no results, returns empty list" do
      params = %VisitFilterParams{user_id: Faker.UUID.v4()}

      assert [] == PapaVisits.list_visits(params)
    end
  end

  defp convert_errors(results) do
    Enum.map(results, &convert_error/1)
  end

  defp convert_error({:error, %Ecto.Changeset{} = changeset}) do
    Ecto.Changeset.traverse_errors(changeset, &ErrorHelpers.translate_error/1)
  end

  defp convert_error(other), do: other
end
