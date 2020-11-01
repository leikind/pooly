defmodule Pooly.Mixfile do
  use Mix.Project

  def project do
    [
      app: :pooly,
      version: "0.1.0",
      elixir: "~> 1.0",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      applications: [:logger],
      # hardcoded first.
      mod: {Pooly, []}
    ]
  end

  defp deps do
    [{:credo, "~> 1.4", only: :dev}]
  end
end
