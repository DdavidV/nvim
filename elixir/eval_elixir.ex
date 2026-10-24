defmodule EvalElixir do
  @moduledoc false

  @info 2
  @error 4

  def run do
    options = %{
      "desc" => "Evaluate an Elixir expression",
      "nargs" => "+"
    }

    Nvim.create_user_command("Elixir", &command/1, options)
  end

  def command(command_options) do
    options = :nvim_rpc.rpc_to_term(command_options)

    case Map.get(options, "args") do
      nil ->
        notify("Could not read Elixir command arguments", @error)

      args ->
        case eval(args) do
          {:ok, value} ->
            notify(format_value(value), @info)

          {:error, reason} ->
            notify(format_error(reason), @error)
        end
    end
  end

  def eval(expression) when is_binary(expression) do
    try do
      Code.eval_string(expression)
      |> then(fn {value, _binding} -> {:ok, value} end)
    rescue
      error ->
        {:error, {:eval, :error, error, __STACKTRACE__}}
    catch
      kind, reason ->
        {:error, {:eval, kind, reason, __STACKTRACE__}}
    end
  end

  def eval(expression) when is_list(expression) do
    eval(List.to_string(expression))
  end

  def eval(expression) do
    {:error, {:invalid_expression, expression}}
  end

  defp format_value(value) do
    inspect(value, pretty: true, limit: :infinity)
  end

  defp format_error({:eval, kind, reason, _stacktrace}) do
    "#{kind}: #{Exception.format_banner(kind, reason)}"
  end

  defp format_error({:invalid_expression, expression}) do
    "Invalid expression: #{inspect(expression)}"
  end

  defp format_error(reason) do
    "Evaluation error: #{inspect(reason)}"
  end

  defp notify(message, level) do
    options = %{
      "title" => "Elixir",
      "timeout" => 5000
    }

    Nvim.API.nvim_notify(message, level, options)
    :ok
  end
end
