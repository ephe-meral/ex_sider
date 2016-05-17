defmodule RedisSetTest do
  use ExUnit.Case, async: true

  setup context do
    redis_set = RedisSet.new(context[:test] |> to_string)
    {:ok, redis_set: redis_set}
  end

  # Tests

  test "put and retrieve member values", %{redis_set: rset} do
    # Since Redis is mutable, we dont need to assign anything here
    for x <- 1..10, into: rset, do: x

    assert Enum.count(rset) == 10

    for x <- 1..10, do: assert(Enum.member?(rset, x))
    refute Enum.member?(rset, 11)
  end

  test "handle the same values gracefully", %{redis_set: rset} do
    data = ["surprisingly", :we_can_store, "all kinds of data!!!", 1, 1, 1]

    for x <- data, into: rset, do: x

    assert similar(Enum.to_list(rset),
      ["surprisingly", :we_can_store, "all kinds of data!!!", 1])
  end

  # Helpers

  def similar([_ | _] = list_a, [_ | _] = list_b)
  when length(list_a) != length(list_b), do: false

  def similar([_ | _] = list_a, [_ | _] = list_b) do
    list_a |> Enum.all?(fn x -> list_b |> Enum.member?(x) end)
  end
end
