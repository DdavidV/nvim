defmodule NvimHost.MixProject do
  use Mix.Project

  def project do
    [
      app: :nvim_elixir_host,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {NvimHost.Application, []}
    ]
  end

  defp deps do
    [
      {:nvim_rpc, path: "../nvim_erlang_rpc", manager: :rebar3}
    ]
  end
end
