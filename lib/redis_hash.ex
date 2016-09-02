defmodule RedisHash do
  @moduledoc """
  Offers read and write access to Redis' hash functions,
  without caching. All functions directly result in calls to Redis.

  Writing data will always overwrite existing values.
  """
  require Logger
  alias RedisHash

  defstruct(
    __redis_key__: nil,
    __redis_adapter__: nil,
    __binary_mode__: true)

  @doc """
  If local caching is enabled, this will checkout the initial cache state from
  redis upon creation.

  Options:

  * `:binary_mode` - true/false depending on whether data should be put through
  `:erlang.term_to_binary` and `:erlang.binary_to_term` respectively or not (default: true)
  """
  def new(redis_key), do: new(redis_key, [])
  def new(redis_key, opts) when is_atom(redis_key), do: new(redis_key |> to_string, opts)
  def new(redis_key, opts) when is_binary(redis_key) do
    binary_mode = opts[:binary_mode] || true
    adapter = Application.get_env(:ex_sider, :redis_adapter)
    %RedisHash{
      __redis_key__: redis_key,
      __redis_adapter__: adapter,
      __binary_mode__: binary_mode}
  end

  @doc "Delete this hash from the Redis repo."
  def delete(%RedisHash{__redis_key__: key, __redis_adapter__: adapter} = container) do
    case adapter.command(["DEL", key]) do
      {:ok, x} when is_number(x) -> container
      other ->
        Logger.error "RedisHash failed to call delete/1, got Redis reply: #{inspect other}"
        container
    end
  end

  @doc "Pulls all fields of this hash from Redis. Returns nil or a map."
  def pull(%RedisHash{__redis_key__: key, __redis_adapter__: adapter, __binary_mode__: binary}) do
    case adapter.command(["HGETALL", key]) do
      {:ok, nil} -> nil
      {:ok, []}  -> %{}
      {:ok, fields} when is_list(fields) -> extract_map(fields, %{}, binary)
      other ->
        Logger.error("RedisHash failed to call pull/1, got Redis reply: #{inspect other}")
        nil
    end
  end

  @doc """
  Push all local keys/values back to the Redis repo.
  This simply overwrites whatever is already in there.
  Returns ok or error and the reason.
  """
  def push(%RedisHash{__redis_key__: key, __redis_adapter__: adapter, __binary_mode__: binary}, %{} = data) do
    data = ensure_keys_are_string(data)
    fields = data |> Enum.reduce([], fn
      {key, value}, acc when binary -> [key, :erlang.term_to_binary(value) | acc]
      {key, value}, acc             -> [key, value | acc]
    end)
    case adapter.command(["HMSET", key | fields]) do
      {:ok, "OK"} -> :ok
      other ->
        Logger.error("RedisHash failed to call push/1, got Redis reply: #{inspect other}")
        {:error, :redis_hmset_failed}
    end
  end

  defp extract_map([], acc, _binary_mode),             do: acc
  defp extract_map([key, value | fields], acc, true),  do: extract_map(fields, acc |> Map.put(key, :erlang.binary_to_term(value)), true)
  defp extract_map([key, value | fields], acc, false), do: extract_map(fields, acc |> Map.put(key, value), false)
  defp extract_map(_, acc, _binary_mode) do
    Logger.error("RedisHash failed to extract key/values from the listing given by redis.")
    acc
  end

  defp ensure_keys_are_string(%{} = map) do
    map
    |> Enum.map(
      fn {key, val} when is_atom(key)   -> {key |> to_string, val}
         {key, val} when is_binary(key) -> {key, val}
         {key, _val} ->
           raise "For maps to work with Redis, their keys must be strings or atoms, and they will always be cast to string. Got: #{inspect key}"
      end)
    |> Enum.into(%{})
  end
end
