defmodule PapaVisits.Repo do
  use Ecto.Repo,
    otp_app: :papa_visits,
    adapter: Ecto.Adapters.Postgres
end
