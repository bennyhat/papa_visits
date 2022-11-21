defmodule PapaVisitsWeb.Api.Auth.RegistrationController do
  @moduledoc """
  A controller for registering new users for the sake of
  assigning a new id and access token
  """
  use PapaVisitsWeb, :controller

  action_fallback PapaVisitsWeb.Api.FallbackController

  alias Plug.Conn

  @spec create(Conn.t(), map()) :: Conn.t() | {:error, any()}
  def create(conn, user_params) do
    with {:ok, _user, conn} <- Pow.Plug.create_user(conn, user_params) do
      conn
      |> put_view(PapaVisitsWeb.Api.AuthView)
      |> render("access_token.json", token: conn.private.access_token)
    end
  end

  @spec delete(Conn.t(), map()) :: Conn.t() | {:error, any()}
  def delete(conn, _params) do
    with {:ok, _user, conn} <- Pow.Plug.delete_user(conn) do
      conn
      |> put_view(PapaVisitsWeb.Api.AuthView)
      |> render("delete.json")
    end
  end
end
