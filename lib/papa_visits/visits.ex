defmodule PapaVisits.Visits do
  @moduledoc """
  Repository pattern implementation for working with Visits.

  Business logic is also here as this is still a context.
  """
  import Ecto.Query

  alias Ecto.Multi
  alias PapaVisits.Params.Visit, as: VisitParams
  alias PapaVisits.Repo
  alias PapaVisits.Users.User
  alias PapaVisits.Visits.Visit
  alias PapaVisits.Visits.Transaction

  @type create_params :: VisitParams.t()
  @type create_returns ::
          {:ok, Visit.t()} | {:error, Ecto.Changeset.t() | :exceeds_budget | :user_not_found}

  @spec create(create_params) :: create_returns()
  def create(params) do
    transaction =
      Multi.new()
      |> Multi.run(:changeset, fn _repo, _ -> {:ok, Visit.changeset(params)} end)
      |> Multi.run(:validate, &validate_changeset/2)
      |> Multi.one(:minutes, &user_minutes/1)
      |> Multi.run(:check_minutes, &check_minutes/2)
      |> Multi.one(:allowed?, &allowed?/1)
      |> Multi.run(:check_allowed, &check_allowed/2)
      |> Multi.insert(:request, &Map.get(&1, :changeset))
      |> Repo.transaction()

    case transaction do
      {:ok, %{request: request}} ->
        {:ok, request}

      {:error, _step, error, _} ->
        {:error, error}

      other ->
        other
    end
  end

  @type complete_params :: TransactionParams.t()
  @type complete_returns :: {:ok, Transaction.t()} | {:error, Ecto.Changeset.t()}

  @spec complete(complete_params()) :: complete_returns()
  def complete(params) do
    transaction =
      Multi.new()
      |> Multi.one(:visit, &transaction_visit(&1, params.visit_id))
      |> Multi.run(:check_visit, &check_visit/2)
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

  defp validate_changeset(_repo, %{changeset: %{valid?: true} = changeset}), do: {:ok, changeset}
  defp validate_changeset(_repo, %{changeset: changeset}), do: {:error, changeset}

  defp user_minutes(%{changeset: changeset}) do
    # AFAIK transactions are only serialized per-repo-process due to
    # Ecto's connection pooling
    # A `FOR UPDATE` here (though not the only solution)
    # Makes it so concurrent requests (and transacts that actually write data)
    # on a different node also wait for the check this is in.

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

  defp check_minutes(_repo, %{minutes: nil}), do: {:error, :user_not_found}
  defp check_minutes(_repo, _), do: {:ok, :user_and_minutes_found}

  defp check_allowed(_repo, %{allowed?: true}), do: {:ok, :within_budget}
  defp check_allowed(_repo, _), do: {:error, :exceeds_budget}

  defp transaction_visit(_, visit_id) do
    from v in Visit, where: v.id == ^visit_id
  end

  defp check_visit(_, %{visit: nil}), do: {:error, :visit_not_found}

  defp check_visit(_, %{visit: %{status: status}}) when status != :requested,
    do: {:error, :visit_not_active}

  defp check_visit(_, %{visit: _visit}), do: {:ok, :visit_active}

  defp take_from_papa(%{transaction: transaction}) do
    papa_id = transaction.papa_id
    visit_id = transaction.visit_id

    from u in User,
      where: u.id == ^papa_id,
      join: v in Visit,
      on: v.id == ^visit_id and v.user_id == ^papa_id,
      update: [set: [minutes: u.minutes - v.minutes]]
  end

  defp give_to_pal(%{transaction: transaction}) do
    pal_id = transaction.pal_id
    visit_id = transaction.visit_id

    from u in User,
      where: u.id == ^pal_id,
      join: v in Visit,
      on: v.id == ^visit_id,
      update: [set: [minutes: fragment("round(?)", u.minutes + v.minutes * 0.85)]]
  end

  defp check_transaction(_repo, %{take_from_papa: {0, _}}), do: {:error, :transaction_failed}
  defp check_transaction(_repo, %{give_to_pal: {0, _}}), do: {:error, :transaction_failed}

  defp check_transaction(repo, %{transaction: transaction}),
    do: {:ok, repo.preload(transaction, [:papa, :pal, :visit])}
end
