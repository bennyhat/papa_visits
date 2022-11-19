defmodule PapaVisitsTest do
  use PapaVisits.DataCase

  alias PapaVisits.Visits.Visit
  alias PapaVisitsWeb.ErrorHelpers

  describe "request_visit/1" do
    test "given valid visit params it creates a visit" do
      minutes = 100
      %{id: member_id} = Factory.insert(:user, minutes: minutes)
      params = Factory.build(:visit_params, user_id: member_id, minutes: minutes)

      assert {:ok, %Visit{status: :requested, user_id: ^member_id, minutes: ^minutes}} =
               PapaVisits.request_visit(params)
    end

    test "given a missing user it reflects that" do
      minutes = 100
      %{id: member_id} = Factory.build(:user, minutes: minutes)
      params = Factory.build(:visit_params, user_id: member_id, minutes: minutes)

      assert {:error, :user_not_found} = PapaVisits.request_visit(params)
    end

    test "given semantically invalid parameters it reflects them" do
      # the idea here is that required fields and casting will have
      # been handled by the params structs
      minutes = 100
      %{id: member_id} = Factory.insert(:user, minutes: minutes)

      params =
        Factory.build(
          :visit_params,
          user_id: member_id,
          minutes: -10,
          date: Faker.Date.backward(1)
        )

      assert {:error, changeset} = PapaVisits.request_visit(params)

      assert %{
               minutes: ["must be greater than 0"],
               date: ["must be at least today"]
             } = Ecto.Changeset.traverse_errors(changeset, &ErrorHelpers.translate_error/1)
    end

    test "given request that exceeds available minutes, returns error" do
      minutes = 100
      requested = 101

      %{id: member_id} = Factory.insert(:user, minutes: minutes)
      params = Factory.build(:visit_params, user_id: member_id, minutes: requested)

      assert {:error, :exceeds_budget} == PapaVisits.request_visit(params)
    end

    test "given request that exceeds available minutes (including current requests), returns error" do
      minutes = 100
      requested = 34

      %{id: member_id} = Factory.insert(:user, minutes: minutes)
      params = Factory.build(:visit_params, user_id: member_id, minutes: requested)

      assert {:ok, _} = PapaVisits.request_visit(params)
      assert {:ok, _} = PapaVisits.request_visit(params)
      assert {:error, :exceeds_budget} == PapaVisits.request_visit(params)
    end

    test "given concurrent requests for all minutes, only one succeeds" do
      minutes = 100
      %{id: member_id} = Factory.insert(:user, minutes: minutes)
      params = Factory.build(:visit_params, user_id: member_id, minutes: minutes)

      task_one = Task.async(fn -> PapaVisits.request_visit(params) end)
      task_two = Task.async(fn -> PapaVisits.request_visit(params) end)

      result_one = Task.await(task_one)
      result_two = Task.await(task_two)

      assert {:error, :exceeds_budget} in [result_one, result_two]
      refute result_one == result_two
    end
  end
end
