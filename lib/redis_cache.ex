defmodule RedisCache do
  @moduledoc """
  Currently only works by merging/replacing with maps and then pull/push-ing.

  In the future, this should implement `Access`, `Enumerable` and `Collectable` - meaning
  this could then be used with Elixir's `Enum` w/o limitations. These should work
  independant of whether or not local caching is used.

  You can let this cache its values locally and commit them back to the repo
  on demand. This doesn't handle inconsistencies etc. - the use case is to have
  a relatively longer term storage (redis semantics) for process related data.
  In case a process gets restarted etc. it can quickly commit and
  refetch its state later on. Obviously gets tricky if multiple processes
  use the same redis-hash.

  Conflicts and race conditions are tried to be avoided, but essentially this
  is a very simplistic grow-only set. (You can delete the whole thing, but not
  single entries for now)

  This will fetch the state of the hash when it is created, and will
  try to keep it up to date with the external version whenever you do pulls and
  pushes to redis.
  """
  require Logger
  alias RedisCache

  defstruct(
    __redis_hash__: nil,
    __local_cache__: %{},
    __local_changes__: %{})

  @doc """
  This will checkout the initial cache state from
  redis upon creation.

  Options:

  * `:binary_mode` - true/false depending on whether data should be put through
  `:erlang.term_to_binary` and `:erlang.binary_to_term` respectively or not (default: true)
  """
  def new(redis_key), do: new(redis_key, [])
  def new(redis_key, opts) when is_atom(redis_key), do: new(redis_key |> to_string, opts)
  def new(redis_key, opts) when is_binary(redis_key) do
    %RedisCache{
      __redis_hash__: RedisHash.new(redis_key, opts),
      __local_cache__: %{},
      __local_changes__: %{}}
    |> pull
  end

  @doc "Returns the underlying cached map. This does not pull in changes beforehand!"
  def dump(%RedisCache{__local_cache__: cache}), do: cache

  @doc """
  Merges the fields of the given map into the RedisCache, overwriting existing fields in
  the cache and possibly causing local (unpushed) changes.
  """
  def merge(%RedisCache{__local_cache__: cache, __local_changes__: changes} = container, %{} = other_map) do
    other_map = ensure_keys_are_string(other_map)
    new_cache = cache |> Map.merge(other_map)
    new_changes = changes |> Map.merge(map_diff(cache, new_cache))
    %RedisCache{container | __local_cache__: new_cache, __local_changes__: new_changes}
  end

  @doc "Delete this hash from the Redis repo and clear the local cache, if any."
  def delete(%RedisCache{__redis_hash__: rhash} = container) do
    RedisHash.delete(rhash)
    %RedisCache{container | __local_cache__: %{}, __local_changes__: %{}}
  end

  @doc """
  Pulls all fields of this hash from Redis and merges it with the current local cache if any.
  This doesn't change the local-cache state of the RedisCache.
  """
  def pull(%RedisCache{__redis_hash__: rhash, __local_cache__: cache, __local_changes__: changes} = container) do
    case RedisHash.pull(rhash) do
      nil -> container
      %{} = data ->
        new_cache = cache |> Map.merge(data)
        new_changes = changes |> Map.merge(map_diff(cache, new_cache))
        %RedisCache{container | __local_cache__: new_cache, __local_changes__: new_changes}
    end
  end

  @doc """
  Push all local keys/values back to the Redis repo.
  This simply overwrites whatever is already in there.
  """
  def push(%RedisCache{__local_changes__: changes} = container), do: do_push(Enum.empty?(changes), container)

  defp do_push(true, container), do: container
  defp do_push(false, %RedisCache{__redis_hash__: rhash, __local_changes__: changes} = container) do
    case RedisHash.push(rhash, changes) do
      :ok -> %RedisCache{container | __local_changes__: %{}} |> pull
      _   -> container
    end
  end

  @doc """
  Check if we have local unpushed changes.
  """
  def unpushed_changes?(%RedisCache{__local_changes__: changes}), do: not Enum.empty?(changes)

  # Helpers

  defp ensure_keys_are_string(map) do
    map
    |> Enum.map(
      fn {key, val} when is_atom(key)   -> {key |> to_string, val}
         {key, val} when is_binary(key) -> {key, val}
         {key, _val} ->
           raise "For maps to work with Redis, their keys must be strings or atoms, and they will always be cast to string. Got: #{inspect key}"
      end)
    |> Enum.into(%{})
  end

  # Shallow diff of 2 maps (shallow b/c redis only supports one level of sub-keys anyway)
  # Result is what is changed and new in map2
  defp map_diff(map1, map2) do
    map2 |> Enum.reduce(%{}, fn {key, map2_val}, acc ->
      case map1[key] do
        map1_val when map1_val == map2_val -> acc
        _                                  -> acc |> Map.put(key, map2_val)
      end
    end)
  end
end
