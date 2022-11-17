import Config

config :papa_visits, PapaVisits.Repo,
  database: "papa_visits_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :papa_visits, PapaVisitsWeb.Endpoint,
  server: true,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "ijHrAhYmLhToSgrdAmh3AWUfc/NVuYR1/MxjOI87yBIPXpwSnHqN51RxoPAcmrJn",
  watchers: [
    # Start the esbuild watcher by calling Esbuild.install_and_run(:default, args)
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
  ]

config :papa_visits, PapaVisitsWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/papa_visits_web/(live|views)/.*(ex)$",
      ~r"lib/papa_visits_web/templates/.*(eex)$"
    ]
  ]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
