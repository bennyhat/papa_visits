defmodule PapaVisitsWeb.PageController do
  use PapaVisitsWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
