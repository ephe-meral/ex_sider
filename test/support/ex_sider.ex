defmodule ExSider do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(ExSider.RedixPool, [ExSider.RedixPool.load_opts]),
    ]

    opts = [strategy: :one_for_one, name: ExSider.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

