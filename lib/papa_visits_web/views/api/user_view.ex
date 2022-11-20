defmodule PapaVisitsWeb.Api.UserView do
  use PapaVisitsWeb, :view

  alias PapaVisits.Users.User
  alias PapaVisitsWeb.Api.VisitView

  def render("show.json", %{user: user}) do
    %{
      data: render(__MODULE__, "user_preloaded.json", user: user)
    }
  end

  def render("user_preloaded.json", %{user: %User{} = user}) do
    user
    |> render_user()
    |> Map.put(:visits, render_many(user.visits, VisitView, "visit.json", as: :visit))
  end

  def render("user.json", %{user: %User{} = user}) do
    render_user(user)
  end

  defp render_user(user) do
    %{
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      minutes: user.minutes
    }
  end
end
