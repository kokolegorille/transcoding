defmodule Transcoding.MixProject do
  use Mix.Project

  def project do
    [
      app: :transcoding,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:ex_image_info, "~> 0.2.4"},
      {:mime, "~> 2.0"},
    ]
  end
end
