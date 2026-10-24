defmodule Nvim do
  def call(method, params \\ [], timeout \\ 5000) do
    GenServer.call(Nvim.Host, {:call, method, params, timeout}, timeout + 100)
  end

  def cast(method, params \\ []) do
    GenServer.cast(Nvim.Host, {:cast, method, params})
  end

  def api(function, params \\ [], timeout \\ 5000) do
    with :ok <- validate_api_request(function, params) do
      GenServer.call(Nvim.Host, {:api_call, function, params, timeout}, timeout + 100)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_api_request(function, params)
       when is_atom(function) and is_list(params) do
    # +1 for request_id
    arity = length(params) + 1

    case Code.ensure_loaded(:nvim_api) do
      {:module, :nvim_api} ->
        if function_exported?(:nvim_api, function, arity) do
          :ok
        else
          {:error, {:invalid_api_function, function, arity}}
        end

      {:error, reason} ->
        {:error, {:api_bindings_unavailable, reason}}
    end
  end

  def create_user_command(name, handler, options)
      when is_binary(name) and is_function(handler, 1) and is_map(options) do
    case api(:nvim_get_api_info, []) do
      {:ok, [channel_id, _metadata]} when is_integer(channel_id) ->
        create_user_command_with_channel(name, handler, options, channel_id)

      {:ok, response} ->
        {:error, {:invalid_api_info_response, response}}

      {:error, reason} ->
        {:error, {:api_info_failed, reason}}
    end
  end

  def create_user_command(_name, _handler, _options) do
    {:error, :invalid_user_command_arguments}
  end

  defp create_user_command_with_channel(name, handler, options, channel_id) do
    method =
      "nvim_elixir_user_command:" <>
        Integer.to_string(System.unique_integer([:positive, :monotonic]))

    wrapped_handler = fn [command_options] ->
      handler.(command_options)
    end

    case register_handler(method, wrapped_handler) do
      :ok ->
        create_remote_user_command(name, method, options, channel_id)

      {:error, reason} ->
        {:error, {:user_command_handler_registration_failed, reason}}
    end
  end

  defp create_remote_user_command(name, method, options, channel_id) do
    code = """
    local name, method, channel, options = ...
    vim.api.nvim_create_user_command(name, function(command_options)
      vim.rpcnotify(channel, method, command_options)
    end, options)
    """

    args = [name, method, channel_id, options]

    case api(:nvim_exec_lua, [code, args]) do
      {:ok, nil} ->
        :ok

      {:error, reason} ->
        _ = unregister_handler(method)
        {:error, {:user_command_creation_failed, reason}}

      unexpected ->
        _ = unregister_handler(method)
        {:error, {:unexpected_user_command_response, unexpected}}
    end
  end

  def register_handler(method, handler) when is_function(handler, 1) do
    GenServer.call(Nvim.Host, {:register_handler, method, handler})
  end

  def register_handler(_method, _handler) do
    {:error, :invalid_handler}
  end

  def unregister_handler(method) when is_binary(method) do
    GenServer.call(Nvim.Host, {:unregister_handler, method})
  end

end
