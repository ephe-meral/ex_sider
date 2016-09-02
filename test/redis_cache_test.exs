defmodule RedisCacheTest do
  use ExUnit.Case, async: true

  setup context do
    redis_hash = RedisCache.new(context[:test])
    test_map = %{"hola" => "hi", "abc" => 1, "def" => 1, "list" => [1, :"2", "3"]}
    {:ok, [redis_hash: redis_hash, test_map: test_map]}
  end

  # Tests

  test "dump and merge", %{redis_hash: rhash, test_map: map} do
    assert RedisCache.dump(rhash) == %{}
    refute RedisCache.unpushed_changes?(rhash)

    rhash = RedisCache.merge(rhash, map)
    assert RedisCache.dump(rhash) == map
    assert RedisCache.unpushed_changes?(rhash)
  end

  test "pull and push", %{redis_hash: rhash, test_map: map} = context do
    rhash = rhash |> RedisCache.merge(map) |> RedisCache.push
    assert RedisCache.dump(rhash) == map
    refute RedisCache.unpushed_changes?(rhash)

    rhash2 = RedisCache.new(context[:test])
    assert RedisCache.dump(rhash) == map
    refute RedisCache.unpushed_changes?(rhash)
    rhash2 = rhash2 |> RedisCache.merge(%{changes: true}) |> RedisCache.push

    assert RedisCache.dump(rhash) != RedisCache.dump(rhash2)
    rhash = RedisCache.pull(rhash)
    assert RedisCache.dump(rhash) == RedisCache.dump(rhash2)
  end

  test "dont push when no changes occured", %{redis_hash: rhash, test_map: map} do
    rhash = rhash |> RedisCache.merge(map) |> RedisCache.push
    assert RedisCache.dump(rhash) == map
    refute RedisCache.unpushed_changes?(rhash)

    rhash = rhash |> RedisCache.merge(map)
    refute RedisCache.unpushed_changes?(rhash)
    # This won't crash, but will produce an error message if we would be trying to push an empty set of changes
    rhash = rhash |> RedisCache.push
    refute RedisCache.unpushed_changes?(rhash)
  end

  test "delete", %{redis_hash: rhash, test_map: map} = context do
    rhash = rhash |> RedisCache.merge(map) |> RedisCache.push
    dump = RedisCache.dump(rhash)
    assert dump == map

    RedisCache.delete(rhash)

    rhash2 = RedisCache.new(context[:test])
    assert %{} == RedisCache.dump(rhash2)
  end
end
