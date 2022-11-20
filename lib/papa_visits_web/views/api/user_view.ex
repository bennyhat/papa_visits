defmodule PapaVisitsWeb.Api.UserView do
  use PapaVisitsWeb, :view

  alias PapaVisits.Users.User

  def render("user.json", %{user: %User{} = user}) do
    %{
      id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      minutes: user.minutes
    }
  end
end
