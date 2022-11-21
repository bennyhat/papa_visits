defmodule PapaVisits.MixProject do
  use Mix.Project

  def project do
    [
      app: :papa_visits,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      build_per_environment: true,
      build_embedded: true,
      default_release_name: :papa_visits_a,
      releases: [
        papa_visits_a: [quiet: false],
        papa_visits_b: [quiet: true]
      ],
      test_paths: test_paths(Mix.env())
    ]
  end

  def application do
    [
      mod: {PapaVisits.Application, []},
      extra_applications: [:logger, :runtime_tools] ++ extra_applications(Mix.env())
    ]
  end

  defp extra_applications(:test) do
    [:faker, :ex_machina]
  end

  defp extra_applications(_), do: []

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(_) do
    case System.get_env("TEST_TIER", "unit") do
      "unit" -> ["test/unit"]
      "integration" -> ["test/integration"]
      other -> raise "Unrecognized TEST_TIER=#{other}"
    end
  end

  defp test(tier, args) do
    string_args = Enum.join(args, " ")
    exit_code = Mix.shell().cmd("mix test --color #{string_args}", env: [{"TEST_TIER", tier}])
    exit({:shutdown, exit_code})
  end

  defp deps do
    [
      {:assertions, "~> 0.19.0", only: :test},
      {:cozy_params, "~> 1.0"},
      {:credo, "~> 1.6", only: :dev},
      {:ecto_sql, "~> 3.6"},
      {:esbuild, "~> 0.4", runtime: Mix.env() == :dev},
      {:ex_machina, "~> 2.7", only: :test},
      {:faker, "~> 0.17.0", only: :test},
      {:finch, "~> 0.3", only: :test},
      {:floki, ">= 0.30.0", only: :test},
      {:gettext, "~> 0.18"},
      {:jason, "~> 1.2"},
      {:permutation, "~> 0.2.0", only: :test},
      {:phoenix, "~> 1.6.15"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_dashboard, "~> 0.6"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.17.5"},
      {:plug_cowboy, "~> 2.5"},
      {:postgrex, ">= 0.0.0"},
      {:pow, "~> 1.0"},
      {:swoosh, "~> 1.3"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:tesla, "~> 1.4", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": ["esbuild default --minify", "phx.digest"],
      "test.integration": &test("integration", &1 ++ ["--no-start"]),
      "test.unit": &test("unit", &1)
    ]
  end
end
