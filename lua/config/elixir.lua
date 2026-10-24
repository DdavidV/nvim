
local M = {}

local function notify_error(message)
  vim.notify(message, vim.log.levels.ERROR, { title = "Elixir host" })
end

local function notify_log(data)
  local message = table.concat(vim.tbl_filter(function(line)
    return line ~= ""
  end, data), "\n")

  if message == "" then
    return
  end

  vim.schedule(function()
    vim.notify(message, vim.log.levels.ERROR, { title = "Elixir host" })
  end)
end

local function run_checked(command, cwd, description)
  local ok, result = pcall(function()
    return vim.system(command, { cwd = cwd, text = true }):wait()
  end)

  if not ok then
    return false, description .. " failed: " .. tostring(result)
  end

  if result.code ~= 0 then
    local details = result.stderr ~= "" and result.stderr or result.stdout
    return false, description .. " failed:\n" .. details
  end

  return true
end

local function elixir_string(value)
  local escaped = value
    :gsub("\\", "\\\\")
    :gsub('"', '\\"')
    :gsub("\n", "\\n")
    :gsub("\r", "\\r")
    :gsub("\t", "\\t")

  return '"' .. escaped .. '"'
end

local function compile_scripts(scripts_dir, scripts_ebin)
  local sources = vim.fn.globpath(scripts_dir, "**/*.ex", false, true)

  vim.fn.mkdir(scripts_ebin, "p")

  for _, beam in ipairs(vim.fn.globpath(scripts_ebin, "*.beam", false, true)) do
    if vim.fn.delete(beam) ~= 0 then
      return false, "Could not remove stale BEAM module: " .. beam
    end
  end

  if #sources == 0 then
    return true
  end

  if vim.fn.executable("elixirc") ~= 1 then
    return false, "Cannot compile Elixir scripts: elixirc was not found in PATH."
  end

  local command = {
    "elixirc",
    "-o",
    scripts_ebin,
  }

  vim.list_extend(command, sources)

  return run_checked(command, scripts_dir, "Elixir script compilation")
end

local function build_host(host_dir, force)
  local mix_file = host_dir .. "/mix.exs"
  local manifest = host_dir .. "/_build/dev/lib/nvim_elixir_host/ebin/nvim_elixir_host.app"

  if vim.fn.filereadable(mix_file) ~= 1 then
    return false, "Elixir host project not found: " .. mix_file
  end

  if force or vim.fn.filereadable(manifest) ~= 1 then
    local ok, err = run_checked(
      { "mix", "compile" },
      host_dir,
      "Elixir host build"
    )

    if not ok then
      return false, err
    end
  end

  return true
end

local function start_host(host_dir, scripts_dir, scripts_ebin)
  local eval = string.format([[
    Application.put_env(:nvim_elixir_host, :scripts_dir, %s)
    Application.ensure_all_started(:nvim_elixir_host)
    Process.sleep(:infinity)
  ]], elixir_string(scripts_dir))

  local command = {
    "elixir",
    "--erl",
    "-noinput",
    "-pa",
    scripts_ebin,
    "-S",
    "mix",
    "run",
    "--no-start",
    "--no-compile",
    "--no-halt",
    "-e",
    eval,
  }

  local job_id = vim.fn.jobstart(command, {
    rpc = true,
    cwd = host_dir,

    on_stderr = function(id, data)
      if M.stopping_job_id ~= id then
        notify_log(data)
      end
    end,

    on_exit = function(id, exit_code)
      if M.stopping_job_id == id then
        M.stopping_job_id = nil
        return
      end

      if M.job_id == id then
        M.job_id = nil
      end

      if exit_code ~= 0 then
        vim.schedule(function()
          notify_error("Host process exited with status " .. exit_code .. ".")
        end)
      end
    end,
  })

  if job_id <= 0 then
    return nil, "Neovim could not start the Elixir host process (job id " .. job_id .. ")."
  end

  return job_id
end

local function register_commands()
  if not M.reload_command_created then
    vim.api.nvim_create_user_command("ElixirReload", M.reload, {
      desc = "Recompile and restart the Elixir host",
    })

    M.reload_command_created = true
  end
end

function M.setup(options)
  options = options or {}

  assert(type(options) == "table", "elixir options must be a table")
  assert(type(options.scripts_dir) == "string", "elixir.scripts_dir must be a string")

  M.options = options
  register_commands()

  if M.job_id and vim.fn.jobwait({ M.job_id }, 0)[1] == -1 then
    return M.job_id
  end

  for _, executable in ipairs({ "elixir", "elixirc", "mix" }) do
    if vim.fn.executable(executable) ~= 1 then
      notify_error("The Elixir host requires " .. executable .. " in PATH.")
      return
    end
  end

  local config_dir = vim.fn.stdpath("config")
  local host_dir = options.host_dir or (config_dir .. "/nvim_elixir_host")
  local scripts_dir = vim.fn.fnamemodify(options.scripts_dir, ":p")
  local scripts_ebin = scripts_dir .. "/ebin"

  local ok, err = build_host(host_dir, M.force_build)
  M.force_build = nil

  if not ok then
    notify_error(err)
    return
  end

  ok, err = compile_scripts(scripts_dir, scripts_ebin)

  if not ok then
    notify_error(err)
    return
  end

  local job_id
  job_id, err = start_host(host_dir, scripts_dir, scripts_ebin)

  if not job_id then
    notify_error(err)
    return
  end

  M.job_id = job_id
  return job_id
end

function M.reload()
  if M.job_id then
    M.stopping_job_id = M.job_id
    vim.fn.jobstop(M.job_id)
    M.job_id = nil
  end

  vim.defer_fn(function()
    M.force_build = true
    M.setup(M.options)
  end, 100)
end

function M.call(module, function_name, args)
  assert(type(module) == "string", "module must be a string")
  assert(type(function_name) == "string", "function_name must be a string")
  assert(args == nil or type(args) == "table", "args must be a table")

  if not M.job_id or vim.fn.jobwait({ M.job_id }, 0)[1] ~= -1 then
    error("Elixir host is not running", 2)
  end

  local ok, result = pcall(
    vim.fn.rpcrequest,
    M.job_id,
    "elixir.call",
    module,
    function_name,
    args or {}
  )

  if not ok then
    error("Elixir RPC call failed: " .. tostring(result), 2)
  end

  return result
end

function M.module(module_name)
  assert(type(module_name) == "string", "module_name must be a string")

  return setmetatable({}, {
    __index = function(_, function_name)
      return function(...)
        return M.call(module_name, function_name, { ... })
      end
    end,
  })
end

return M
