defmodule PapaVisits do
  @moduledoc """
  Main context for actual business logic.
  """

  alias PapaVisits.Params.Visit, as: VisitParams
  alias PapaVisits.Visits
  alias PapaVisits.Visits.Visit

  @spec request_visit(VisitParams.t()) :: {:ok, Visit.t()} | {:error, Ecto.Changeset.t()}
  def request_visit(params) do
    Visits.create(params)
  end
end
