local M = {}

local notification = require("ui.notification")
local progress_notifications = {}
local progress_order = {}
local progress_namespace = vim.api.nvim_create_namespace("LspProgressPanels")
local progress_timer
local pulse_frame = 0
local progress_timeout = 30000
local progress_scale = 1
local tick_progress
local attached = false

local message_levels = {
  [1] = vim.log.levels.ERROR,
  [2] = vim.log.levels.WARN,
  [3] = vim.log.levels.INFO,
  [4] = vim.log.levels.DEBUG,
}

local function client_title(client_id)
  local client = vim.lsp.get_client_by_id(client_id)
  return client and ("LSP: " .. client.name) or "LSP"
end

local function show_server_message(_, params, context)
  if type(params) ~= "table" or type(params.message) ~= "string" then
    return
  end

  notification.notify(
    params.message,
    message_levels[params.type] or vim.log.levels.INFO,
    { title = client_title(context.client_id) }
  )
end

local function progress_window()
  local current = vim.api.nvim_get_current_win()
  local function is_editor(winid)
    return vim.api.nvim_win_is_valid(winid)
      and vim.api.nvim_win_get_config(winid).relative == ""
      and vim.bo[vim.api.nvim_win_get_buf(winid)].filetype ~= "native-explorer"
  end

  if is_editor(current) then
    return current
  end
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor(winid) then
      return winid
    end
  end
end

local function progress_lines(entry, width)
  local client = vim.lsp.get_client_by_id(entry.client_id)
  local client_name = client and client.name or "LSP"
  local title = "󰔛 " .. client_name
  if entry.title and entry.title ~= client_name then
    title = title .. " - " .. entry.title
  end

  local message = (entry.message or "Working"):gsub("[\r\n]", " ")
  local percentage = entry.percentage
  local suffix = percentage and (" %3d%%"):format(percentage) or "  ..."
  local bar_width = math.max(3, width - vim.fn.strdisplaywidth(suffix))
  local filled
  if percentage then
    filled = math.floor(bar_width * percentage / 100)
  else
    filled = pulse_frame % bar_width
  end
  local filled_bar = string.rep("█", filled)
  if not percentage then
    filled_bar = filled_bar .. "█"
  end
  local track_count = math.max(0, bar_width - vim.fn.strdisplaywidth(filled_bar))
  local bar = filled_bar .. string.rep("░", track_count)

  return { title, message, bar .. suffix }, #filled_bar, #bar
end

local function render_progress()
  local winid = progress_window()
  if not winid then
    return
  end

  local window_width = vim.api.nvim_win_get_width(winid)
  local window_height = vim.api.nvim_win_get_height(winid)
  local width = math.max(20, math.min(math.floor(44 * progress_scale), window_width - 4))
  local height = 3

  for index, key in ipairs(progress_order) do
    local entry = progress_notifications[key]
    if entry then
      if not entry.buf or not vim.api.nvim_buf_is_valid(entry.buf) then
        entry.buf = vim.api.nvim_create_buf(false, true)
        vim.bo[entry.buf].buftype = "nofile"
        vim.bo[entry.buf].bufhidden = "wipe"
        vim.bo[entry.buf].swapfile = false
      end

      local lines, filled_end, bar_end = progress_lines(entry, width)
      vim.bo[entry.buf].modifiable = true
      vim.api.nvim_buf_set_lines(entry.buf, 0, -1, false, lines)
      vim.bo[entry.buf].modifiable = false
      vim.api.nvim_buf_clear_namespace(entry.buf, progress_namespace, 0, -1)
      vim.api.nvim_buf_add_highlight(entry.buf, progress_namespace, "LspProgressTitle", 0, 0, -1)
      vim.api.nvim_buf_add_highlight(entry.buf, progress_namespace, "LspProgressMessage", 1, 0, -1)
      vim.api.nvim_buf_add_highlight(entry.buf, progress_namespace, "LspProgressBar", 2, 0, filled_end)
      vim.api.nvim_buf_add_highlight(entry.buf, progress_namespace, "LspProgressTrack", 2, filled_end, bar_end)
      vim.api.nvim_buf_add_highlight(entry.buf, progress_namespace, "LspProgressPercent", 2, bar_end, -1)

      local stack_position = #progress_order - index + 1
      local panel_height = height + 2
      local win_config = {
        relative = "win",
        win = winid,
        row = math.max(0, window_height - panel_height * stack_position),
        col = math.max(0, window_width - width - 3),
        width = width,
        height = height,
        style = "minimal",
        focusable = false,
        border = "rounded",
        zindex = 240 + index,
      }

      if not entry.win or not vim.api.nvim_win_is_valid(entry.win) then
        entry.win = vim.api.nvim_open_win(entry.buf, false, win_config)
      else
        vim.api.nvim_win_set_config(entry.win, win_config)
      end
      vim.wo[entry.win].wrap = false
      vim.wo[entry.win].winhighlight = "Normal:ThemeNotifyFloat,FloatBorder:LspProgressBorder"
    end
  end
end

local function close_progress(key)
  local entry = progress_notifications[key]
  if not entry then
    return
  end

  if entry.win and vim.api.nvim_win_is_valid(entry.win) then
    vim.api.nvim_win_close(entry.win, true)
  end
  if entry.buf and vim.api.nvim_buf_is_valid(entry.buf) then
    vim.api.nvim_buf_delete(entry.buf, { force = true })
  end
  progress_notifications[key] = nil
  for index, candidate in ipairs(progress_order) do
    if candidate == key then
      table.remove(progress_order, index)
      break
    end
  end

  if #progress_order == 0 and progress_timer then
    progress_timer:stop()
    progress_timer:close()
    progress_timer = nil
  end
  render_progress()
end

local function handle_progress(_, params, context)
  if type(params) ~= "table" or params.token == nil or type(params.value) ~= "table" then
    return
  end

  local value = params.value
  local key = tostring(context.client_id) .. ":" .. tostring(params.token)
  vim.schedule(function()
    if value.kind == "end" then
      close_progress(key)
      return
    end

    local entry = progress_notifications[key]
    if not entry then
      entry = { client_id = context.client_id }
      progress_notifications[key] = entry
      progress_order[#progress_order + 1] = key
    end
    entry.title = value.title or entry.title
    entry.message = value.message or entry.message or "Working"
    entry.last_update = vim.uv.now()
    if type(value.percentage) == "number" then
      entry.percentage = math.max(0, math.min(100, math.floor(value.percentage)))
    end

    if not progress_timer then
      progress_timer = vim.uv.new_timer()
      local interval = math.min(160, progress_timeout)
      progress_timer:start(interval, interval, vim.schedule_wrap(tick_progress))
    end
    render_progress()
  end)
end

local function clear_client_progress(client_id)
  local keys = {}
  for key, entry in pairs(progress_notifications) do
    if entry.client_id == client_id then
      keys[#keys + 1] = key
    end
  end
  for _, key in ipairs(keys) do
    close_progress(key)
  end
end

tick_progress = function()
  local now = vim.uv.now()
  local stale = {}
  for key, entry in pairs(progress_notifications) do
    if now - entry.last_update >= progress_timeout then
      stale[#stale + 1] = key
    end
  end
  for _, key in ipairs(stale) do
    close_progress(key)
  end

  if #progress_order > 0 then
    pulse_frame = pulse_frame + 1
    render_progress()
  end
end

function M.setup(options)
  options = options or {}
  if options.statusbar_scale ~= nil then
    assert(
      type(options.statusbar_scale) == "number"
        and options.statusbar_scale > 0
        and options.statusbar_scale <= 1,
      "LSP statusbar scale must be greater than 0 and at most 1"
    )
    progress_scale = options.statusbar_scale
  end
  if options.progress_timeout ~= nil then
    assert(
      type(options.progress_timeout) == "number"
        and options.progress_timeout >= 1
        and options.progress_timeout % 1 == 0,
      "LSP progress timeout must be a positive integer"
    )
    progress_timeout = options.progress_timeout
  end

  vim.lsp.handlers["window/showMessage"] = show_server_message
  vim.lsp.handlers["$/progress"] = handle_progress

  if attached then
    return
  end

  local group = vim.api.nvim_create_augroup("NativeLspNotifications", { clear = true })
  vim.api.nvim_create_autocmd("LspDetach", {
    group = group,
    callback = function(event)
      local client_id = event.data and event.data.client_id
      if client_id then
        clear_client_progress(client_id)
      end
    end,
  })
  attached = true
end

return M