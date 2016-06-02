[![Build Status](https://travis-ci.org/ephe-meral/ex_sider.svg?branch=master)](https://travis-ci.org/ephe-meral/ex_sider)
[![Hex.pm](https://img.shields.io/hexpm/l/ex_sider.svg "WTFPL Licensed")](https://github.com/ephe-meral/ex_sider/blob/master/LICENSE)
[![Hex version](https://img.shields.io/hexpm/v/ex_sider.svg "Hex version")](https://hex.pm/packages/ex_sider)


# ex_sider

Elixir &lt;-> Redis datastructure adapter

## setup

In your `mix.exs` file:

```elixir
def deps do
  [{:ex_sider, "~> 0.1.0"},
   # the following is only needed if using a Redix pool:
   {:poolboy, "~> 1.5"},
   {:redix, ">= 0.0.0"}]
end
```

In your config file:

```elixir
config ex_sider,
  redis_adapter: MyApp.RedixPool # currently the only supported adapter, see below

# also make sure to configure the redis adapter correctly
```

## use case

This can be used (potentially, if necessary) with different Redis adapters, but for
now I'll stick with [Redix](https://github.com/whatyouhide/redix). From the example
we can create a new RedixPool e.g. like so:

```elixir
# Copied from github.com/whatyouhide/redix README.md
defmodule MyApp.RedixPool do
  use Supervisor

  @redis_connection_params host: "localhost", password: ""

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    pool_opts = [
      name: {:local, :redix_poolboy},
      worker_module: Redix,
      size: 10,
      max_overflow: 5,
    ]

    children = [
      :poolboy.child_spec(:redix_poolboy, pool_opts, @redis_connection_params)
    ]

    supervise(children, strategy: :one_for_one, name: __MODULE__)
  end

  def command(command) do
    :poolboy.transaction(:redix_poolboy, &Redix.command(&1, command))
  end

  def pipeline(commands) do
    :poolboy.transaction(:redix_poolboy, &Redix.pipeline(&1, commands))
  end
end
```

We now update our `ex_sider` config with the correct module name (see above), and also make sure that the RedixPool is started when we start our Application:

```elixir
defmodule MyApp do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # ...
      supervisor(MyApp.RedixPool, [[]]),
      # ...
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Finally, after this setup, we can use the `ex_redis` modules like any normal Map, Set or List, e.g.:
(Actually, take this with a grain of salt: Since this is an ongoing effort, interfaces might be incomplete - but please request specific improvements or contribute!)

```elixir
redis_set = RedisSet.new("my-set-name")

# by default, ex_sider uses a 'binary' mode, where it pipes all
# terms given to it into :erlang.term_to_binary/1, and all terms
# that it retrieves through :erlang.binary_to_term/1
data = ["surprisingly", :we_can_store, "all kinds of data!!!", 1, 1, 1]

# we can use for comprehensions:
for x <- data, into: redis_set, do: x

# and any kind of Enum operation, e.g.:
Enum.to_list(redis_set)
# => ["surprisingly", :we_can_store, "all kinds of data!!!", 1]
# note the missing 1's because we are using a RedisSet
```

## remarks

**Mutability** - All datastructures implemented here are mutable, that means, that every operation that changes any part of them (i.e. writes data) will change for all parts of the application that have a reference to this datastructure. This is because we actually only implement a thin adapter layer based on Elixir Protocols, that interface with redis in order to store data.

**Binary Data** - Any data will, by default, be stored as an erlang term that is being converted to binary beforehand. That means that - in case you access Redis without `ex_sider` - that you will have to call `:erlang.binary_to_term` on anything that you retrieve from it. If that is not an option for you, simply disable binary mode when initialising the datastructure:

```elixir
# to disable binary mode (only values that are binaries can be used then, like e.g. elixir strings)
redis_set = RedisSet.new("my-set-name", binary_mode: false)
```

**This Project** - This project is supposed to be a helper to make interfacing with Redis simpler. It is by no means: complete, perfectly documented or otherwise done. Any help is appreciated, just fork & PR, create issues etc. Business as usual.

## is it any good?

bien sûr.
