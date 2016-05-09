defmodule ExSider.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_sider,
     version: "0.1.0",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: Coverex.Task],
     deps: deps]
  end

  def application do
    [mod: {ExSider, []},
     applications: [:logger]]
  end

  defp deps do
    [{:poolboy, "~> 1.5"},
     {:redix, ">= 0.0.0"},
     {:coverex, "~> 1.4", only: :test}]
  end
end
