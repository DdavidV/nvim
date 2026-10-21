local M = {}

local defaults = {
  timeout = 5000,
  max_width = 60,
  gap = 1,
}

local config = vim.deepcopy(defaults)
local notifications = {}
local next_id = 0
local namespace = vim.api.nvim_create_namespace("NativeNotification")

local levels = {
  [vim.log.levels.ERROR] = { name = "ERROR", highlight = "ThemeNotifyError" },
  [vim.log.levels.WARN] = { name = "WARN", highlight = "ThemeNotifyWarn" },
  [vim.log.levels.INFO] = { name = "INFO", highlight = "ThemeNotifyInfo" },
  [vim.log.levels.DEBUG] = { name = "DEBUG", highlight = "ThemeNotifyDebug" },
  [vim.log.levels.TRACE] = { name = "TRACE", highlight = "ThemeNotifyDebug" },
}

-- Return the display information for a log level, defaulting unknown levels to INFO.
local function get_level(level)
  return levels[level] or levels[vim.log.levels.INFO]
end

-- Build a severity-colored header, divider, and message body.
local function make_lines(entry)
  local title = entry.opts.title or "Neovim"
  local timestamp = os.date("%H:%M")
  local body = vim.split(entry.message, "\n", { plain = true })
  local width = vim.fn.strdisplaywidth("● " .. title) + vim.fn.strdisplaywidth(timestamp) + 1
  for _, line in ipairs(body) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width, config.max_width, math.max(1, vim.o.columns - 4))

  local title_width = math.max(0, width - vim.fn.strdisplaywidth("● ") - vim.fn.strdisplaywidth(timestamp) - 1)
  local visible_title = ""
  for index = 1, vim.fn.strchars(title) do
    local candidate = visible_title .. vim.fn.strcharpart(title, index - 1, 1)
    if vim.fn.strdisplaywidth(candidate) > title_width then
      break
    end
    visible_title = candidate
  end
  if visible_title ~= title and title_width > 1 then
    while vim.fn.strdisplaywidth(visible_title .. "…") > title_width do
      visible_title = vim.fn.strcharpart(visible_title, 0, vim.fn.strchars(visible_title) - 1)
    end
    visible_title = visible_title .. "…"
  end

  local header_left = "● " .. visible_title
  local padding = math.max(1, width - vim.fn.strdisplaywidth(header_left) - vim.fn.strdisplaywidth(timestamp))
  local header = header_left .. string.rep(" ", padding) .. timestamp
  local lines = { header, string.rep("─", width) }
  vim.list_extend(lines, body)

  local height = 0
  for _, line in ipairs(lines) do
    height = height + math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / width))
  end
  height = math.min(height, math.max(1, vim.o.lines - 4))
  return lines, width, height
end

-- Open or reposition all notification windows in a top-right stack.
local function render()
  local row = 1
  for _, entry in ipairs(notifications) do
    local lines, width, height = make_lines(entry)
    local col = math.max(0, vim.o.columns - width - 2)

    if not entry.buf or not vim.api.nvim_buf_is_valid(entry.buf) then
      entry.buf = vim.api.nvim_create_buf(false, true)
      vim.bo[entry.buf].bufhidden = "wipe"
      vim.bo[entry.buf].buftype = "nofile"
      vim.bo[entry.buf].modifiable = false
    end

    vim.bo[entry.buf].modifiable = true
    vim.api.nvim_buf_set_lines(entry.buf, 0, -1, false, lines)
    vim.bo[entry.buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(entry.buf, namespace, 0, -1)
    vim.api.nvim_buf_add_highlight(entry.buf, namespace, entry.level.highlight, 0, 0, -1)
    vim.api.nvim_buf_add_highlight(entry.buf, namespace, entry.level.highlight, 1, 0, -1)

    local win_config = {
      relative = "editor",
      row = row,
      col = col,
      width = width,
      height = height,
      style = "minimal",
      focusable = false,
      border = "rounded",
      zindex = 250,
    }

    if not entry.win or not vim.api.nvim_win_is_valid(entry.win) then
      entry.win = vim.api.nvim_open_win(entry.buf, false, win_config)
    else
      vim.api.nvim_win_set_config(entry.win, win_config)
    end

    vim.wo[entry.win].wrap = true
    vim.wo[entry.win].linebreak = true
    vim.wo[entry.win].winhighlight =
      "Normal:ThemeNotifyFloat,FloatBorder:" .. entry.level.highlight
    row = row + height + config.gap
  end
  vim.cmd.redraw()
end

-- Remove a notification and close its timer, buffer, and window.
function M.dismiss(id)
  for index, entry in ipairs(notifications) do
    if entry.id == id then
      table.remove(notifications, index)
      if entry.timer then
        entry.timer:stop()
        entry.timer:close()
      end
      if entry.win and vim.api.nvim_win_is_valid(entry.win) then
        vim.api.nvim_win_close(entry.win, true)
      end
      if entry.buf and vim.api.nvim_buf_is_valid(entry.buf) then
        vim.api.nvim_buf_delete(entry.buf, { force = true })
      end
      vim.schedule(render)
      return true
    end
  end
  return false
end

-- Add an entry once called from a context where window APIs are allowed.
local function show_notification(message, level, opts)
  opts = opts or {}
  if opts.replace then
    M.dismiss(opts.replace)
  end

  next_id = next_id + 1
  local entry = {
    id = next_id,
    message = tostring(message),
    level = get_level(level),
    opts = opts,
  }
  table.insert(notifications, 1, entry)

  local timeout = opts.timeout
  if timeout == nil then
    timeout = config.timeout
  end
  if timeout > 0 then
    entry.timer = vim.uv.new_timer()
    entry.timer:start(timeout, 0, vim.schedule_wrap(function()
      M.dismiss(entry.id)
    end))
  end

  render()
  return entry.id
end

-- Display a notification, deferring UI work when called from an API-fast event.
function M.notify(message, level, opts)
  if vim.in_fast_event() then
    vim.schedule(function()
      show_notification(message, level, opts)
    end)
    return
  end
  return show_notification(message, level, opts)
end

-- Apply notification settings and prepare the UI styling and resize hooks.
function M.setup(options)
  options = options or {}
  config = vim.tbl_deep_extend("force", config, options)
  assert(type(config.timeout) == "number" and config.timeout >= 0, "notification timeout must be a non-negative number")
  assert(type(config.max_width) == "number" and config.max_width >= 1, "notification max_width must be positive")
  assert(type(config.gap) == "number" and config.gap >= 0, "notification gap must be non-negative")

  local group = vim.api.nvim_create_augroup("NativeNotifications", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = render,
  })
end

return M
