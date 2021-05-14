defmodule Circe.MixProject do
  use Mix.Project

  def version, do: "0.1.0"

  def project do
    [
      app: :circe,
      version: version(),
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      source_url: git_repository(),
      deps: deps(),
      docs: docs(),
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
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
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
        "Changelog" => "https://hexdocs.pm/circe/changelog.html",
      },
    ]
  end

  def docs do
    [
      extras: [
        "CHANGELOG.md": [title: "Changelog"],
        "README.md": [title: "Overview"],
      ],
      api_reference: false,
      main: "readme",
      source_url: git_repository(),
      source_ref: "v#{version()}",
    ]
  end

  defp git_repository do
    "https://github.com/Shakadak/circe.ex"
  end
end
