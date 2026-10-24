
defmodule Nvim.Elixir.Extensions do
  @moduledoc false

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    scripts_dir =
      Application.get_env(:nvim_elixir_host, :scripts_dir, "")
      |> Path.expand()

    children = start_extensions(scripts_dir)

    Supervisor.init(children,
      strategy: :one_for_one,
      max_restarts: 5,
      max_seconds: 10
    )
  end

  defp start_extensions(scripts_dir) do
    ebin_dir = Path.join(scripts_dir, "ebin")
    beam_files = Path.wildcard(Path.join(ebin_dir, "*.beam"))

    if File.dir?(ebin_dir) do
      case :code.add_patha(String.to_charlist(ebin_dir)) do
        true ->
          beam_files
          |> load_all(ebin_dir, [])
          |> Enum.flat_map(&retrieve_child_specs/1)

        {:error, reason} ->
          Logger.error("Cannot add #{ebin_dir} to code path: #{inspect(reason)}")
          []
      end
    else
      Logger.warning("Extension ebin directory does not exist: #{ebin_dir}")
      []
    end
  end

  defp load_all([], _ebin_dir, modules), do: Enum.reverse(modules)

  defp load_all([beam_file | rest], ebin_dir, modules) do
    beam_path = Path.rootname(beam_file)

    case :code.load_abs(String.to_charlist(beam_path)) do
      {:module, module} ->
        run_script_part(module)
        load_all(rest, ebin_dir, [module | modules])

      {:error, reason} ->
        Logger.error("Cannot load BEAM file #{beam_file}: #{inspect(reason)}")
        load_all(rest, ebin_dir, modules)
    end
  end

  defp run_script_part(module) do
    if function_exported?(module, :run, 0) do
      try do
        case apply(module, :run, []) do
          :ok ->
            :ok

          {:ok, _value} ->
            :ok

          {:error, reason} ->
            Logger.error(
              "Elixir extension #{inspect(module)}:run/0 returned an error: #{inspect(reason)}"
            )

          other ->
            Logger.warning(
              "Elixir extension #{inspect(module)}:run/0 returned: #{inspect(other)}"
            )
        end
      rescue
        error ->
          Logger.error(
            "Elixir extension #{inspect(module)}:run/0 failed: " <>
              Exception.format(:error, error, __STACKTRACE__)
          )
      catch
        kind, reason ->
          Logger.error(
            "Elixir extension #{inspect(module)}:run/0 failed (#{inspect(kind)}): " <>
              "#{inspect(reason)}"
          )
      end
    end

    :ok
  end

  defp retrieve_child_specs(module) do
    cond do
      function_exported?(module, :child_specs, 0) ->
        case apply(module, :child_specs, []) do
          specs when is_list(specs) ->
            specs

          spec ->
            [spec]
        end

      function_exported?(module, :start_link, 0) ->
        [
          %{
            id: module,
            start: {module, :start_link, []},
            restart: :transient,
            shutdown: 5_000,
            type: :worker,
            modules: [module]
          }
        ]

      true ->
        []
    end
  end
end
