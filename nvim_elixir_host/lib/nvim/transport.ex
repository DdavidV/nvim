defmodule Nvim.Transport do
  use GenServer

  def send_data(pid, data) when is_binary(data) do
    GenServer.call(pid, {:send, data})
  end

  def start_link(owner) do
    GenServer.start_link(__MODULE__, owner)
  end

  @impl true
  def init(owner) do
    Process.flag(:trap_exit, true)

    port = Port.open({:fd, 0, 1}, [:binary, :eof])

    {:ok, %{port: port, owner: owner}}
  end

  @impl true
  def handle_call({:send, data}, _from, state) do
    case Port.command(state.port, data) do
      true ->
        {:reply, :ok, state}

      false ->
        {:stop, :port_closed, {:error, :port_closed}, state}
    end
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    send(state.owner, {:transport_data, data})
    {:noreply, state}
  end

  def handle_info({port, :eof}, %{port: port} = state) do
    send(state.owner, :transport_input_closed)
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, port, reason}, %{port: port} = state) do
    send(state.owner, {:transport_disconnected, reason})
    {:stop, {:port_exit, reason}, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    if Port.info(state.port) != nil do
      Port.close(state.port)
    end

    :ok
  end
end
