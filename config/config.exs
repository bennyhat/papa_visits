import Config

config :papa_visits,
  ecto_repos: [PapaVisits.Repo]

config :papa_visits, PapaVisits.Repo, migration_primary_key: [name: :id, type: :uuid]

config :papa_visits, :pow,
  user: PapaVisits.Users.User,
  repo: PapaVisits.Repo

config :papa_visits, PapaVisitsWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: PapaVisitsWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: PapaVisits.PubSub,
  live_view: [signing_salt: "Ez5Zvuwp"]

config :papa_visits, PapaVisits.Mailer, adapter: Swoosh.Adapters.Local

config :swoosh, :api_client, false

config :esbuild,
  version: "0.14.29",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
