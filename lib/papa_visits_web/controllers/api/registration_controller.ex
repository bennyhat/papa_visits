defmodule PapaVisitsWeb.API.RegistrationController do
  @moduledoc """
  A controller for registering new users for the sake of
  assigning a new id and access token
  """
  use PapaVisitsWeb, :controller

  alias Ecto.Changeset
  alias Plug.Conn
  alias PapaVisitsWeb.ErrorHelpers

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, user_params) do
    conn
    |> Pow.Plug.create_user(user_params)
    |> case do
      {:ok, _user, conn} ->
        json(conn, %{data: %{access_token: conn.private.access_token}})

      {:error, changeset, conn} ->
        errors = Changeset.traverse_errors(changeset, &ErrorHelpers.translate_error/1)

        conn
        |> put_status(500)
        |> json(%{error: %{status: 500, message: "Couldn't create user", errors: errors}})
    end
  end
end
