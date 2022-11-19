defmodule PapaVisits.Visits do
  @moduledoc """
  Repository pattern implementation for working with Visits
  """
  import Ecto.Query

  alias PapaVisits.Params.Visit, as: VisitParams
  alias PapaVisits.Repo
  alias PapaVisits.Users.User
  alias PapaVisits.Visits.Visit

  # TODO - re-organize all this
  @spec create(VisitParams.t()) ::
          {:ok, Visit.t()} | {:error, Ecto.Changeset.t() | :exceeds_budget | :user_not_found}
  def create(params) do
    with %{valid?: true} = changeset <- Visit.changeset(params) do
      transaction =
        Repo.transaction(fn ->
          case check_budget(changeset) do
            :ok ->
              Repo.insert(changeset)

            other ->
              other
          end
        end)

      case transaction do
        {:ok, result} -> result
        {:error, error} -> error
      end
    else
      changeset ->
        {:error, changeset}
    end
  end

  defp check_budget(changeset) do
    user_id = Ecto.Changeset.fetch_field!(changeset, :user_id)
    requested_minutes = Ecto.Changeset.fetch_field!(changeset, :minutes)

    # AFAIK transactions are only serialized per-repo-process due to
    # Ecto's connection pooling
    # A `FOR UPDATE` here (though not the only solution)
    # Makes it so concurrent requests (and transacts that actually write data)
    # on a different node also wait for this check.
    minutes_query =
      from u in User,
        where: u.id == ^user_id,
        select: u.minutes,
        lock: "FOR UPDATE"

    case Repo.one(minutes_query) do
      nil ->
        {:error, :user_not_found}

      current_minutes ->
        available_minutes = current_minutes - requested_minutes

        allowed_query =
          from v in Visit,
            where: v.user_id == ^user_id and v.status == :requested,
            select: ^available_minutes >= coalesce(sum(coalesce(v.minutes, 0)), 0)

        case Repo.one(allowed_query) do
          true ->
            :ok

          false ->
            {:error, :exceeds_budget}
        end
    end
  end
end
