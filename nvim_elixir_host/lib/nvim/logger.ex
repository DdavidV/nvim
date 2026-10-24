defmodule Nvim.Logger do
  require Logger

  @max_bytes 10 * 1024 * 1024
  @max_files 5

  def configure! do
    # Never let the default handler write protocol-breaking output to stdout.
    :ok = :logger.remove_handler(:default)
    log_dir = :filename.basedir(:user_log, "nvim-beam")
    log_file = Path.join(log_dir, "server.log")

    File.mkdir_p!(log_dir)

    Logger.configure(level: :info)

    :ok =
      :logger.add_handler(:nvim_file, :logger_std_h, %{
        level: :info,
        config: %{
          file: String.to_charlist(log_file),
          max_no_bytes: @max_bytes,
          max_no_files: @max_files
        },
        formatter: {:logger_formatter, %{single_line: true}}
      })

    Logger.info("Logging initialized", log_file: log_file)

    :ok
  end
end
