# Taken from the Redix samples in their README.md
defmodule ExSider.RedixPool do
  @moduledoc false
  use Supervisor

  def load_opts do
    host = Application.get_env(:ex_sider, :redis_host)
    port = Application.get_env(:ex_sider, :redis_port) |> String.to_integer
    [host: host, port: port]
  end

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts)

  def init(opts) do
    pool_opts = [
      name: {:local, :redix_poolboy},
      worker_module: Redix,
      size: 10,
      max_overflow: 5,
    ]

    children = [
      :poolboy.child_spec(:redix_poolboy, pool_opts, opts)
    ]

    supervise(children, strategy: :one_for_one, name: __MODULE__)
  end

  # API
  # sample usage:
  #     RedixPool.command(~w(PING)) #=> {:ok, "PONG"}

  def command(command), do: :poolboy.transaction(:redix_poolboy, &Redix.command(&1, command))

  def pipeline(commands), do: :poolboy.transaction(:redix_poolboy, &Redix.pipeline(&1, commands))
end
