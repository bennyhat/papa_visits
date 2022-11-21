defmodule PapaVisits.Test.Support.Clients.Primary do
  @moduledoc """
  A client that points at the primary application
  """
  use PapaVisits.Test.Support.Clients.Base,
    base_url: "http://localhost:" <> System.fetch_env!("PORT") <> "/api"
end
