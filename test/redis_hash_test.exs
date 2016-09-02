defmodule RedisHashTest do
  use ExUnit.Case, async: true

  setup context do
    redis_hash = RedisHash.new(context[:test])
    test_map = %{"hola" => "hi", "abc" => 1, "def" => 1, "list" => [1, :"2", "3"]}
    {:ok, [redis_hash: redis_hash, test_map: test_map]}
  end

  # Tests

  test "pull and push", %{redis_hash: rhash, test_map: map} = context do
    :ok = rhash |> RedisHash.push(map)
    assert map == RedisHash.new(context[:test]) |> RedisHash.pull
  end

  test "delete", %{redis_hash: rhash, test_map: map} = context do
    :ok = rhash |> RedisHash.push(map)
    assert map == RedisHash.pull(rhash)

    RedisHash.delete(rhash)

    assert %{} == RedisHash.new(context[:test]) |> RedisHash.pull
  end

  test "concurrent updates on the same hashmap but different fields", %{redis_hash: rhash, test_map: map} = ctx do
    # Push some inital data
    :ok = rhash |> RedisHash.push(map)

    [Task.async(fn ->
      rhash |> RedisHash.push(%{"abc" => 1})
      rhash |> RedisHash.push(%{"abc" => 2})
      rhash |> RedisHash.push(%{"abc" => 3})
      rhash |> RedisHash.push(%{"abc" => 4})
    end),
    Task.async(fn ->
      rhash |> RedisHash.push(%{"def" => 1})
      rhash |> RedisHash.push(%{"def" => 2})
      rhash |> RedisHash.push(%{"def" => 3})
      rhash |> RedisHash.push(%{"def" => 4})
    end)]
    |> Enum.map(&Task.await/1)

    :timer.sleep(1000)

    map = RedisHash.new(ctx[:test]) |> RedisHash.pull
    assert map["abc"] == 4
    assert map["def"] == 4
  end
end
