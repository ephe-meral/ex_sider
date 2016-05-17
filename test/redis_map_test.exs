defmodule RedisMapTest do
  use ExUnit.Case, async: true

  setup do
    redis_map = RedisMap.new()
    {:ok, redis_map: redis_map}
  end

  # Tests

  test "into and fetch", %{redis_map: rmap} = context do
    for x <- 1..10,
        into: rmap,
        do: {"#{context[:test]}:#{x}", x}

    for x <- 1..10, do: assert RedisMap.fetch(rmap, "#{context[:test]}:#{x}") == {:ok, x}
  end

  test "get_and_update and drop", %{redis_map: rmap} = context do
    # non-existing vals should be inserted
    for x <- 1..10, do: RedisMap.get_and_update(rmap, "#{context[:test]}:#{x}", fn _ -> {x, x} end)
    # checks...
    for x <- 1..10, do: assert RedisMap.fetch(rmap, "#{context[:test]}:#{x}") == {:ok, x}

    # existing ones should be updated
    for x <- 1..5, do: RedisMap.get_and_update(rmap, "#{context[:test]}:#{x}", fn x -> {x*x, x*x} end)
    # checks...
    for x <- 1..5, do: assert RedisMap.fetch(rmap, "#{context[:test]}:#{x}") == {:ok, x*x}
    for x <- 6..10, do: assert RedisMap.fetch(rmap, "#{context[:test]}:#{x}") == {:ok, x}

    # :pop & drop deletes vals
    for x <- 1..2, do: RedisMap.get_and_update(rmap, "#{context[:test]}:#{x}", fn _ -> :pop end)
    drops = for x <- 3..5, do: "#{context[:test]}:#{x}"
    RedisMap.drop(rmap, drops)
    # checks...
    for x <- 1..5, do: assert RedisMap.fetch(rmap, "#{context[:test]}:#{x}") == :error
    for x <- 6..10, do: assert RedisMap.fetch(rmap, "#{context[:test]}:#{x}") == {:ok, x}
  end

  test "access proto", %{redis_map: rmap} = context do
    key = context[:test]
    assert rmap[key] == nil
    assert put_in(rmap[key], %{a: 1, b: 2}) == rmap
    assert rmap[key][:a] == 1
    assert rmap[key][:b] == 2
    assert rmap[key][:c] == nil
  end
end
