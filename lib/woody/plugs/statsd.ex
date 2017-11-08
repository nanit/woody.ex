defmodule Woody.Plugs.StatsD do
  alias Plug.Conn
  alias Woody.StatsD

  def init(opts), do: Keyword.get(opts, :log_level, :info)
  def call(conn, lvl) do
    start = System.monotonic_time()
    Conn.register_before_send(conn, fn conn ->
      stop = System.monotonic_time()
      diff = System.convert_time_unit(stop - start, :native, :milli_seconds)
      report(conn, diff)
      conn
    end)
  end

  defp route_to_metric_name(conn) do
    path_params = Map.new(for {k,v} <- conn.path_params, do: {v, k})
    path_info = Enum.map(conn.path_info, fn p -> path_params[p] || p end)
    ([conn.method] ++ path_info) |> Enum.map(&String.downcase/1) |> Enum.join("-")
  end

  defp report(conn, time_took) do
    metric_name = route_to_metric_name(conn)
    StatsD.increment("web.#{metric_name}.requests")
    StatsD.increment("web.#{metric_name}.response_codes.#{conn.status}")
    StatsD.timer(time_took, "web.#{metric_name}")
  end
end
