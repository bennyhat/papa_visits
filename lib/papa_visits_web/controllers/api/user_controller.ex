defmodule PapaVisitsWeb.Api.UserController do
  use PapaVisitsWeb, :controller

  alias PapaVisits
  alias Plug.Conn

  @spec show(Conn.t(), map()) :: Conn.t()
  def show(conn, _params) do
    case PapaVisits.get_user(conn.assigns.current_user.id) do
      nil ->
        conn
        |> put_status(404)
        |> put_view(PapaVisitsWeb.Api.AuthView)
        |> render("invalid.json", status: 401, message: "User not found")

      user ->
        render(conn, "show.json", user: user)
    end
  end
end
