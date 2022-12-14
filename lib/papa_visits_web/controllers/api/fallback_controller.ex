defmodule PapaVisitsWeb.Api.FallbackController do
  @moduledoc """
  A controller for handling fallback errors from
  API controllers
  """
  use PapaVisitsWeb, :controller
  alias PapaVisitsWeb.ErrorHelpers
  alias Ecto.Changeset

  def call(conn, {:error, params_changeset: %Ecto.Changeset{} = changeset}) do
    errors = CozyParams.get_error_messages(changeset)
    message = "Parameter validation failed."

    send_changeset_errors(conn, errors, message)
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset, _conn}) do
    call(conn, {:error, changeset})
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    errors = Changeset.traverse_errors(changeset, &ErrorHelpers.translate_error/1)
    message = "Validation failed."

    send_changeset_errors(conn, errors, message)
  end

  defp send_changeset_errors(conn, errors, message) do
    conn
    |> put_status(422)
    |> put_view(PapaVisitsWeb.Api.ErrorView)
    |> render("changeset_error.json", status: 422, errors: errors, message: message)
  end
end
