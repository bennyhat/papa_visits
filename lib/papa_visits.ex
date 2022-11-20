defmodule PapaVisits do
  @moduledoc """
  Main context for actual business logic.
  """

  alias PapaVisits.Visits

  @spec request_visit(Visits.request_params()) :: Visits.request_returns()
  def request_visit(params) do
    Visits.create(params)
  end

  @spec complete_visit(Visits.complete_params()) :: Visits.complete_returns()
  def complete_visit(params) do
    Visits.complete(params)
  end
end
