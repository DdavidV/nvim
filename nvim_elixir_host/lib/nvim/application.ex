defmodule NvimHost.Application do
  use Application

  @impl true
  def start(_type, _args) do
    Nvim.Logger.configure!()
    {:ok, :nvim_api} = :nvim_rpc.ensure_api_bindings()

    children = [
      Nvim.Host,
      Nvim.Elixir.Extensions
    ]

    opts = [strategy: :one_for_one, name: NvimHost.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
