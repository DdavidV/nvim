local M = {}
local close_glyph = "󰅖"

local state = {
  editor_window = nil,
  -- Each editor window owns its own ordered tab list; a buffer may be in many lists.
  windows = {},
  -- Save window-local options so an emptied split can be restored when reused.
  window_options = {},
}

-- Keep window and tab indices in separate ranges for the statusline click handler.
local click_base = 100000

local function redraw_tabs()
  -- Winbars are statuslines, so redraw them even in windows that are not focused.
  vim.cmd("redrawstatus!")
end

local function escape_statusline(value)
  -- Percent signs are statusline directives; escape filename text before rendering.
  return tostring(value):gsub("%%", "%%%%"):gsub("[\r\n]", " ")
end

local function is_empty_unnamed_buffer(bufnr)
  return vim.api.nvim_buf_get_name(bufnr) == ""
    and not vim.bo[bufnr].modified
    and vim.api.nvim_buf_line_count(bufnr) == 1
    and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""
end

local function is_empty_editor(bufnr)
  return vim.b[bufnr].handrolled_empty_editor == true
end

local function is_editor_window(winid)
  if type(winid) ~= "number" or not vim.api.nvim_win_is_valid(winid)
      or vim.api.nvim_win_get_config(winid).relative ~= "" then
    return false
  end
  local bufnr = vim.api.nvim_win_get_buf(winid)
  return vim.bo[bufnr].filetype ~= "native-explorer"
end

local function is_tab_buffer(bufnr)
  -- Only ordinary, listed file buffers appear as tabs; scratch/utility buffers do not.
  return vim.api.nvim_buf_is_valid(bufnr)
    and vim.bo[bufnr].buflisted
    and vim.bo[bufnr].buftype == ""
    and vim.bo[bufnr].filetype ~= "native-explorer"
    and not is_empty_unnamed_buffer(bufnr)
    and not is_empty_editor(bufnr)
end

local function editor_window(preferred)
  if preferred and is_editor_window(preferred) then
    return preferred
  end
  local current = vim.api.nvim_get_current_win()
  if is_editor_window(current) then
    state.editor_window = current
    return current
  end

  local winid = state.editor_window
  if is_editor_window(winid)
      and vim.api.nvim_win_get_tabpage(winid) == vim.api.nvim_get_current_tabpage() then
    return winid
  end

  for _, candidate in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor_window(candidate) then
      state.editor_window = candidate
      return candidate
    end
  end
end

local function window_state(winid)
  local entry = state.windows[winid]
  if not entry then
    entry = { buffers = {} }
    state.windows[winid] = entry
  end
  return entry
end

local function add_buffer(winid, bufnr)
  if not is_editor_window(winid) or not is_tab_buffer(bufnr) then
    return
  end

  local buffers = window_state(winid).buffers
  for _, existing in ipairs(buffers) do
    if existing == bufnr then
      return
    end
  end
  buffers[#buffers + 1] = bufnr
end

local function window_buffers(winid)
  local entry = window_state(winid)
  local active = vim.api.nvim_win_get_buf(winid)
  -- Track buffers assigned through normal Neovim commands as well as our own actions.
  add_buffer(winid, active)

  local buffers = {}
  for _, bufnr in ipairs(entry.buffers) do
    if is_tab_buffer(bufnr) then
      buffers[#buffers + 1] = bufnr
    end
  end
  entry.buffers = buffers
  return buffers
end

local function buffer_label(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return "[No Name]"
  end
  return vim.fs.basename(name)
end

local function set_editor_buffer(winid, bufnr)
  if not is_editor_window(winid) or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.fn.bufload(bufnr)
  vim.api.nvim_win_set_buf(winid, bufnr)
  state.editor_window = winid
  add_buffer(winid, bufnr)
end

function M.render(winid)
  winid = winid or vim.api.nvim_get_current_win()
  if not is_editor_window(winid) then
    return ""
  end

  local buffers = window_buffers(winid)
  if #buffers == 0 then
    return ""
  end
  local active_buffer = vim.api.nvim_win_get_buf(winid)
  local parts = {}

  for index, bufnr in ipairs(buffers) do
    local selected = bufnr == active_buffer
    local highlight = selected and "TabLineSel" or "TabLine"
    local label = escape_statusline(buffer_label(bufnr))
    local modified = vim.bo[bufnr].modified and " [+]" or ""
    -- Encode the target window and tab index so clicks act on the bar that was clicked.
    local select_id = winid * click_base + index
    local close_id = winid * click_base + click_base / 2 + index

    parts[#parts + 1] = "%#" .. highlight .. "#"
      .. "%" .. select_id .. "@v:lua.NvimHandRolledTabsClick@"
      .. " " .. label .. modified .. " "
      .. "%T"
      .. "%#" .. (selected and "TabLineCloseSel" or "TabLineClose") .. "#"
      .. "%" .. close_id .. "@v:lua.NvimHandRolledTabsClick@"
      .. " " .. close_glyph .. " "
      .. "%T"
  end

  parts[#parts + 1] = "%#TabLineFill#%T"
  return table.concat(parts)
end

function M.click(click_id)
  local winid = math.floor(click_id / click_base)
  local index = click_id % click_base
  local close_click = index >= click_base / 2
  if close_click then
    index = index - click_base / 2
  end

  if not is_editor_window(winid) then
    return
  end

  local bufnr = window_buffers(winid)[index]
  if bufnr then
    if close_click then
      M.close_window_tab(winid, bufnr)
    else
      set_editor_buffer(winid, bufnr)
    end
  end
end

local function remove_window_buffer(winid, bufnr)
  local entry = state.windows[winid]
  if not entry then
    return
  end
  for index, candidate in ipairs(entry.buffers) do
    if candidate == bufnr then
      table.remove(entry.buffers, index)
      return
    end
  end
end

local function buffer_in_other_window(winid, bufnr)
  -- Do not delete a buffer still displayed or listed in another split.
  for other_win, entry in pairs(state.windows) do
    if other_win ~= winid and vim.api.nvim_win_is_valid(other_win) then
      for _, candidate in ipairs(entry.buffers) do
        if candidate == bufnr then
          return true
        end
      end
    end
  end
  return false
end

local function create_empty_editor(winid)
  -- A private nofile buffer keeps the split alive after its final tab is closed.
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.b[bufnr].handrolled_empty_editor = true
  vim.api.nvim_win_set_buf(winid, bufnr)
  M.update_window_ui(winid)
  return bufnr
end

function M.close_window_tab(winid, bufnr)
  if not is_editor_window(winid) or not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local entry = window_state(winid)
  local buffers = window_buffers(winid)
  local name = buffer_label(bufnr)
  local target_index
  for position, candidate in ipairs(buffers) do
    if candidate == bufnr then
      target_index = position
      break
    end
  end
  local replacement
  -- Closing the active tab selects the next local tab, wrapping at the list end.
  if #buffers > 1 and target_index then
    replacement = buffers[target_index % #buffers + 1]
  end

  local active = vim.api.nvim_win_get_buf(winid) == bufnr
  local old_buffers = vim.deepcopy(entry.buffers)
  remove_window_buffer(winid, bufnr)
  if active then
    if replacement then
      vim.api.nvim_win_set_buf(winid, replacement)
    else
      create_empty_editor(winid)
    end
  end

  if not buffer_in_other_window(winid, bufnr) then
    -- A normal delete refuses modified buffers; restore the tab and report why.
    local ok, err = pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
    if not ok then
      entry.buffers = old_buffers
      if active and vim.api.nvim_win_is_valid(winid) then
        vim.api.nvim_win_set_buf(winid, bufnr)
      end
      if active then
        M.update_window_ui(winid)
      end
      vim.notify(("Cannot close %s: %s"):format(name, err), vim.log.levels.WARN)
      return false
    end
  end

  redraw_tabs()
  return true
end

function M.close_tab(index)
  local winid = editor_window()
  local bufnr = winid and window_buffers(winid)[index]
  M.close_window_tab(winid, bufnr)
end

function M.close_current()
  local winid = editor_window()
  if winid then
    M.close_window_tab(winid, vim.api.nvim_win_get_buf(winid))
  end
end

function M.close_all()
  local winid = editor_window()
  if not winid then
    return
  end
  for _, bufnr in ipairs(vim.deepcopy(window_buffers(winid))) do
    M.close_window_tab(winid, bufnr)
  end
end

function M.move(direction)
  local winid = editor_window()
  if not winid then
    return
  end
  local buffers = window_buffers(winid)
  if #buffers == 0 then
    return
  end

  local active_buffer = vim.api.nvim_win_get_buf(winid)
  local active_index
  for index, bufnr in ipairs(buffers) do
    if bufnr == active_buffer then
      active_index = index
      break
    end
  end

  local next_index
  if not active_index then
    next_index = direction > 0 and 1 or #buffers
  else
    next_index = ((active_index - 1 + direction) % #buffers) + 1
  end
  set_editor_buffer(winid, buffers[next_index])
end

local function other_editor_window(source, direction)
  local source_position = vim.api.nvim_win_get_position(source)
  local candidates = {}
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if winid ~= source and is_editor_window(winid) then
      local position = vim.api.nvim_win_get_position(winid)
      -- Prefer the requested side, then the closest split (including stacked splits).
      local is_requested_side = (direction > 0 and position[2] > source_position[2])
        or (direction < 0 and position[2] < source_position[2])
      candidates[#candidates + 1] = {
        winid = winid,
        is_requested_side = is_requested_side,
        distance = math.abs(position[2] - source_position[2])
          + math.abs(position[1] - source_position[1]) * 0.25,
      }
    end
  end

  table.sort(candidates, function(left, right)
    if left.is_requested_side ~= right.is_requested_side then
      return left.is_requested_side
    end
    return left.distance < right.distance
  end)
  return candidates[1] and candidates[1].winid
end

local function split_editor_window(source, direction)
  vim.api.nvim_set_current_win(source)
  vim.cmd(direction > 0 and "rightbelow vsplit" or "leftabove vsplit")
  local target = vim.api.nvim_get_current_win()
  state.windows[target] = { buffers = {} }
  add_buffer(target, vim.api.nvim_win_get_buf(target))
  M.update_window_ui(target)
  state.editor_window = target
  return target
end

function M.move_to_other_window(direction)
  local source = editor_window()
  if not source then
    return
  end
  local bufnr = vim.api.nvim_win_get_buf(source)
  if not is_tab_buffer(bufnr) then
    return
  end

  local target = other_editor_window(source, direction)
    or split_editor_window(source, direction)
  add_buffer(target, bufnr)
  vim.api.nvim_win_set_buf(target, bufnr)
  M.close_window_tab(source, bufnr)
  vim.api.nvim_set_current_win(target)
end

function M.open_in_other_window(direction)
  local source = editor_window()
  if not source then
    return
  end
  local bufnr = vim.api.nvim_win_get_buf(source)
  if not is_tab_buffer(bufnr) then
    return
  end

  local target = other_editor_window(source, direction)
    or split_editor_window(source, direction)
  add_buffer(target, bufnr)
  vim.api.nvim_win_set_buf(target, bufnr)
  state.editor_window = target
  vim.api.nvim_set_current_win(target)
end

function M.track(winid, bufnr)
  add_buffer(winid, bufnr or vim.api.nvim_win_get_buf(winid))
  if is_editor_window(winid) then
    state.editor_window = winid
  end
end

function M.update_window_ui(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winid)
  -- A per-window winbar avoids taking a full-width row from the explorer.
  if vim.bo[bufnr].filetype == "native-explorer" or is_empty_editor(bufnr) then
    vim.wo[winid].winbar = ""
  else
    vim.wo[winid].winbar = "%!v:lua.require'ui.tabs'.render(" .. winid .. ")"
  end

  if is_empty_editor(bufnr) then
    if not state.window_options[winid] then
      state.window_options[winid] = {
        number = vim.wo[winid].number,
        relativenumber = vim.wo[winid].relativenumber,
        signcolumn = vim.wo[winid].signcolumn,
        cursorline = vim.wo[winid].cursorline,
      }
    end
    vim.wo[winid].number = false
    vim.wo[winid].relativenumber = false
    vim.wo[winid].signcolumn = "no"
    vim.wo[winid].cursorline = false
  elseif state.window_options[winid] then
    local options = state.window_options[winid]
    vim.wo[winid].number = options.number
    vim.wo[winid].relativenumber = options.relativenumber
    vim.wo[winid].signcolumn = options.signcolumn
    vim.wo[winid].cursorline = options.cursorline
    state.window_options[winid] = nil
  end
end

function M.setup()
  -- A per-window winbar keeps tabs above the editor without reserving a
  -- full-width row over the explorer.
  vim.o.showtabline = 0

  _G.NvimHandRolledTabsClick = M.click

  local group = vim.api.nvim_create_augroup("HandRolledTabs", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function()
      local winid = vim.api.nvim_get_current_win()
      M.track(winid)
      M.update_window_ui(winid)
    end,
  })
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      local winid = vim.api.nvim_get_current_win()
      if vim.api.nvim_win_get_config(winid).relative == ""
          and vim.bo[vim.api.nvim_win_get_buf(winid)].filetype ~= "native-explorer" then
        state.editor_window = winid
        M.track(winid)
      end
      M.update_window_ui(winid)
    end,
  })
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    M.track(winid)
    M.update_window_ui(winid)
  end
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(event)
      -- Remove a deleted buffer from every split's independent tab list.
      for _, entry in pairs(state.windows) do
        for index = #entry.buffers, 1, -1 do
          if entry.buffers[index] == event.buf then
            table.remove(entry.buffers, index)
          end
        end
      end
      vim.schedule(function()
        redraw_tabs()
      end)
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(event)
      local winid = tonumber(event.match)
      -- Window IDs can be reused, so discard all state associated with a closed one.
      state.windows[winid] = nil
      state.window_options[winid] = nil
    end,
  })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufFilePost", "BufModifiedSet", "BufWritePost", "VimResized" }, {
    group = group,
    callback = function()
      vim.schedule(function()
        redraw_tabs()
      end)
    end,
  })
end

return M
