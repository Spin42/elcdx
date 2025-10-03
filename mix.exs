defmodule Elcdx.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/Spin42/elcdx"

  def project do
    [
      app: :elcdx,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:circuits_uart, "~> 1.4"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Elixir library for communicating with ELCD LCD display modules via UART.
    Provides a simple API for controlling LCD displays, including text display,
    cursor control, and screen management.
    """
  end

  defp package do
    [
      maintainers: ["Marc"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*)
    ]
  end

  defp docs do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
