defmodule PapaVisits.Test.Support.Clients.Secondary do
  @moduledoc """
  A client that points at the secondary application
  """
  use PapaVisits.Test.Support.Clients.Base,
    base_url: "http://localhost:" <> System.fetch_env!("PORT_SECONDARY") <> "/api"
end
