defmodule PapaVisitsWeb.Router do
  use PapaVisitsWeb, :router

  pipeline :api do
    plug :accepts, ["json"]

    plug PapaVisitsWeb.ApiAuthPlug,
      otp_app: :papa_visits,
      token_namespace: "papa_visits_api"
  end

  scope "/api", PapaVisitsWeb.API do
    pipe_through :api

    post "/registration", RegistrationController, :create
    post "/session", SessionController, :create
  end
end
