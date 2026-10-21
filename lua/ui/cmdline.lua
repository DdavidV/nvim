local event_handler = require("event.handler")
local M = {}

-- UI-attach namespace identifies this client; the others isolate our highlights.
local ns = vim.api.nvim_create_namespace("NativeCmdline")
local cursor_ns = vim.api.nvim_create_namespace("NativeCmdlineCursor")
local menu_ns = vim.api.nvim_create_namespace("NativeCmdlineCompletion")

-- Command-line state is indexed by nesting level so nested prompts can be restored.
local lines = {}
local active
local buf
local win

-- Completion-menu state is separate from the command-line float.
local menu_buf
local menu_win
local menu_items
local menu_selected = -1
local attached

-- Build the bottom-centered float configuration used by the command-line UI.
local function float_config(width, config)
  local max_width = math.max(1, vim.o.columns - 4)
  width = math.min(max_width, math.max(1, width))

  return vim.tbl_extend("force", {
    relative = "editor",
    row = math.max(0, vim.o.lines - math.max(1, vim.o.cmdheight) - 3),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    width = width,
    height = 1,
    style = "minimal",
    focusable = false,
    border = "rounded",
    zindex = 60,
  }, config or {})
end

-- Open a non-focused float with the command-line UI's shared styling.
local function open_float(buffer, width, config)
  local window = vim.api.nvim_open_win(buffer, false, float_config(width, config))
  vim.wo[window].winhighlight = "Normal:ThemeCmdlineFloat,FloatBorder:ThemeCmdlineBorder"
  return window
end

-- Close a float only if its window is still valid.
local function close_float(window)
  if window and vim.api.nvim_win_is_valid(window) then
    vim.api.nvim_win_close(window, true)
  end
end

-- Close the completion window and reset its cached state.
local function close_menu()
  close_float(menu_win)
  menu_win = nil
  menu_buf = nil
  menu_items = nil
  menu_selected = -1
end

-- Close both floats when there is no active command line to display.
local function close()
  close_menu()
  close_float(win)
  win = nil
  buf = nil
end

-- Render completion items in a float positioned above the command line.
local function update_menu()
  if not menu_items or #menu_items == 0 or not active then
    close_menu()
    return
  end

  local display = {}
  local max_width = 1
  for _, item in ipairs(menu_items) do
    -- Each item contains a word, kind, and optional menu description.
    local word = tostring(item[1] or "")
    local kind = tostring(item[2] or "")
    local menu = tostring(item[3] or "")
    local text = word
    if kind ~= "" then
      text = text .. "  " .. kind
    end
    if menu ~= "" then
      text = text .. "  " .. menu
    end
    text = text:gsub("[\r\n]+", " ")
    display[#display + 1] = text
    max_width = math.max(max_width, vim.fn.strdisplaywidth(text))
  end

  local command = lines[active]
  local cmdline_text = command.firstc .. command.prompt .. string.rep(" ", command.indent) .. command.text
  local cmdline_width = math.max(44, vim.fn.strdisplaywidth(cmdline_text) + 2)
  local cmdline_config = float_config(cmdline_width)
  local max_height = math.min(#display, 10, math.max(1, cmdline_config.row - 2))
  local height = max_height

  -- Keep the selected completion visible when the list exceeds the window.
  local start = 1
  if menu_selected >= max_height then
    start = menu_selected - max_height + 2
  end
  start = math.min(start, math.max(1, #display - max_height + 1))

  local visible = {}
  for index = start, math.min(#display, start + max_height - 1) do
    visible[#visible + 1] = display[index]
  end

  local width = math.max(1, math.min(vim.o.columns - 4, math.max(cmdline_config.width, max_width + 2)))
  local col = math.max(0, cmdline_config.col)
  local row = math.max(0, cmdline_config.row - height - 2)

  if not menu_buf or not vim.api.nvim_buf_is_valid(menu_buf) then
    -- Recreate the scratch buffer if it was wiped after the float closed.
    menu_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[menu_buf].bufhidden = "wipe"
    vim.bo[menu_buf].modifiable = false
  end
  if not menu_win or not vim.api.nvim_win_is_valid(menu_win) then
    menu_win = open_float(menu_buf, width, { row = row, col = col, height = height, zindex = 201 })
    vim.wo[menu_win].wrap = false
    vim.wo[menu_win].cursorline = false
    vim.wo[menu_win].winhighlight =
      "Normal:ThemeCmdlineFloat,FloatBorder:ThemeCmdlineBorder,CursorLine:ThemeCompletionSelected"
  else
    vim.api.nvim_win_set_config(menu_win, float_config(width, {
      row = row,
      col = col,
      height = height,
      zindex = 201,
    }))
  end

  vim.bo[menu_buf].modifiable = true
  vim.api.nvim_buf_set_lines(menu_buf, 0, -1, false, visible)
  vim.bo[menu_buf].modifiable = false
  -- Clear only this module's previous selection highlight.
  vim.api.nvim_buf_clear_namespace(menu_buf, menu_ns, 0, -1)

  -- Neovim selection indices are zero-based; buffer rows are one-based.
  local selected_row = menu_selected - start + 2
  if selected_row >= 1 and selected_row <= #visible then
    vim.api.nvim_buf_set_extmark(menu_buf, menu_ns, selected_row - 1, 0, {
      end_row = selected_row,
      end_col = 0,
      hl_group = "ThemeCompletionSelected",
      priority = 100,
    })
  end
end

-- Render the active command line and place a highlight over its cursor.
local function update()
  local state = active and lines[active]
  if not state then
    close()
    return
  end

  local line = state.firstc .. state.prompt .. string.rep(" ", state.indent) .. state.text
  local cursor = #state.firstc + #state.prompt + state.indent + state.pos
  if cursor >= #line then
    -- Keep the cursor highlight within the rendered line at the end position.
    line = line .. " "
  end

  local width = math.max(1, math.min(vim.o.columns - 4, math.max(44, vim.fn.strdisplaywidth(line) + 2)))
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    -- Use a scratch buffer because the command line is drawn outside the editor grid.
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].modifiable = false
  end

  if not win or not vim.api.nvim_win_is_valid(win) then
    win = open_float(buf, width)
    vim.wo[win].wrap = false
  else
    vim.api.nvim_win_set_config(win, float_config(width))
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
  vim.bo[buf].modifiable = false
  -- Replace the cursor extmark without touching marks from other features.
  vim.api.nvim_buf_clear_namespace(buf, cursor_ns, 0, -1)

  cursor = math.min(#line - 1, cursor)
  vim.api.nvim_win_set_cursor(win, { 1, cursor })
  vim.api.nvim_buf_set_extmark(buf, cursor_ns, 0, cursor, {
    end_row = 0,
    end_col = cursor + 1,
    hl_group = "ThemeCmdlineCursor",
    priority = 200,
  })
  vim.cmd.redraw()
  if menu_items then
    update_menu()
  end
end

-- UI callbacks may run during redraw; schedule window changes after the callback.
local function schedule_update()
  vim.schedule(update)
end

-- Handle cmdline_show: flatten the highlighted chunks into the displayed text.
function M.show(content, pos, firstc, prompt, indent, level)
  local chunks = {}
  for _, chunk in ipairs(content) do
    chunks[#chunks + 1] = chunk[2]
  end
  local text = (firstc .. prompt .. table.concat(chunks)):lower()
  if text:find("press", 1, true) and text:find("continue", 1, true) then
    -- nvim_input is fast and can release the modal prompt before deferred UI work.
    vim.api.nvim_input("<CR>")
    return true
  end

  lines[level] = {
    text = table.concat(chunks),
    pos = pos,
    firstc = firstc,
    prompt = prompt,
    indent = indent,
  }
  active = level
  schedule_update()
  return true
end

-- Handle cursor-only updates without rebuilding the stored command-line text.
function M.pos(pos, level)
  if lines[level] then
    lines[level].pos = pos
    active = level
    schedule_update()
  end
  return true
end

-- Remove a hidden command line and return to the highest remaining nesting level.
function M.hide(level)
  lines[level] = nil
  active = nil
  for current in pairs(lines) do
    if not active or current > active then
      active = current
    end
  end
  schedule_update()
  return true
end

-- Handle popupmenu_show only for the external command-line completion menu.
function M.popupmenu_show(items, selected, _, _, grid)
  if grid ~= -1 then
    return false
  end
  menu_items = items
  menu_selected = selected
  schedule_update()
  return true
end

-- Update the selected row without rebuilding the completion buffer.
function M.popupmenu_select(selected)
  if not menu_items then
    return false
  end
  menu_selected = selected
  vim.schedule(update_menu)
  return true
end

-- Handle popupmenu_hide and defer closing until after the UI callback returns.
function M.popupmenu_hide()
  if not menu_items then
    return false
  end
  menu_items = nil
  vim.schedule(function()
    close_menu()
    vim.cmd.redraw()
  end)
  return true
end

-- Attach this UI client once and route each Neovim event to its callback.
local function attach()
  if attached then
    return
  end

  event_handler.attach(ns, { ext_cmdline = true, ext_popupmenu = true }, {
    -- Return true for events rendered here, allowing Neovim to suppress its UI.
    cmdline_show = M.show,
    cmdline_pos = M.pos,
    cmdline_hide = M.hide,
    popupmenu_show = M.popupmenu_show,
    popupmenu_select = M.popupmenu_select,
    popupmenu_hide = M.popupmenu_hide,
  })
  attached = true
end

-- Configure native command-line options and refresh float positions on resize.
function M.setup()
  vim.opt.cmdheight = 0
  vim.opt.wildmenu = true
  vim.opt.wildoptions = "pum"
  vim.opt.wildmode = "full"
  attach()

  local group = vim.api.nvim_create_augroup("NativeCmdlinePopup", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = schedule_update,
  })
end

return M
