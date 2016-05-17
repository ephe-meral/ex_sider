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

  def drop_internal(_container, keys), do: raise ArgumentError, message: "invalid RedisMap keys, need to be List of String or Atom: #{inspect keys}"

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

  def fetch(_container, key), do: raise ArgumentError, message: "invalid RedisMap key, needs to be String or Atom: #{inspect key}"

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
