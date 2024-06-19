defmodule Omni.MixProject do
  use Mix.Project

  def project do
    [
      app: :omni,
      name: "Omni",
      description: "One client for all LLMs. Universal Elixir chat completion API client.",
      source_url: "https://github.com/lebrunel/omni",
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: [
        name: "omni",
        files: ~w(lib .formatter.exs mix.exs README.md LICENSE),
        licenses: ["Apache-2.0"],
        links: %{
          "GitHub" => "https://github.com/lebrunel/omni"
        }
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      {:plug, "~> 1.15", only: :test},
      {:recase, "~> 0.8"},
      {:req, "~> 0.5"},
    ]
  end

  # ExDoc config
  defp docs do
    [
      main: "Omni",
      groups_for_modules: [
        "Providers": ~r/^Omni\.Providers\..+$/
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
