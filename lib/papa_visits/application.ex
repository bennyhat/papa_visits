defmodule PapaVisits.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PapaVisits.Repo,
      PapaVisitsWeb.Telemetry,
      {Phoenix.PubSub, name: PapaVisits.PubSub},
      PapaVisitsWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: PapaVisits.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PapaVisitsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
