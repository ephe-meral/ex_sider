defmodule RedisSet do
  alias RedisSet

  defstruct __redis_key__: nil, __redis_adapter__: nil, __binary_mode__: true

  def new(redis_key, opts \\ []) when is_binary(redis_key) do
    binary_mode = opts[:binary_mode] || true
    adapter = Application.get_env(:ex_sider, :redis_adapter)
    %RedisSet{
      __redis_key__: redis_key,
      __redis_adapter__: adapter,
      __binary_mode__: binary_mode}
  end
end

defimpl Enumerable, for: RedisSet do
  require Logger

  def reduce(%RedisSet{__redis_key__: key, __redis_adapter__: adapter, __binary_mode__: binary}, acc, fun) do
    case adapter.command(["SMEMBERS", key]) do
      {:ok, members} when is_list(members) -> do_reduce(members, acc, fun, binary)
      other ->
        Logger.error("RedisSet failed to call reduce/3, got Redis reply: #{inspect other}")
        do_reduce([], acc, fun, binary)
    end
  end

  def do_reduce(_,       {:halt, acc}, _fun, _binary),  do: {:halted, acc}
  def do_reduce(list,    {:suspend, acc}, fun, binary), do: {:suspended, acc, &do_reduce(list, &1, fun, binary)}
  def do_reduce([],      {:cont, acc}, _fun, _binary),  do: {:done, acc}
  def do_reduce([h | t], {:cont, acc}, fun, true),      do: do_reduce(t, fun.(:erlang.binary_to_term(h), acc), fun, true)
  def do_reduce([h | t], {:cont, acc}, fun, false),     do: do_reduce(t, fun.(h, acc), fun, false)

  def member?(%RedisSet{__redis_key__: key, __redis_adapter__: adapter, __binary_mode__: binary}, value) do
    value = if binary, do: :erlang.term_to_binary(value), else: value
    case adapter.command(["SISMEMBER", key, value]) do
      {:ok, 1} -> {:ok, true}
      {:ok, 0} -> {:ok, false}
      other ->
        Logger.error("RedisSet failed to call member?/2, got Redis reply: #{inspect other}")
        {:error, :redis_error}
    end
  end

  def count(%RedisSet{__redis_key__: key, __redis_adapter__: adapter}) do
    case adapter.command(["SCARD", key]) do
      {:ok, count} -> {:ok, count}
      other ->
        Logger.error("RedisSet failed to call count/1, got Redis reply: #{inspect other}")
        {:error, :redis_error}
    end
  end
end

defimpl Collectable, for: RedisSet do
  require Logger

  def into(%RedisSet{__redis_key__: key, __redis_adapter__: adapter, __binary_mode__: binary} = original) do
    {[], fn
      list, {:cont, x} when binary -> [:erlang.term_to_binary(x) | list]
      list, {:cont, x}             -> [x | list]
      list, :done ->
        list = Enum.uniq(list)
        case adapter.command(["SADD", key] ++ list) do
          {:ok, x} when x == length(list) -> original
          other ->
            Logger.error("RedisSet failed to call into/1, got Redis reply: #{inspect other}")
            original
        end
      _, :halt -> :ok
    end}
  end
end
