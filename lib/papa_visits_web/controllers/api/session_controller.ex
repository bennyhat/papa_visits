defmodule PapaVisitsWeb.Api.SessionController do
  use PapaVisitsWeb, :controller

  alias Plug.Conn

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, user_params) do
    case Pow.Plug.authenticate_user(conn, user_params) do
      {:ok, conn} ->
        conn
        |> put_view(PapaVisitsWeb.Api.AuthView)
        |> render("access_token.json", token: conn.private.access_token)

      {:error, conn} ->
        conn
        |> put_status(401)
        |> put_view(PapaVisitsWeb.Api.AuthView)
        |> render("invalid.json", status: 401, message: "Invalid email or password")
    end
  end
end
