local event_handler = require("event.handler")
local notification = require("ui.notification")
local M = {}

local namespace = vim.api.nvim_create_namespace("NativeNotificationEvents")
local attached = false

M.kinds = {
  -- Echo output
  empty = "", -- Empty or unknown message
  echo = "echo", -- :echo
  echomsg = "echomsg", -- :echomsg

  -- Prompts and command output
  confirm = "confirm",
  confirm_sub = "confirm_sub",
  number_prompt = "number_prompt",
  return_prompt = "return_prompt",

  -- Errors and warnings
  emsg = "emsg", -- Neovim error or thrown exception
  echoerr = "echoerr", -- :echoerr
  lua_error = "lua_error", -- Lua execution error
  rpc_error = "rpc_error", -- RPC request error
  wmsg = "wmsg", -- Neovim warning

  -- Informational output
  list_cmd = "list_cmd", -- Output from list-style commands
  quickfix = "quickfix", -- Quickfix navigation message
  search_count = "search_count", -- Search match count
  shell_err = "shell_err", -- Shell command stderr
}

local message_levels = {
  [M.kinds.emsg] = vim.log.levels.ERROR,
  [M.kinds.echoerr] = vim.log.levels.ERROR,
  [M.kinds.lua_error] = vim.log.levels.ERROR,
  [M.kinds.rpc_error] = vim.log.levels.ERROR,
  [M.kinds.shell_err] = vim.log.levels.ERROR,
  [M.kinds.wmsg] = vim.log.levels.WARN,
}

-- Disable blocking hit-enter prompts so queued notification UI can render.
local function disable_hit_enter_prompt()
  local options = vim.split(vim.o.messagesopt, ",", { plain = true, trimempty = true })
  local filtered = {}
  for _, option in ipairs(options) do
    if option ~= "hit-enter" and not option:match("^wait:") then
      filtered[#filtered + 1] = option
    end
  end
  filtered[#filtered + 1] = "wait:0"
  vim.o.messagesopt = table.concat(filtered, ",")
end

-- Convert Neovim error and warning messages into notification UI calls.
local function show_message(kind, content)
  if kind == M.kinds.return_prompt then
    vim.api.nvim_input("<CR>")
    return true
  end

  local level = message_levels[kind]
  if not level then
    return
  end

  local chunks = {}
  for _, chunk in ipairs(content) do
    chunks[#chunks + 1] = chunk[2]
  end
  local message = table.concat(chunks)
  if message == "" then
    return true
  end

  -- The UI module defers rendering when this callback runs in api-fast context.
  notification.notify(message, level, { title = "Neovim" })
  return true
end

-- Install vim.notify and attach to Neovim's external message events.
function M.setup()
  disable_hit_enter_prompt()
  vim.notify = notification.notify
  if attached then
    return
  end

  event_handler.attach(namespace, { ext_messages = true }, {
    msg_show = show_message,
  })
  attached = true
end

return M
