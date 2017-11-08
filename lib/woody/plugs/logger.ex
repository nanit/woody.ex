defmodule Woody.Plugs.Logger do
  alias Plug.Conn
  use Woody.Logger
  import Woody.Logger, only: [log: 2]

  def init(opts), do: Keyword.get(opts, :log_level, :info)
  def call(conn, lvl) do
    start = System.monotonic_time()
    Conn.register_before_send(conn, fn conn ->
      stop = System.monotonic_time()
      diff = System.convert_time_unit(stop - start, :native, :milli_seconds)
      log lvl, ["FINISHED_REQUEST", %{method: conn.method, path: conn.request_path, status: conn.status, time_took: diff}]
      conn
    end)
  end
end
