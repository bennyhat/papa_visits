defmodule PapaVisitsWeb.PageControllerTest do
  use PapaVisitsWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end
end
