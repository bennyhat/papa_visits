defmodule PapaVisitsWeb.Router do
  use PapaVisitsWeb, :router

  pipeline :api do
    plug :accepts, ["json"]

    plug PapaVisitsWeb.ApiAuthPlug,
      otp_app: :papa_visits,
      token_namespace: "papa_visits_api"
  end

  scope "/api", PapaVisitsWeb.Api, as: :api do
    pipe_through :api

    scope "/auth", Auth, as: :auth do
      post "/registration", RegistrationController, :create
      post "/session", SessionController, :create
    end

    get "/visit", VisitController, :index
  end
end
