defmodule Woody.Logger do
  require Logger
  require Poison
  
  defmacro __using__(_opts) do
    quote do
      require Logger
      import Woody.Logger, only: [debug: 1, debug: 2, debug: 3, error: 1, error: 2, error: 3, info: 1, info: 2, info: 3]
    end
  end

  @app Application.get_env(:tip_me, :app_for_log)

  def prefix(k, v) when is_nil(v), do: k
  def prefix(k, v) when is_boolean(v), do: "#{k}_bool"
  def prefix(k, v) when is_atom(v), do: "#{k}_str"
  def prefix(k, v) when is_bitstring(v), do: "#{k}_str"
  def prefix(k, v) when is_float(v), do: "#{k}_flt"
  def prefix(k, v) when is_integer(v), do: "#{k}_int"
  def prefix(k, v) when is_tuple(v), do: "#{k}_str"
  def prefix(k, v) when is_map(v), do: k
  def prefix(k, v) when is_list(v) do
    if Keyword.keyword? v do
      k
    else
      "#{k}_str"
    end
  end
  def prefix(k, _v), do: "#{k}_str"

  def process(v) when is_nil(v), do: v
  def process(v) when is_boolean(v), do: v
  def process(v) when is_atom(v), do: to_string(v)
  def process(v) when is_bitstring(v), do: v
  def process(v) when is_float(v), do: v
  def process(v) when is_integer(v), do: v
  def process(v) when is_tuple(v), do: inspect(v)
  def process(v) when is_map(v) do 
    case nested_map_size(v) do
      x when x > 20 ->
        case Poison.encode(v) do
          {:ok, str} -> str
          {:error, err} -> inspect(v)
        end
      _else -> add_to_log(v, %{})
    end
  end
  def process(v) when is_list(v) do
    if Keyword.keyword? v do
      add_to_log(Enum.into(v, %{}), %{})
    else
      inspect v
    end
  end
  def process(v), do: inspect(v)

  def add_kv_to_log({k, v}, acc) do 
    processed = process(v)
    Map.put(acc, prefix(k, processed), processed)
  end

  def add_to_log(member, acc) when is_bitstring(member) do
    Map.put(acc, :message, member)
  end

  def add_to_log(member, acc) when is_map(member) do
    try do
      Enum.reduce(member, acc, &add_kv_to_log/2)
    rescue
      _error -> Map.merge(acc, %{payload: inspect(member)})
    end
  end

  def add_to_log(member, acc) when is_list(member) do
    if Keyword.keyword? member do
      add_to_log(Enum.into(member, %{}), acc)
    else
      Map.merge(acc, %{payload: inspect(member)})
    end
  end

  def add_to_log(member, acc) do
    Map.merge(acc, %{payload: inspect(member)})
  end
  
  defp additional_fields(lvl, module, file, function, line) do
    %{"@timestamp" => Timex.format!(Timex.now, "{ISO:Extended}"),
      "level" => lvl,
      "app" => @app,
      "meta" => %{
        "module" => module,
        "file" => file,
        "function" => inspect(function),
        "line" => line,
      }}
  end

  def wrap_with_metadata(m, lvl, module, file, function, line) do
    Map.merge(additional_fields(lvl, module, file, function, line), m)
  end

  def log(lvl, list, caller) do
    %{module: m, file: file, function: f, line: l} = caller
    quote do
      msg = unquote(list) |> Enum.reduce(%{}, &Woody.Logger.add_to_log/2) |> Woody.Logger.wrap_with_metadata(unquote(lvl), unquote(m), unquote(file), unquote(f), unquote(l)) |> Poison.encode!
      Logger.log(unquote(lvl), msg)
    end
  end

  defmacro log(lvl, l) do
    log lvl, l, __CALLER__
  end

  defmacro info(a1) do
    log(:info, [a1], __CALLER__)
  end

  defmacro info(a1, a2) do
    log(:info, [a1, a2], __CALLER__)
  end

  defmacro info(a1, a2, a3) do
    log(:info, [a1, a2, a3], __CALLER__)
  end

  defmacro debug(a1) do
    log(:debug, [a1], __CALLER__)
  end

  defmacro debug(a1, a2) do
    log(:debug, [a1, a2], __CALLER__)
  end

  defmacro debug(a1, a2, a3) do
    log(:debug, [a1, a2, a3], __CALLER__)
  end

  defmacro error(a1) do
    log(:error, [a1], __CALLER__)
  end

  defmacro error(a1, a2) do
    log(:error, [a1, a2], __CALLER__)
  end

  defmacro error(a1, a2, a3) do
    log(:error, [a1, a2, a3], __CALLER__)
  end

  defp nested_map_size(m) when is_map(m) do
    current = m |> Map.keys |> Enum.count
    Enum.reduce(m, current, fn {_k, v}, acc -> acc + nested_map_size(v) end )
  end
  defp nested_map_size(_), do: 0

end

