defmodule PapaVisitsWeb.ApiAuthPlug do
  @moduledoc """
  This module gets hooked into Pow's main user management system
  such that it can:
  - fetch and verify tokens from the conn, if they're there
  - be used under the hood to create the tokens to attach to the conn
  """
  use Pow.Plug.Base

  alias Plug.Conn
  alias PapaVisits.Users
  alias PapaVisits.Users.User

  @doc """
  Fetches the user from access token.
  """
  @impl Pow.Plug.Base
  @spec fetch(Conn.t(), Config.t()) :: {Conn.t(), map() | nil}
  def fetch(conn, config) do
    token_namespace = Keyword.fetch!(config, :token_namespace)
    token_max_age = Keyword.get(config, :token_max_age, 86_400)

    with {:ok, token} <- fetch_access_token(conn),
         {:ok, user_id} <-
           Phoenix.Token.verify(PapaVisitsWeb.Endpoint, token_namespace, token,
             max_age: token_max_age
           ),
         user when not is_nil(user) <- Users.get(user_id) do
      {conn, user}
    else
      _any -> {conn, nil}
    end
  end

  @doc """
  Creates an access token for a user.
  """
  @impl Pow.Plug.Base
  @spec create(Conn.t(), User.t(), Config.t()) :: {Conn.t(), map()}
  def create(conn, user, config) do
    token_namespace = Keyword.fetch!(config, :token_namespace)

    token = Phoenix.Token.sign(PapaVisitsWeb.Endpoint, token_namespace, user.id)

    conn = Conn.put_private(conn, :access_token, token)

    {conn, user}
  end

  @doc """
  Required by the Pow plug base wrapper.
  Not implementing for now, as there is no logout planned for this
  exercise.
  """
  @impl Pow.Plug.Base
  @spec delete(Conn.t(), Config.t()) :: Conn.t()
  def delete(conn, _config) do
    conn
  end

  defp fetch_access_token(conn) do
    case Conn.get_req_header(conn, "authorization") do
      [token | _rest] -> {:ok, token}
      _any -> :error
    end
  end
end
