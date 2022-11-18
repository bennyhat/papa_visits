defmodule PapaVisitsWeb.API.SessionController do
  use PapaVisitsWeb, :controller

  alias Plug.Conn

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, user_params) do
    conn
    |> Pow.Plug.authenticate_user(user_params)
    |> case do
      {:ok, conn} ->
        json(conn, %{data: %{access_token: conn.private.access_token}})

      {:error, conn} ->
        conn
        |> put_status(401)
        |> json(%{error: %{status: 401, message: "Invalid email or password"}})
    end
  end
end
