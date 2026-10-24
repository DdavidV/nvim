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
end
