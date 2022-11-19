defmodule PapaVisitsWeb.Api.AuthView do
  use PapaVisitsWeb, :view

  def render("invalid.json", %{status: status, message: message}) do
    %{error: %{status: status, message: message}}
  end

  def render("access_token.json", %{token: token}) do
    %{
      data: %{
        access_token: token
      }
    }
  end
end
