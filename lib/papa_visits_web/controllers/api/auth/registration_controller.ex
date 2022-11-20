defmodule PapaVisitsWeb.Api.Auth.RegistrationController do
  @moduledoc """
  A controller for registering new users for the sake of
  assigning a new id and access token
  """
  use PapaVisitsWeb, :controller

  action_fallback PapaVisitsWeb.Api.FallbackController

  alias Plug.Conn

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, user_params) do
    with {:ok, _user, conn} <- Pow.Plug.create_user(conn, user_params) do
      conn
      |> put_view(PapaVisitsWeb.Api.AuthView)
      |> render("access_token.json", token: conn.private.access_token)
    end
  end
end
