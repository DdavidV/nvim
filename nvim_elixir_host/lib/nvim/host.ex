defmodule Nvim.Host do
  use GenServer
  require Logger
  alias Nvim.Host.State

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  @impl true
  def init(_args) do
    case Nvim.Transport.start_link(self()) do
      {:ok, pid} ->
        spawn(&notify_started/0)
        {:ok, %State{transport: pid, handlers: %{"elixir.call" => &Nvim.Elixir.Eval.call/1}}}

      {:error, reason} ->
        {:error, {:transport_start, reason}}
    end
  end

  defp notify_started() do
    options = %{"title" => "Elixir Host"}

    case Nvim.api(:nvim_notify, ["Started Neovim Beam host", 2, options]) do
      {:ok, _notification_id} ->
        :ok

      {:error, reason} ->
        Logger.error("Could not notify Neovim host-started: #{inspect(reason)}")
    end
  end

  @impl true
  def handle_call({:call, method, params, timeout}, from, state) do
    request_id = state.next_request_id
    message = {:request, request_id, method, params}

    case encode_and_send(message, state.transport) do
      :ok ->
        schedule_timeout(request_id, timeout, from, state)

      {:error, reason} ->
        {:reply, {:error, reason}, advance_request_id(state)}
    end
  end

  def handle_call({:api_call, function, params, timeout}, from, state) do
    request_id = state.next_request_id

    with {:ok, packet} <- apply(:nvim_api, function, [request_id | params]),
         :ok <- Nvim.Transport.send_data(state.transport, packet) do
      schedule_timeout(request_id, timeout, from, state)
    else
      {:error, reason} ->
        {:reply, {:error, reason}, advance_request_id(state)}
    end
  end

  def handle_call({:register_handler, method, handler}, _from, state) do
    with {:ok, method} <- normalize_method(method),
         :ok <- validate_handler(handler) do
      {:reply, :ok, %{state | handlers: Map.put(state.handlers, method, handler)}}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:unregister_handler, method}, _from, state) do
    case normalize_method(method) do
      {:ok, method} ->
        {:reply, :ok, %{state | handlers: Map.delete(state.handlers, method)}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(_request, _from, state) do
    {:reply, {:error, :unsupported_request}, state}
  end

  defp normalize_method(method) when is_atom(method), do: {:ok, Atom.to_string(method)}
  defp normalize_method(method) when is_binary(method), do: {:ok, method}
  defp normalize_method(_), do: {:error, :invalid_method_type}

  defp validate_handler(handler) do
    if is_function(handler, 1) do
      :ok
    else
      {:error, :invalid_handler}
    end
  end

  defp schedule_timeout(request_id, timeout, from, state) do
    timer = Process.send_after(self(), {:request_timeout, request_id}, timeout)

    {:noreply,
     %{state | pending_requests: Map.put(state.pending_requests, request_id, {from, timer})}
     |> advance_request_id()}
  end

  defp advance_request_id(state) do
    %{state | next_request_id: state.next_request_id + 1}
  end

  @impl true
  def handle_cast({method, params}, state), do: send_notification(method, params, state)
  def handle_cast(_request, state), do: {:noreply, state}

  @impl true
  def handle_info({:transport_data, data}, state) do
    decode_messages(state.buffer <> data, %{state | buffer: ""})
  end

  def handle_info(:transport_input_closed, state) do
    # Fail every pending request with :disconnected reason
    Enum.each(state.pending_requests, fn {request_id, {_from, _timer}} ->
      reply_back(request_id, :disconnected, nil, state)
    end)

    spawn(fn -> Application.stop(:nvim_elixir_host) end)
    {:stop, :normal, state}
  end

  def handle_info({:request_timeout, request_id}, state) do
    {:noreply, reply_back(request_id, :timeout, nil, state)}
  end

  def handle_info({:handler_result, pid, result}, state) do
    case Map.pop(state.workers, pid) do
      {%{kind: :notification} = incoming, workers} ->
        Process.demonitor(incoming.monitor)
        {:noreply, %{state | workers: workers}}

      {%{kind: :request} = incoming, workers} ->
        Process.demonitor(incoming.monitor)
        state = %{state | workers: workers}
        send_handler_result(incoming.request_id, result, state)
        {:noreply, state}

      {_, workers} ->
        {:noreply, %{state | workers: workers}}
    end
  end

  def handle_info({:DOWN, _monitor_ref, :process, pid, reason}, state) do
    case Map.pop(state.workers, pid) do
      {%{kind: :notification} = incoming, workers} ->
        Process.demonitor(incoming.monitor)
        {:noreply, %{state | workers: workers}}

      {%{kind: :request} = incoming, workers} ->
        Process.demonitor(incoming.monitor)
        error_result = {:error, {:exit, reason}}
        state = %{state | workers: workers}
        send_handler_result(incoming.request_id, error_result, state)
        {:noreply, state}

      {_, workers} ->
        {:noreply, %{state | workers: workers}}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp decode_messages("", state), do: {:noreply, state}

  defp decode_messages(data, state) do
    case :nvim_rpc.decode_rpc(data) do
      {:ok, msg, rest} ->
        state = handle_rpc_message(msg, state)
        decode_messages(rest, state)

      {:error, :incomplete} ->
        {:noreply, %{state | buffer: data}}

      {:error, _reason} ->
        Logger.error("Failed to decode RPC message: #{inspect(data)}")
        {:noreply, state}
    end
  end

  defp handle_rpc_message({:response, request_id, error, result}, state) do
    reply_back(request_id, error, result, state)
  end

  defp handle_rpc_message({kind, method, params}, state) do
    # Incoming notification without request_id
    handle_rpc_message({kind, nil, method, params}, state)
  end

  defp handle_rpc_message({kind, request_id, method, params}, state) do
    case Map.get(state.handlers, method) do
      nil ->
        # Handler not found responde only when request_id is available
        if request_id do
          error = :nvim_rpc.term_to_rpc("method_not_found")
          send_response(request_id, error, nil, state)
        end

        # Continue with the previous state
        Logger.error("No handler found for method: #{inspect(method)}")
        state

      handler ->
        # Handler is found spawn the request
        parent = self()

        {pid, monitor} =
          spawn_monitor(fn ->
            result = invoke_handler(handler, params)
            # Send the result to the host process
            send(parent, {:handler_result, self(), result})
          end)

        incoming = %{
          kind: kind,
          request_id: request_id,
          method: method,
          params: params,
          monitor: monitor
        }

        %{state | workers: Map.put(state.workers, pid, incoming)}
    end
  end

  def invoke_handler(handler, params) do
    handler.(params)
  rescue
    error ->
      {:error, {:exception, error, __STACKTRACE__}}
  catch
    kind, reason ->
      {:error, {kind, reason, __STACKTRACE__}}
  end

  defp send_handler_result(request_id, result, state) do
    case result do
      {:ok, result} ->
        send_response(request_id, nil, result, state)

      {:error, reason} ->
        send_response(request_id, reason, nil, state)

      result ->
        send_response(request_id, nil, result, state)
    end
  end

  defp send_response(request_id, error, result, state) do
    message = {:response, request_id, error, result}
    encode_and_send(message, state.transport)
  end

  defp send_notification(method, params, state) do
    message = {:notification, method, params}
    encode_and_send(message, state.transport)
  end

  defp encode_and_send(message, transport) do
    case :nvim_rpc.encode_rpc(message) do
      {:ok, encoded} ->
        Nvim.Transport.send_data(transport, encoded)

      {:error, reason} ->
        Logger.error("Message cannot be encoded: #{inspect(message)}")
        {:error, reason}
    end
  end

  defp reply_back(request_id, error, result, state) do
    case Map.get(state.pending_requests, request_id) do
      {from, timer} ->
        Process.cancel_timer(timer)

        reply =
          case error do
            nil ->
              {:ok, result}

            _ ->
              {:error, error}
          end

        GenServer.reply(from, reply)
        %{state | pending_requests: Map.delete(state.pending_requests, request_id)}

      nil ->
        # No pending request found
        Logger.error("No pending request found for request_id: #{inspect(request_id)}")
        state
    end
  end
end
