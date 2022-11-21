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

  # presumably this could return some details of the delete in
  # the future too, like visits, transactions, etc. deleted
  def render("delete.json", _assigns) do
    %{
      data: "success"
    }
  end
end
