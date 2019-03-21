defmodule Schemata.MixProject do
  use Mix.Project

  def project do
    [
      app: :schemata,
      version: "0.1.1",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      #{:ecto, "~> 2.0 or ~> 3.0"},
      {:ecto, "~> 3.0"},
      {:ex_doc, "~> 0.19.0", only: [:dev, :test]}
    ]
  end
end
