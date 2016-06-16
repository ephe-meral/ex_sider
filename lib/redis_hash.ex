defmodule RedisHash do
  @moduledoc """
  Currently only works by merging/replacing with maps and then pull/push-ing.

  In the future, this should implement `Access`, `Enumerable` and `Collectable` - meaning
  this can be used with Elixir's `Enum` w/o limitations. These should work
  independant of whether or not local caching is used.

  You can let this cache its values locally and commit them back to the repo
  on demand. This doesn't handle inconsistencies etc. - the use case is to have
  a relatively longer term storage (redis semantics) for process related data.
  In case a process gets restarted etc. it can quickly commit and
  refetch its state later on. Obviously gets tricky if multiple processes
  use the same redis-hash.
  """
  require Logger
  alias RedisHash

  defstruct(
    __redis_key__: nil,
    __redis_adapter__: nil,
    __binary_mode__: true,
    __local_cache_enabled__: true,
    __local_cache__: %{},
    __local_changes__: false)

  @doc """
  If local caching is enabled, this will checkout the initial cache state from
  redis upon creation.

  Options:

  * `:binary_mode` - true/false depending on whether data should be put through
  `:erlang.term_to_binary` and `:erlang.binary_to_term` respectively or not (default: true)
  * `:local_cache` - true/false to enable or disable local caching (default: true)
  """
  def new(redis_key), do: new(redis_key, [])
  def new(redis_key, opts) when is_atom(redis_key), do: new(redis_key |> to_string, opts)
  def new(redis_key, opts) when is_binary(redis_key) do
    binary_mode = opts[:binary_mode] || true
    local_cache_enabled = opts[:local_cache] || true
    adapter = Application.get_env(:ex_sider, :redis_adapter)
    hash =
      %RedisHash{
        __redis_key__: redis_key,
        __redis_adapter__: adapter,
        __binary_mode__: binary_mode,
        __local_cache_enabled__: local_cache_enabled}
    if local_cache_enabled, do: pull(hash),
                          else: hash
  end

  @doc """
  Returns the underlying cached map. This does not pull in changes beforehand!
  """
  def dump(%RedisHash{__local_cache_enabled__: true, __local_cache__: cache}), do: cache
  def dump(%RedisHash{__local_cache_enabled__: false}) do
    Logger.error("RedisHash dump/1 called on hash with disabled local cache")
    %{}
  end

  @doc """
  Merges the fields of the given map into the RedisHash, overwriting existing fields in
  the cache and possibly causing local (unpushed) changes.

  If this is used with a non-local-cached RedisHash, the given map is merged directly into
  the Redis hash in the redis repo!
  """
  def merge(%RedisHash{__local_cache_enabled__: true, __local_cache__: cache, __local_changes__: changes} = container, %{} = other_map) do
    other_map = ensure_keys_are_string(other_map)
    new_cache = cache |> Map.merge(other_map)
    %RedisHash{container | __local_cache__: new_cache, __local_changes__: (changes or (cache != new_cache))}
  end
  def merge(%RedisHash{__local_cache_enabled__: false} = container, %{} = other_map) do
    other_map = ensure_keys_are_string(other_map)
    push(%RedisHash{container | __local_cache__: other_map})
    container
  end

  @doc """
  Clear this hash from the Redis repo and clear the local cache, if any.
  """
  def clear(%RedisHash{__redis_key__: key, __redis_adapter__: adapter} = container) do
    case adapter.command(["DEL", key]) do
      {:ok, x} when is_number(x) -> %RedisHash{container | __local_cache__: %{}, __local_changes__: false}
      other ->
        Logger.error "RedisHash failed to call delete/1, got Redis reply: #{inspect other}"
        container
    end
  end

  @doc """
  Pulls all fields of this hash from Redis and merges it with the current local cache if any.
  This doesn't change the local-cache state of the RedisHash.
  """
  def pull(%RedisHash{__redis_key__: key, __redis_adapter__: adapter, __binary_mode__: binary, __local_cache__: cache} = container) do
    case adapter.command(["HGETALL", key]) do
      {:ok, nil} -> container
      {:ok, []}  -> container
      {:ok, fields} when is_list(fields) ->
        local_count = Enum.count(cache)
        local_cache = extract_map(fields, cache, binary)
        %RedisHash{container | __local_cache__: local_cache, __local_changes__: (Enum.count(local_cache) > local_count)}
      other ->
        Logger.error("RedisHash failed to call pull/1, got Redis reply: #{inspect other}")
        container
    end
  end

  @doc """
  Push all local keys/values back to the Redis repo.
  This simply overwrites whatever is already in there.
  """
  def push(%RedisHash{__redis_key__: key, __redis_adapter__: adapter, __binary_mode__: binary, __local_cache__: cache} = container) do
    fields = cache |> Enum.reduce([], fn
      {key, value}, acc when binary -> [key, :erlang.term_to_binary(value) | acc]
      {key, value}, acc             -> [key, value | acc]
    end)
    case adapter.command(["HMSET", key | fields]) do
      {:ok, "OK"} ->
        %RedisHash{container | __local_changes__: false}
      other ->
        Logger.error("RedisHash failed to call pull/1, got Redis reply: #{inspect other}")
        container
    end
  end

  @doc """
  Check if we have local unpushed changes.
  """
  def unpushed_changes?(%RedisHash{__local_changes__: changes}), do: changes

  defp extract_map([], acc, _binary_mode),             do: acc
  defp extract_map([key, value | fields], acc, true),  do: extract_map(fields, acc |> Map.put(key, :erlang.binary_to_term(value)), true)
  defp extract_map([key, value | fields], acc, false), do: extract_map(fields, acc |> Map.put(key, value), false)
  defp extract_map(_, acc, _binary_mode) do
    Logger.error("RedisHash failed to extract key/values from the listing given by redis.")
    acc
  end

  defp ensure_keys_are_string(map) do
    map =
      map
      |> Enum.map(fn {key, val} when is_atom(key) -> {key |> to_string, val}
                     {key, val}                   -> {key, val}
                  end)
      |> Enum.into(%{})

    for {key, _} <- map, not is_binary(key),
    do: raise "For maps to work with RedisHash, their keys must be strings or atoms, and they will always be cast to string."

    map
  end
end
