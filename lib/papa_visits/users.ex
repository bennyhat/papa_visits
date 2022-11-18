defmodule PapaVisits.Users do
  @moduledoc """
  Repository pattern implementation for accessing Users
  """

  alias PapaVisits.Repo
  alias PapaVisits.Users.User

  @spec get(Ecto.UUID.t()) :: User.t() | nil
  def get(id) do
    Repo.get(User, id)
  end
end
