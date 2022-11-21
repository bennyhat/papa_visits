defmodule PapaVisits.Test.Support.Clients.Primary do
  use PapaVisits.Test.Support.Clients.Base,
    base_url: "http://localhost:" <> System.fetch_env!("PORT") <> "/api"
end
