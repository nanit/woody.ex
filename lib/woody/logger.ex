defmodule Woody.Logger do
  require Logger
  require Poison
  
  defmacro __using__(_opts) do
    quote do
      require Logger
      import Woody.Logger, only: [debug: 1, debug: 2, debug: 3, error: 1, error: 2, error: 3, info: 1, info: 2, info: 3]
    end
  end

  @app Application.get_env(:woody, :app_name)
  def stringify(k) do
    case String.Chars.impl_for k do
      nil -> inspect k
      _other -> k
    end
  end

  def suffix(k, nil), do: stringify k
  def suffix(k, suf), do: "#{stringify k}_#{suf}"

  def get_suffix(v) when is_nil(v), do: nil
  def get_suffix(v) when is_boolean(v), do: "bool"
  def get_suffix(v) when is_atom(v), do: "str"
  def get_suffix(v) when is_bitstring(v), do: "str"
  def get_suffix(v) when is_float(v), do: "flt"
  def get_suffix(v) when is_integer(v), do: "int"
  def get_suffix(v) when is_tuple(v), do: "str"
  def get_suffix(v) when is_map(v), do: nil
  def get_suffix(v) when is_list(v) do
    if Keyword.keyword? v do
      nil
    else
      "str"
    end
  end
  def get_suffix(_v), do: "str"

  def process(v) when is_nil(v), do: v
  def process(v) when is_boolean(v), do: v
  def process(v) when is_atom(v), do: to_string(v)
  def process(v) when is_bitstring(v), do: v
  def process(v) when is_float(v), do: v
  def process(v) when is_integer(v), do: v
  def process(v) when is_tuple(v), do: inspect(v)
  def process(%{__struct__: Date} = v) when is_map(v) do 
    {Date.to_iso8601(v), "date"}
  end
  def process(%{__struct__: DateTime} = v) when is_map(v) do 
    {DateTime.to_iso8601(v), "datetime"}
  end

  def process(%{__struct__: type} = v) when is_map(v) do 
    inspect(v)
  end
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
    case process(v) do
      {processed, suf} -> Map.put(acc, suffix(k, suf), processed)
      processed -> Map.put(acc, suffix(k, get_suffix(processed)), processed)
    end
  end

  def add_to_log(member, acc) when is_bitstring(member) do
    Map.update(acc, :message, member, fn old -> "#{old} #{member}" end)
  end

  def add_to_log(%{__struct__: _type} = member, acc) when is_map(member) do
    add_to_log(inspect(member), acc)
  end

  def add_to_log(member, acc) when is_map(member) do
    Enum.reduce(member, acc, &add_kv_to_log/2)
  end

  def add_to_log(member, acc) when is_list(member) do
    if Keyword.keyword? member do
      add_to_log(Enum.into(member, %{}), acc)
    else
      Map.merge(acc, %{payload_str: inspect(member)})
    end
  end

  def add_to_log(member, acc) do
    Map.merge(acc, %{payload_str: inspect(member)})
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

  def transform(list), do: Enum.reduce(list, %{}, &Woody.Logger.add_to_log/2) 

  def log(lvl, list, caller) do
    %{module: m, file: file, function: f, line: l} = caller
    quote do
      unquoted = unquote(list)
      msg_map = try do
        Woody.Logger.transform(unquoted)
      rescue e ->
        if System.get_env("WOODY_DEBUG") == "true" do 
          IO.puts "woody error #{inspect(e)}"
          IO.puts "trying to log #{inspect(unquoted)}"
        end
        %{message: inspect(unquoted)}
      end
      map_with_metadata = msg_map |> Woody.Logger.wrap_with_metadata(unquote(lvl), unquote(m), unquote(file), unquote(f), unquote(l))
      case Poison.encode(map_with_metadata) do
        {:ok, json} -> Logger.log(unquote(lvl), json)
        {:error, err} -> Logger.log(unquote(lvl), inspect(map_with_metadata))
      end
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

