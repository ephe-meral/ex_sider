defmodule ExSider.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_sider,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: Coverex.Task],
     deps: deps,
     description: "Elixir Map/List/Set interfaces for Redis datastructures.",
     package: package]
  end

  def application do
    [mod: {ExSider, []},
     applications: [:logger]]
  end

  defp deps do
    [{:poolboy, "~> 1.5", only: [:dev, :test]},
     {:redix, ">= 0.0.0", only: [:dev, :test]},
     {:coverex, "~> 1.4", only: :test}]
  end

  defp package do
    [maintainers: ["Johanna Appel"],
     licenses: ["WTFPL"],
     links: %{"GitHub" => "https://github.com/ephe-meral/ex_sider"}]
  end
end
