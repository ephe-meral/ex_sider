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

  test "put/3, get/2 and delete/2", %{redis_map: rmap} = context do
    key = context[:test]
    value = System.unique_integer
    RedisMap.put(rmap, key, value)
    assert RedisMap.get(rmap, key) == value
    RedisMap.delete(rmap, key)
    refute RedisMap.get(rmap, key)
  end

  test "access proto", %{redis_map: rmap} = context do
    key = context[:test]
    assert rmap[key] == nil
    assert put_in(rmap[key], %{a: 1, b: 2}) == rmap
    assert rmap[key][:a] == 1
    assert rmap[key][:b] == 2
    assert rmap[key][:c] == nil
  end

  test "pop/2", %{redis_map: rmap} = context do
    key = context[:test]
    value = System.unique_integer
    RedisMap.put(rmap, key, value)
    assert {^value, ^rmap} = RedisMap.pop(rmap, key)
  end

  test "take/2", %{redis_map: rmap} = context do
    for x <- 1..100, into: rmap, do: {"#{context[:test]}:#{x}", "val#{x}"}
    map = RedisMap.take(rmap, 1..100 |> Enum.map(&("#{context[:test]}:#{&1}")))
    vals = Map.values(map)
    assert similar(1..100 |> Enum.map(&("val#{&1}")), vals)
  end

  # Helpers

  def similar([_ | _] = list_a, [_ | _] = list_b)
  when length(list_a) != length(list_b), do: false

  def similar([_ | _] = list_a, [_ | _] = list_b) do
    list_a |> Enum.all?(fn x -> list_b |> Enum.member?(x) end)
  end
end
