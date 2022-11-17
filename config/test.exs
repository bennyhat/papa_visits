import Config

config :papa_visits, PapaVisits.Repo,
  database: "papa_visits_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :papa_visits, PapaVisitsWeb.Endpoint,
  secret_key_base: "P+NXxtB/BYNgcmWctwh2JW5kLmUP7oUutMomJBYzuCl459sADZR6Z5tCR3yNeRv1",
  server: false

config :papa_visits, PapaVisits.Mailer, adapter: Swoosh.Adapters.Test

config :logger, level: :warn

config :phoenix, :plug_init_mode, :runtime
