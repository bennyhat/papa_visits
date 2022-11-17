import Config

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

host = System.fetch_env!("HOST")
port = String.to_integer(System.get_env("PORT") || "4000")

config :papa_visits, PapaVisitsWeb.Endpoint,
  url: [host: host, port: port, scheme: "http"],
  secret_key_base: secret_key_base

config :papa_visits, PapaVisits.Repo,
  port: System.fetch_env!("PGPORT"),
  username: System.fetch_env!("PGUSER"),
  password: System.fetch_env!("PGPASSWORD"),
  hostname: System.fetch_env!("PGHOST")

if config_env() == :prod do
  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

  config :papa_visits, PapaVisits.Repo,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6,
    database: System.fetch_env!("PGDATABASE")
end
