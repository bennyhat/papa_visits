defmodule PapaVisitsTest do
  use PapaVisits.DataCase

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
          papa_id: papa.id,
          pal_id: pal.id,
          visit_id: visit.id
        )

      expected_pal_minutes = round(pal.minutes + visit.minutes * 0.85)
      expected_papa_minutes = papa.minutes - visit.minutes

      assert {:ok,
              %Transaction{
                papa: %{minutes: ^expected_papa_minutes},
                pal: %{minutes: ^expected_pal_minutes},
                visit: %{status: :completed}
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
          papa_id: papa.id,
          pal_id: pal.id,
          visit_id: visit.id
        )

      expected_pal_minutes = round(pal.minutes + visit.minutes * 0.85)

      assert {:ok,
              %Transaction{
                pal: %{minutes: ^expected_pal_minutes},
                visit: %{status: :completed}
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
          papa_id: papa.id,
          pal_id: pal.id,
          visit_id: visit.id
        )

      expected_pal_minutes = round(pal.minutes + visit.minutes * 0.85)

      assert {:ok,
              %Transaction{
                pal: %{minutes: ^expected_pal_minutes},
                visit: %{status: :completed}
              }} = PapaVisits.complete_visit(params)
    end

    test "given concurrent completions of same transaction, rejects one", %{
      visit: visit,
      papa: papa,
      pal: pal
    } do
      params =
        Factory.build(
          :transaction_params,
          papa_id: papa.id,
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
      papa: papa,
      pal: pal
    } do
      params =
        Factory.build(
          :transaction_params,
          papa_id: papa.id,
          pal_id: pal.id,
          visit_id: visit.id
        )

      assert {:ok, _} = PapaVisits.complete_visit(params)

      assert %{
               visit_id: ["visit not active"]
             } = convert_error(PapaVisits.complete_visit(params))
    end

    test "given a missing pal, it rejects it", %{papa: papa, visit: visit} do
      pal = Factory.build(:user)

      params =
        Factory.build(
          :transaction_params,
          papa_id: papa.id,
          pal_id: pal.id,
          visit_id: visit.id
        )

      assert %{
               pal_id: ["pal not found"]
             } = convert_error(PapaVisits.complete_visit(params))
    end

    test "given a missing papa, it rejects it", %{pal: pal, visit: visit} do
      papa = Factory.build(:user)

      params =
        Factory.build(
          :transaction_params,
          papa_id: papa.id,
          pal_id: pal.id,
          visit_id: visit.id
        )

      assert %{
               papa_id: ["papa not found"]
             } = convert_error(PapaVisits.complete_visit(params))
    end

    test "given a missing visit, it rejects it", %{pal: pal, papa: papa} do
      visit = Factory.build(:visit)

      params =
        Factory.build(
          :transaction_params,
          papa_id: papa.id,
          pal_id: pal.id,
          visit_id: visit.id
        )

      assert %{
               visit_id: ["visit not found"]
             } = convert_error(PapaVisits.complete_visit(params))
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
