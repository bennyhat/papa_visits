defmodule PapaVisitsWeb.Router do
  use PapaVisitsWeb, :router

  pipeline :api do
    plug :accepts, ["json"]

    plug PapaVisitsWeb.Api.AuthPlug,
      otp_app: :papa_visits,
      token_namespace: "papa_visits_api"
  end

  pipeline :api_protected do
    plug Pow.Plug.RequireAuthenticated,
      error_handler: PapaVisitsWeb.Api.Auth.ErrorPlug
  end

  scope "/api", PapaVisitsWeb.Api, as: :api do
    pipe_through :api

    scope "/auth", Auth, as: :auth do
      post "/registration", RegistrationController, :create
      post "/session", SessionController, :create
    end
  end

  scope "/api", PapaVisitsWeb.Api, as: :api do
    pipe_through [:api, :api_protected]

    get "/user", UserController, :show

    get "/visit", VisitController, :index
    post "/visit", VisitController, :create
  end
end
