defmodule PapaVisits.Users do
  @moduledoc """
  Repository pattern implementation for accessing Users
  """

  alias PapaVisits.Repo
  alias PapaVisits.Users.User

  @type get_params :: Ecto.UUID.t()
  @type get_returns :: User.t_preloaded() | nil

  @spec get(get_params()) :: get_returns()
  def get(id) do
    Repo.preload(get_basic(id), [:visits])
  end

  @type get_basic_params :: Ecto.UUID.t()
  @type get_basic_returns :: User.t() | nil

  @spec get_basic(get_basic_params()) :: get_basic_returns()
  def get_basic(id) do
    Repo.get(User, id)
  end
end
