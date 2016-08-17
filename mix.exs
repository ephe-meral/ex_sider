defmodule ExSider.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_sider,
     version: "0.1.4",
     elixir: "~> 1.2",
     elixirc_paths: elixirc_paths(Mix.env),
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [{:poolboy, "~> 1.5", only: [:dev, :test]},
     {:redix, ">= 0.0.0", only: [:dev, :test]},
     {:coverex, "~> 1.4", only: :test},
     {:ex_doc, ">= 0.0.0", only: :dev}]
  end

  defp package do
    [maintainers: ["Johanna Appel"],
     licenses: ["WTFPL"],
     links: %{"GitHub" => "https://github.com/ephe-meral/ex_sider"}]
  end
end
