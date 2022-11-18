defmodule PapaVisitsWeb.Router do
  use PapaVisitsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PapaVisitsWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]

    plug PapaVisitsWeb.ApiAuthPlug,
      otp_app: :papa_visits,
      token_namespace: "papa_visits_api"
  end

  scope "/api", PapaVisitsWeb.API do
    pipe_through :api

    post "/registration", RegistrationController, :create
  end

  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PapaVisitsWeb.Telemetry
    end
  end

  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
