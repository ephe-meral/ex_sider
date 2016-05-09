defmodule RedisSetTest do
  use ExUnit.Case, async: true

  setup_all do
    {:ok, _} = ExSider.RedixPool.command(["FLUSHDB"])
    on_exit fn ->
      {:ok, _} = ExSider.RedixPool.command(["FLUSHDB"])
    end

    :ok
  end

  test "put and retrieve member values", context do
    rset = RedisSet.new(context[:test] |> to_string)

    # Since Redis is mutable, we dont need to assign anything here
    for x <- 1..10, into: rset, do: x

    assert Enum.count(rset) == 10

    for x <- 1..10, do: assert(Enum.member?(rset, x))
    refute Enum.member?(rset, 11)
  end
end
