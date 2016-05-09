use Mix.Config

config :ex_sider,
  redis_adapter: ExSider.RedixPool,
  redis_host: (System.get_env("REDIS_HOST") || "localhost"),
  redis_port: (System.get_env("REDIS_PORT") || "6379") # expect a string

config :logger,
  level: :debug,
  #level: :warn,
  compile_time_purge_level: :debug
  #compile_time_purge_level: :warn
