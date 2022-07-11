defmodule ChangesetExtras.MixProject do
  @moduledoc false

  use Mix.Project

  def project do
    [
      app: :changeset_extras,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "Changeset extras",
      source_url: "https://github.com/GabrielFeliciano/changeset_extras"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.6"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "A package that adds extra functions for dealing with changesets"
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/GabrielFeliciano/changeset_extras"}
    ]
  end
end
