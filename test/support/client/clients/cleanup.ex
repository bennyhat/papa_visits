defmodule PapaVisits.Test.Support.Clients.Cleanup do
  @moduledoc """
  A client that points at the primary application, but does not
  tear down the primary if it gets killed
  """

  use PapaVisits.Test.Support.Clients.Base,
    base_url: "http://localhost:" <> System.fetch_env!("PORT") <> "/api"
end
