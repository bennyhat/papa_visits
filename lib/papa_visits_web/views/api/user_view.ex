defmodule PapaVisitsWeb.Api.UserView do
  use PapaVisitsWeb, :view

  alias PapaVisits.Users.User

  def render("show.json", %{user: user}) do
    %{
      data: render(__MODULE__, "user.json", user: user)
    }
  end

  def render("user.json", %{user: %User{} = user}) do
    %{
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      minutes: user.minutes
    }
  end
end
