defmodule Circe.MixProject do
  use Mix.Project

  def project do
    [
      app: :circe,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      source_url: git_repository(),
      deps: deps(),
      elixirc_options: [warnings_as_errors: true],
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
      {:ex_doc, "~> 0.23.0", only: :dev, runtime: false},
    ]
  end

  defp description do
    """
    Tools to ease the manipulation of AST
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => git_repository(),
      },
    ]
  end

  defp git_repository do
    "https://github.com/Shakadak/circe.ex"
  end
end
