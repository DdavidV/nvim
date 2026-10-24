local M = {}

local function notify_error(message)
  vim.notify(message, vim.log.levels.ERROR, { title = "BEAM host" })
end

local function notify_log(data)
  local message = table.concat(vim.tbl_filter(function(line)
    return line ~= ""
  end, data), "\n")
  if message == "" then
    return
  end

  local level = vim.log.levels.ERROR
  if message:find("=NOTICE REPORT", 1, true) or message:find("=INFO REPORT", 1, true) then
    level = vim.log.levels.INFO
  elseif message:find("=WARNING REPORT", 1, true) then
    level = vim.log.levels.WARN
  end

  vim.schedule(function()
    vim.notify(message, level, { title = "BEAM host" })
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

local function compile_scripts(scripts_dir, ebin_dir, host_beam_dir)
  local sources = vim.fn.globpath(scripts_dir, "**/*.erl", false, true)
  vim.fn.mkdir(ebin_dir, "p")

  for _, beam in ipairs(vim.fn.globpath(ebin_dir, "*.beam", false, true)) do
    if vim.fn.delete(beam) ~= 0 then
      return false, "Could not remove stale BEAM module: " .. beam
    end
  end

  if #sources == 0 then
    return true
  end

  if vim.fn.executable("erlc") ~= 1 then
    return false, "Cannot compile BEAM scripts: erlc was not found in PATH."
  end

  local command = {
    "erlc",
    "-o",
    ebin_dir,
    "-pa",
    host_beam_dir .. "/nvim_erlang_host/ebin",
    "-pa",
    host_beam_dir .. "/nvim_rpc/ebin",
  }
  vim.list_extend(command, sources)
  return run_checked(command, scripts_dir, "BEAM script compilation")
end

local function erlang_string(value)
  local escaped = value
    :gsub("\\", "\\\\")
    :gsub('"', '\\"')
    :gsub("\n", "\\n")
    :gsub("\r", "\\r")
    :gsub("\t", "\\t")
  return '"' .. escaped .. '"'
end

local function start_host(host_dir, beam_dir, scripts_dir, scripts_ebin)
  local configured_scripts_dir = erlang_string(scripts_dir)

  -- Set the scripts_dir before starting the host
  local eval = string.format([[
    ok = application:set_env([
          {nvim_erlang_host, [{scripts_dir, %s}]}
      ]),
    case application:ensure_all_started(nvim_erlang_host) of
        {ok, _StartedApplications} ->
            ok;
        {error, StartError} ->
            io:format(standard_error, "Could not start nvim_erlang_host: ~p~n", [StartError]),
            halt(1)
    end,
    receive after infinity -> ok end.
  ]], configured_scripts_dir)

  local command = {
    "erl",
    "-noshell",
    "-noinput",
    "-pa",
    beam_dir .. "/nvim_erlang_host/ebin",
    "-pa",
    beam_dir .. "/nvim_rpc/ebin",
    "-pa",
    scripts_ebin,
    "-eval",
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
    return nil, "Neovim could not start the BEAM host process (job id " .. job_id .. ")."
  end
  return job_id
end

local function build_host(host_dir, force)
  local beam_dir = host_dir .. "/_build/default/lib"
  local host_beam = beam_dir .. "/nvim_erlang_host/ebin/nvim_erlang_host.beam"
  local rpc_beam = beam_dir .. "/nvim_rpc/ebin/nvim_rpc.beam"

  if force or vim.fn.filereadable(host_beam) ~= 1 or vim.fn.filereadable(rpc_beam) ~= 1 then
    local ok, err = run_checked({ "rebar3", "compile" }, host_dir, "BEAM host build")
    if not ok then
      return false, err
    end
  end
  return true, beam_dir
end

-- Register all user commands for the BEAM extension host.
local function register_commands()
  if not M.reload_command_created then
    vim.api.nvim_create_user_command("ErlangReload", M.reload, {
      desc = "Recompile and restart the BEAM extension host",
    })
    M.reload_command_created = true
  end

end

function M.setup(options)
  options = options or {}
  assert(type(options) == "table", "beam options must be a table")
  assert(type(options.scripts_dir) == "string", "beam.scripts_dir must be a string")

  M.options = options
  register_commands()

  if M.job_id and vim.fn.jobwait({ M.job_id }, 0)[1] == -1 then
    return M.job_id
  end

  if vim.fn.executable("rebar3") ~= 1 or vim.fn.executable("erl") ~= 1 then
    notify_error("The BEAM host requires both erl and rebar3 in PATH.")
    return
  end

  local config_dir = vim.fn.stdpath("config")
  -- Later this can be changed if the host code is ever moved to a different git repository
  local host_dir = config_dir .. "/nvim_erlang_host"
  local scripts_dir = vim.fn.fnamemodify(options.scripts_dir, ":p")
  local scripts_ebin = scripts_dir .. "/ebin"

  local ok, result = build_host(host_dir, M.force_build)
  M.force_build = nil
  if not ok then
    notify_error(result)
    return
  end

  local beam_dir = result
  ok, result = compile_scripts(scripts_dir, scripts_ebin, beam_dir)
  if not ok then
    notify_error(result)
    return
  end

  local job_id, err = start_host(host_dir, beam_dir, scripts_dir, scripts_ebin)
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
    error("BEAM host is not running", 2)
  end

  local ok, result = pcall(
    vim.fn.rpcrequest,
    M.job_id,
    "erlang.call",
    module,
    function_name,
    args or {}
  )

  if not ok then
    error("Erlang RPC call failed: " .. tostring(result), 2)
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
