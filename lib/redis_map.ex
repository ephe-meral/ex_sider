defmodule RedisMap do
  @moduledoc """
  Implements Collectable and Access.
  Doesn't implement Enumerable, since Redis Key/Value sets should
  rather not be enumerated. (Its just one big map)
  """
  require Logger
  alias RedisMap

  @behaviour Access

  defstruct __redis_adapter__: nil, __binary_mode__: true

  def new(opts \\ []) do
    binary_mode = opts[:binary_mode] || true
    adapter = Application.get_env(:ex_sider, :redis_adapter)
    %RedisMap{
      __redis_adapter__: adapter,
      __binary_mode__: binary_mode}
  end

  @doc "Standard delete/2, uses drop/2 under the hood"
  def delete(%RedisMap{} = container, key), do: drop(container, [key])

  @doc "Drops several keys and their associated values at once. Used by get_and_update"
  def drop(%RedisMap{} = container, []), do: container
  def drop(%RedisMap{} = container, [_ | _] = keys) do
    string_keys = for key <- keys, is_binary(key) or is_atom(key), do: to_string(key)
    drop_internal(container, keys, string_keys)
  end

  defp drop_internal(%RedisMap{__redis_adapter__: adapter} = container, original_keys, string_keys)
  when length(original_keys) == length(string_keys) do
    case adapter.command(["DEL" | string_keys]) do
      {:ok, x} when is_number(x) -> container
      other ->
        Logger.error "RedisMap failed to call drop/2, got Redis reply: #{inspect other}"
        container
    end
  end
  defp drop_internal(%RedisMap{}, keys, _), do: raise ArgumentError, message: "invalid RedisMap keys, need to be List of String or Atom: #{inspect keys}"
  defp drop_internal(container, _keys, _),  do: raise ArgumentError, message: "invalid container, needs to be a RedisMap: #{inspect container}"

  @doc "Access implementation"
  def fetch(%RedisMap{__redis_adapter__: adapter, __binary_mode__: binary}, key)
  when is_binary(key) or is_atom(key) do
    case adapter.command(["GET", to_string(key)]) do
      {:ok, nil}             -> :error
      {:ok, val} when binary -> {:ok, :erlang.binary_to_term(val)}
      {:ok, val}             -> {:ok, val}
      other                  ->
        Logger.error "RedisMap failed to call fetch/2, got Redis reply: #{inspect other}"
        :error
    end
  end
  def fetch(%RedisMap{}, key), do: raise ArgumentError, message: "invalid RedisMap key, needs to be String or Atom: #{inspect key}"
  def fetch(container, _key),  do: raise ArgumentError, message: "invalid container, needs to be a RedisMap: #{inspect container}"

  @doc "Delegates to Access"
  defdelegate get(container, key),          to: Access
  defdelegate get(container, key, default), to: Access

  @doc "Access implementation"
  def get_and_update(%RedisMap{} = container, key, fun) do
    current =
      case fetch(container, key) do
        {:ok, val} -> val
        :error     -> nil
      end

    case fun.(current) do
      {get, update} ->
        [{key, update}] |> Enum.into(container)
        {get, container}
      :pop when is_nil(current) -> {current, container}
      :pop ->
        drop(container, [key])
        {current, container}
      other ->
        raise BadFunctionError, message: "invalid return type in RedisMap get_and_update/3, allowed is tuple and :pop, go: #{inspect other}"
    end
  end

  @doc "Standard put/3, based on Access implementation of put_in/2"
  def put(%RedisMap{} = container, key, value), do: put_in(container[key], value)

  def take(%RedisMap{} = container, [_ | _] = keys) do
    string_keys = for key <- keys, is_binary(key) or is_atom(key), do: to_string(key)
    take_internal(container, keys, string_keys)
  end

  defp take_internal(%RedisMap{__redis_adapter__: adapter, __binary_mode__: binary} = container, original_keys, string_keys)
  when length(original_keys) == length(string_keys) do
    case adapter.command(["MGET" | string_keys]) do
      {:ok, nil}  -> %{}
      {:ok, vals} ->
        vals =
          if binary, do: vals |> Enum.map(&:erlang.binary_to_term/1),
                   else: vals
        Enum.zip(string_keys, vals) |> Enum.into(%{})
      other                   ->
        Logger.error "RedisMap failed to call take/2, got Redis reply: #{inspect other}"
        %{}
    end
  end
  defp take_internal(%RedisMap{}, keys, _), do: raise ArgumentError, message: "invalid RedisMap keys, need to be List of String or Atom: #{inspect keys}"
  defp take_internal(container, _keys, _),  do: raise ArgumentError, message: "invalid container, needs to be a RedisMap: #{inspect container}"

end

defimpl Collectable, for: RedisMap do
  require Logger

  def into(%RedisMap{__redis_adapter__: adapter, __binary_mode__: binary} = original) do
    {%{}, fn
      map, {:cont, {k, v}} when (is_binary(k) or is_atom(k)) and binary ->
        Map.put(map, to_string(k), :erlang.term_to_binary(v))
      map, {:cont, {k, v}} when (is_binary(k) or is_atom(k)) and (is_binary(v) or is_atom(v)) ->
        Map.put(map, to_string(k), to_string(v))
      map, {:cont, x} ->
        Logger.error "RedisMap failed to call :cont in into/1 (will skip), got unexpected input: #{inspect x}"
        map
      map, :done ->
        vals = map |> Enum.reduce([], fn {k, v}, acc -> [k, v | acc] end)
        case adapter.command(["MSET" | vals]) do
          {:ok, "OK"} -> original
          other ->
            Logger.error("RedisMap failed to call into/1, got Redis reply: #{inspect other}")
            original
        end
      _, :halt -> :ok
    end}
  end
end
