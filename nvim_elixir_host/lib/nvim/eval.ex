defmodule Nvim.Elixir.Eval do
  require Logger

  def call([{:string, module_name}, {:string, function_name}, args]) do
    module = resolve_module_name(module_name) |> String.to_existing_atom()
    function = String.to_existing_atom(function_name)

    arg_string = Enum.reduce(args, "", fn
      arg, "" -> inspect(arg)
      arg, acc -> ", " <> acc <> inspect(arg)
    end)
    Logger.info("RPC call: #{module}.#{function}(#{arg_string})")

    case Code.ensure_loaded(module) do
      {:module, ^module} ->
        invoke_exported(module, function, args)

      {:error, reason} ->
        Logger.error("Module #{module} not found: #{inspect(reason)}")
        {:error, {:string, "module_not_found"}}
    end
  rescue
    ArgumentError ->
      {:error, {:string, "unknown_module_or_function"}}

    error ->
      Logger.error("Elixir call rescued: #{Exception.format(:error, error, __STACKTRACE__)}")

      {:error, {:string, "error"}}
  catch
    kind, reason ->
      Logger.error("Elixir call caught #{inspect(kind)}: #{inspect(reason)}")
      {:error, {:string, "error"}}
  end

  defp resolve_module_name("Elixir." <> _ = name), do: name
  defp resolve_module_name(name), do: "Elixir." <> name

  defp invoke_exported(module, function, args) do
    if function_exported?(module, function, length(args)) do
      apply(module, function, args)
    else
      {:error, {:string, "function_not_found"}}
    end
  end
end
