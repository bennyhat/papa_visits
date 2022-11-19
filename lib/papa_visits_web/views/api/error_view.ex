defmodule PapaVisitsWeb.Api.ErrorView do
  use PapaVisitsWeb, :view

  def render("changeset_error.json", %{errors: errors, message: message}) do
    %{
      error: %{
        status: 422,
        message: message,
        errors: errors
      }
    }
  end
end
