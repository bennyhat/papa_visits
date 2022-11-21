defmodule PapaVisits.Test.Support.Clients.Base do
  @moduledoc """
  Base client implementation for integration tests.
  Using compilation pattern rather than making tests pass client around.
  """
  defmacro __using__(opts) do
    quote do
      use Tesla

      import PapaVisits.Test.Support.Clients.Base

      adapter(Tesla.Adapter.Finch, name: __MODULE__)

      plug Tesla.Middleware.BaseUrl, unquote(opts[:base_url])
      plug Tesla.Middleware.Headers, [{"accept", "application/json"}]
      plug Tesla.Middleware.JSON
      plug Tesla.Middleware.PathParams

      def child_spec(opts) do
        {id, opts} = Keyword.pop(opts, :id, __MODULE__)

        opts =
          [pools: [default: [size: 10, count: System.schedulers_online()]]]
          |> Keyword.merge(opts)
          |> Keyword.put_new(:name, __MODULE__)

        Supervisor.child_spec({Finch, opts}, id: id)
      end

      def request_visit(body, token) do
        "/visit"
        |> post(body, headers: [{"authorization", token}])
        |> convert_response()
      end

      def complete_visit(visit_id, token) do
        path_params = [visit_id: visit_id]

        "/visit/:visit_id/complete"
        |> put(%{}, opts: [path_params: path_params], headers: [{"authorization", token}])
        |> convert_response()
      end

      def register_user(body) do
        "/auth/registration"
        |> post(body)
        |> convert_response()
      end

      def unregister_user(token) do
        "/auth/registration"
        |> delete(headers: [{"authorization", token}])
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
