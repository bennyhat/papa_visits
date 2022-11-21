defmodule PapaVisits.Visits do
  @moduledoc """
  Repository pattern implementation for working with Visits.

  Business logic is also here as this is still a context.
  """
  import Ecto.Query

  alias Ecto.Multi
  alias PapaVisits.Params.Transaction, as: TransactionParams
  alias PapaVisits.Params.Visit, as: VisitParams
  alias PapaVisits.Params.VisitFilter, as: VisitFilterParams
  alias PapaVisits.Repo
  alias PapaVisits.Users.User
  alias PapaVisits.Visits.Visit
  alias PapaVisits.Visits.Transaction

  @type create_params :: VisitParams.t()
  @type create_returns ::
          {:ok, Visit.t_preloaded()} | {:error, Ecto.Changeset.t()}

  @spec create(create_params) :: create_returns()
  def create(params) do
    transaction =
      Multi.new()
      |> Multi.run(:changeset, fn _repo, _ -> {:ok, Visit.changeset(params)} end)
      |> Multi.run(:validate, &validate_changeset/2)
      |> Multi.one(:minutes, &user_minutes/1)
      |> Multi.run(:check_minutes, &check_minutes(&1, &2, params))
      |> Multi.one(:allowed?, &allowed?/1)
      |> Multi.run(:check_allowed, &check_allowed(&1, &2, params))
      |> Multi.insert(:request, &Map.get(&1, :changeset))
      |> Multi.run(:preload, &preload_visit/2)
      |> Repo.transaction()

    case transaction do
      {:ok, %{preload: preload}} ->
        {:ok, preload}

      {:error, _step, error, _} ->
        {:error, error}

      other ->
        other
    end
  end

  @type complete_params :: TransactionParams.t()
  @type complete_returns :: {:ok, Transaction.t_preloaded()} | {:error, Ecto.Changeset.t()}

  @spec complete(complete_params()) :: complete_returns()
  def complete(params) do
    transaction =
      Multi.new()
      |> Multi.one(:visit, &transaction_visit(&1, params.visit_id))
      |> Multi.run(:check_visit, &check_visit(&1, &2, params))
      |> Multi.update(:complete_visit, fn %{visit: visit} ->
        Visit.status_changeset(visit, :completed)
      end)
      |> Multi.insert(:transaction, Transaction.changeset(params))
      |> Multi.update_all(:take_from_papa, &take_from_papa/1, [])
      |> Multi.update_all(:give_to_pal, &give_to_pal/1, [])
      |> Multi.run(:check_transaction, &check_transaction/2)
      |> Repo.transaction()

    case transaction do
      {:ok, %{check_transaction: transaction}} ->
        {:ok, transaction}

      {:error, _step, error, _} ->
        {:error, error}

      other ->
        other
    end
  end

  @type list_params :: VisitFilterParams.t()
  @type list_returns :: [Visit.t_preloaded()]

  @spec list(list_params()) :: list_returns()
  def list(params) do
    conditions =
      Enum.reduce(Map.from_struct(params), true, fn
        {_field, nil}, existing ->
          existing

        {field_name, field_value}, existing ->
          dynamic([q], field(q, ^field_name) == ^field_value and ^existing)
      end)

    query =
      from v in Visit,
        order_by: [asc: v.date],
        preload: [:tasks, :user],
        where: ^conditions

    Repo.all(query)
  end

  defp validate_changeset(_repo, %{changeset: %{valid?: true} = changeset}), do: {:ok, changeset}
  defp validate_changeset(_repo, %{changeset: changeset}), do: {:error, changeset}

  defp user_minutes(%{changeset: changeset}) do
    # FOR UPDATE use validated by integration tests
    user_id = Ecto.Changeset.fetch_field!(changeset, :user_id)

    from u in User,
      where: u.id == ^user_id,
      select: u.minutes,
      lock: "FOR UPDATE"
  end

  defp allowed?(%{changeset: changeset, minutes: current_minutes}) do
    user_id = Ecto.Changeset.fetch_field!(changeset, :user_id)
    requested_minutes = Ecto.Changeset.fetch_field!(changeset, :minutes)
    available_minutes = current_minutes - requested_minutes

    from v in Visit,
      where: v.user_id == ^user_id and v.status == :requested,
      select: ^available_minutes >= coalesce(sum(coalesce(v.minutes, 0)), 0)
  end

  defp check_minutes(_repo, %{minutes: nil}, params) do
    changeset =
      params
      |> Visit.unvalidated_changeset()
      |> Ecto.Changeset.add_error(:user_id, "user not found")

    {:error, changeset}
  end

  defp check_minutes(_repo, _, _), do: {:ok, :user_and_minutes_found}

  defp check_allowed(_repo, %{allowed?: true}, _), do: {:ok, :within_budget}

  defp check_allowed(_repo, _, params) do
    changeset =
      params
      |> Visit.unvalidated_changeset()
      |> Ecto.Changeset.add_error(:minutes, "exceeds budget")

    {:error, changeset}
  end

  defp preload_visit(repo, %{request: request}) do
    {:ok, repo.preload(request, [:user])}
  end

  defp transaction_visit(_, visit_id) do
    # FOR UPDATE use validated by integration tests
    from v in Visit, where: v.id == ^visit_id, lock: "FOR UPDATE"
  end

  defp check_visit(_, %{visit: nil}, params) do
    changeset =
      params
      |> Transaction.unvalidated_changeset()
      |> Ecto.Changeset.add_error(:visit_id, "visit not found")

    {:error, changeset}
  end

  defp check_visit(_, %{visit: %{status: status}}, params) when status != :requested do
    changeset =
      params
      |> Transaction.unvalidated_changeset()
      |> Ecto.Changeset.add_error(:visit_id, "visit not active")

    {:error, changeset}
  end

  defp check_visit(_, %{visit: _visit}, _params), do: {:ok, :visit_active}

  defp take_from_papa(%{transaction: transaction}) do
    visit_id = transaction.visit_id

    from u in User,
      join: v in Visit,
      on: v.id == ^visit_id,
      where: u.id == v.user_id,
      update: [set: [minutes: u.minutes - v.minutes]]
  end

  defp give_to_pal(%{transaction: transaction}) do
    pal_id = transaction.pal_id
    visit_id = transaction.visit_id

    from u in User,
      join: v in Visit,
      on: v.id == ^visit_id,
      where: u.id == ^pal_id,
      update: [set: [minutes: fragment("round(?)", u.minutes + v.minutes * 0.85)]]
  end

  defp check_transaction(_repo, %{take_from_papa: {0, _}}), do: {:error, :papa_not_found}
  defp check_transaction(_repo, %{give_to_pal: {0, _}}), do: {:error, :pal_not_found}

  defp check_transaction(repo, %{transaction: transaction}),
    do: {:ok, repo.preload(transaction, [:pal, visit: [:user, :tasks]])}
end
