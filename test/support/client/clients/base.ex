defmodule PapaVisits.Test.Support.Clients.Base do
  defmacro __using__(opts) do
    quote do
      use Tesla

      import PapaVisits.Test.Support.Clients.Base

      adapter(Tesla.Adapter.Finch, name: __MODULE__)

      plug Tesla.Middleware.BaseUrl, unquote(opts[:base_url])
      plug Tesla.Middleware.Headers, [{"accept", "application/json"}]
      plug Tesla.Middleware.JSON
      plug Tesla.Middleware.PathParams

      def child_spec(_) do
        opts = [pools: [default: [size: 10, count: System.schedulers_online()]]]

        Supervisor.child_spec({Finch, Keyword.put(opts, :name, __MODULE__)}, id: __MODULE__)
      end

      def request_visit(body, token) do
        "/visit"
        |> post(body, headers: [{"authorization", token}])
        |> convert_response()
      end

      def complete_visit(body, token) do
        visit_id = Map.pop(body, "visit_id")

        "/visit/:visit_id/complete"
        |> put(body, path_params: [visit_id: visit_id], headers: [{"authorization", token}])
        |> convert_response()
      end

      def register_user(body) do
        "/auth/registration"
        |> post(body)
        |> convert_response()
      end

      def get_user(token) do
        "/user"
        |> get(headers: [{"authorization", token}])
        |> convert_response()
      end

      def create_session(body) do
        "/auth/session"
        |> post(body)
        |> convert_response()
      end
    end
  end

  def convert_response({:ok, %{body: %{"error" => %{"errors" => errors}}}}) do
    {:error, errors}
  end

  def convert_response({:ok, %{body: %{"data" => data}}}), do: {:ok, data}
end
