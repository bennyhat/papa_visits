defmodule PapaVisitsWeb.Api.VisitController do
  use PapaVisitsWeb, :controller

  action_fallback PapaVisitsWeb.Api.FallbackController

  alias PapaVisits
  alias PapaVisits.Params.Transaction
  alias PapaVisits.Params.Visit
  alias PapaVisits.Params.VisitFilter
  alias Plug.Conn

  @spec index(Conn.t(), map()) :: Conn.t()
  def index(conn, params) do
    with {:ok, filters} <- VisitFilter.from(params) do
      render(conn, "index.json", visits: PapaVisits.list_visits(filters))
    end
  end

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, params) do
    params_with_user = Map.put(params, :user_id, conn.assigns.current_user.id)

    with {:ok, visit_params} <- Visit.from(params_with_user),
         {:ok, visit} <- PapaVisits.request_visit(visit_params) do
      render(conn, "show.json", visit: visit)
    end
  end

  @spec update_completed(Conn.t(), map()) :: Conn.t()
  def update_completed(conn, params) do
    with {:ok, transaction_params} <- Transaction.from(params),
         {:ok, transaction} <- PapaVisits.complete_visit(transaction_params) do
      render(conn, "update_completed.json", transaction: transaction)
    end
  end
end
