ExUnit.start

{:ok, _} = ExSider.RedixPool.command(["FLUSHDB"])
