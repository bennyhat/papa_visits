defmodule PapaVisits.Test.Support.Clients.Secondary do
  use PapaVisits.Test.Support.Clients.Base,
    base_url: "http://localhost:" <> System.fetch_env!("PORT_SECONDARY") <> "/api"
end
