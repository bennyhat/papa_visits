defmodule PapaVisitsWeb.Api.VisitController do
  use PapaVisitsWeb, :controller

  alias PapaVisits
  alias PapaVisits.Params.VisitFilter
  alias Plug.Conn

  @spec index(Conn.t(), map()) :: Conn.t()
  def index(conn, params) do
    with {:ok, filters} <- VisitFilter.from(params) do
      render(conn, "index.json", visits: PapaVisits.list_visits(filters))
    end
  end
end
