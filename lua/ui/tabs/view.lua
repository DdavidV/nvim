local M = {}

local close_glyph = "󰅖"
local click_base = 100000

local function escape_statusline(value)
  return tostring(value):gsub("%%", "%%%%"):gsub("[\r\n]", " ")
end

local function buffer_label(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return "[No Name]"
  end
  return vim.fs.basename(name)
end

-- Render one window's tab list and route its encoded clicks back to tab actions.
function M.new(state, helpers)
  local view = {}

  function view.render(winid)
    winid = winid or vim.api.nvim_get_current_win()
    if not helpers.is_editor_window(winid) then
      return ""
    end

    local buffers = helpers.window_buffers(winid)
    if #buffers == 0 then
      return ""
    end
    local active_buffer = vim.api.nvim_win_get_buf(winid)
    local parts = {}

    for index, bufnr in ipairs(buffers) do
      local selected = bufnr == active_buffer
      local entry = state.windows[winid]
      local preview = entry and entry.preview == bufnr
      local highlight = preview
          and (selected and "TabLinePreviewSel" or "TabLinePreview")
        or (selected and "TabLineSel" or "TabLine")
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

  function view.click(click_id)
    local winid = math.floor(click_id / click_base)
    local index = click_id % click_base
    local close_click = index >= click_base / 2
    if close_click then
      index = index - click_base / 2
    end

    if not helpers.is_editor_window(winid) then
      return
    end

    local bufnr = helpers.window_buffers(winid)[index]
    if bufnr then
      if close_click then
        helpers.close_window_tab(winid, bufnr)
      else
        helpers.set_editor_buffer(winid, bufnr)
      end
    end
  end

  return view
end

return M