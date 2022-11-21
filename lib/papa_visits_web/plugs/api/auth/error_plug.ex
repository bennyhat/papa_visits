defmodule PapaVisitsWeb.Api.Auth.ErrorPlug do
  @moduledoc """
  A plug for handling unauthenticated users.
  """
  use PapaVisitsWeb, :controller
  alias Plug.Conn

  @spec call(Conn.t(), :not_authenticated) :: Conn.t()
  def call(conn, :not_authenticated) do
    conn
    |> put_status(401)
    |> put_view(PapaVisitsWeb.Api.AuthView)
    |> render("invalid.json", status: 401, message: "Not authenticated")
  end
end
