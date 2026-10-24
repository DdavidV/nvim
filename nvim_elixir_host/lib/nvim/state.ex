defmodule Nvim.Host.State do
  defstruct [
    :transport,
    buffer: "",
    next_request_id: 1,
    pending_requests: %{},
    handlers: %{},
    workers: %{}
  ]

  @type t() :: %__MODULE__{
          transport: pid(),
          buffer: binary(),
          next_request_id: :nvim_rpc.rpc_request_id(),
          pending_requests: %{:nvim_rpc.rpc_request_id() => {GenServer.from(), reference()}},
          handlers: %{binary() => function()},
          workers: %{pid() => {reference(), term(), :nvim_rpc.rpc_request_id(), integer()}}
        }
end
