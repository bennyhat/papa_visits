defmodule PapaVisits do
  @moduledoc """
  Main context for actual business logic.
  """

  alias PapaVisits.Users
  alias PapaVisits.Visits

  @spec request_visit(Visits.create_params()) :: Visits.create_returns()
  def request_visit(params) do
    Visits.create(params)
  end

  @spec complete_visit(Visits.complete_params()) :: Visits.complete_returns()
  def complete_visit(params) do
    Visits.complete(params)
  end

  @spec list_visits(Visits.list_params()) :: Visits.list_returns()
  def list_visits(params) do
    Visits.list(params)
  end

  @spec get_user(Users.get_params()) :: Users.get_returns()
  def get_user(id) do
    Users.get(id)
  end
end
