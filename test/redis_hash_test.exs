defmodule RedisHashTest do
  use ExUnit.Case, async: true

  setup context do
    redis_hash = RedisHash.new(context[:test])
    test_map = %{"hola" => "hi", "abc" => 1, "list" => [1, :"2", "3"]}
    {:ok, [redis_hash: redis_hash, test_map: test_map]}
  end

  # Tests

  test "dump and merge", %{redis_hash: rhash, test_map: map} do
    assert RedisHash.dump(rhash) == %{}
    refute RedisHash.unpushed_changes?(rhash)

    rhash = RedisHash.merge(rhash, map)
    assert RedisHash.dump(rhash) == map
    assert RedisHash.unpushed_changes?(rhash)
  end

  test "pull and push", %{redis_hash: rhash, test_map: map} = context do
    rhash = rhash |> RedisHash.merge(map) |> RedisHash.push
    assert RedisHash.dump(rhash) == map
    refute RedisHash.unpushed_changes?(rhash)

    rhash2 = RedisHash.new(context[:test])
    assert RedisHash.dump(rhash) == map
    refute RedisHash.unpushed_changes?(rhash)
    rhash2 = rhash2 |> RedisHash.merge(%{changes: true}) |> RedisHash.push

    assert RedisHash.dump(rhash) != RedisHash.dump(rhash2)
    rhash = RedisHash.pull(rhash)
    assert RedisHash.dump(rhash) == RedisHash.dump(rhash2)
  end

  test "dont push when no changes occured", %{redis_hash: rhash, test_map: map} do
    rhash = rhash |> RedisHash.merge(map) |> RedisHash.push
    assert RedisHash.dump(rhash) == map
    refute RedisHash.unpushed_changes?(rhash)

    rhash = rhash |> RedisHash.merge(map)
    refute RedisHash.unpushed_changes?(rhash)
    # This won't crash, but will produce an error message if we would be trying to push an empty set of changes
    rhash = rhash |> RedisHash.push
    refute RedisHash.unpushed_changes?(rhash)
  end

  test "clear", %{redis_hash: rhash, test_map: map} = context do
    rhash = rhash |> RedisHash.merge(map) |> RedisHash.push
    dump = RedisHash.dump(rhash)
    assert dump == map

    RedisHash.clear(rhash)

    rhash2 = RedisHash.new(context[:test])
    assert RedisHash.dump(rhash2) == %{}
  end
end
