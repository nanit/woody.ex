defmodule Woody.Mixfile do
  use Mix.Project

  def project do
    [
      app: :woody,
      version: "0.1.3",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      description: "Logging utilities",
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Woody.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:poison, "~> 3.1"},
      {:plug, "~> 1.0"},
      {:timex, "~> 3.1"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp package do
    [ name: :woody,
      files: ["lib", "mix.exs"],
      maintainers: ["Erez Rabih"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/nanit/woody.ex"}]
  end
end
