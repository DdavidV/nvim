local M = {}
local icons = require("utils.icons")

local config = {
  width = 30,
  min_width = 12,
  resize_delay = 1000,
}

-- Keep the explorer's tree and window references together as it is opened,
-- closed, and redrawn.
local state = {
  expanded = {},
  nodes = {},
  root = nil,
  buffer = nil,
  window = nil,
  editor_window = nil,
}

local namespace = vim.api.nvim_create_namespace("HandRolledExplorer")
local resize_check_timer

local function cancel_resize_check()
  if resize_check_timer then
    resize_check_timer:stop()
    resize_check_timer:close()
    resize_check_timer = nil
  end
end

local function normalize(path)
  return vim.fs.normalize(path)
end

local function is_directory(path)
  return vim.fn.isdirectory(path) == 1
end

local function set_buffer_lines(lines)
  vim.bo[state.buffer].modifiable = true
  vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
  vim.bo[state.buffer].modifiable = false
end

local function directory_entries(path)
  local entries = {}
  local ok, iterator, directory_state = pcall(vim.fs.dir, path)
  if not ok or not iterator then
    return nil
  end

  for name, entry_type in iterator, directory_state do
    if name ~= ".git" then
      entries[#entries + 1] = {
        name = name,
        path = vim.fs.joinpath(path, name),
        directory = entry_type == "directory",
      }
    end
  end

  table.sort(entries, function(left, right)
    -- Keep folders above files, then sort names without case sensitivity.
    if left.directory ~= right.directory then
      return left.directory
    end
    return left.name:lower() < right.name:lower()
  end)

  return entries
end

local function add_entry(path, depth, ancestor_is_last, is_last, lines, highlights)
  local name = vim.fs.basename(path)
  local directory = is_directory(path)
  local expanded = directory and state.expanded[path]
  local prefix = {}
  for _, ancestor_is_last_entry in ipairs(ancestor_is_last) do
    prefix[#prefix + 1] = ancestor_is_last_entry and "    " or "│   "
  end
  prefix[#prefix + 1] = is_last and "└── " or "├── "

  local icon
  if directory then
    icon = icons.get_directory(name, expanded)
  else
    icon = icons.get_file(name)
  end
  local connector = table.concat(prefix)
  lines[#lines + 1] = connector .. icon.glyph .. " " .. name
  -- Map each rendered row back to its filesystem entry for keyboard and mouse actions.
  state.nodes[#lines] = { path = path, directory = directory }
  highlights[#highlights + 1] = {
    group = directory and "ExplorerDirectory" or "ExplorerFile",
    line = #lines - 1,
  }
  highlights[#highlights + 1] = {
    group = "ExplorerTree",
    line = #lines - 1,
    start_col = 0,
    end_col = #connector,
  }
  highlights[#highlights + 1] = {
    group = icon.highlight,
    line = #lines - 1,
    start_col = #connector,
    end_col = #connector + #icon.glyph,
  }

  if not expanded then
    return
  end

  local entries = directory_entries(path)
  if not entries then
    lines[#lines + 1] = string.rep("  ", depth + 1) .. "[Unable to read directory]"
    return
  end

  if #entries == 0 then
    lines[#lines + 1] = string.rep("  ", depth + 1) .. "[Empty]"
    return
  end

  local child_ancestors = vim.list_extend(vim.deepcopy(ancestor_is_last), { is_last })
  for index, entry in ipairs(entries) do
    add_entry(entry.path, depth + 1, child_ancestors, index == #entries, lines, highlights)
  end
end

local function render()
  if not state.buffer or not vim.api.nvim_buf_is_valid(state.buffer) then
    return
  end

  -- Remember the selected path so expanding a folder doesn't move the selection.
  local cursor_path
  if state.window and vim.api.nvim_win_is_valid(state.window) then
    local cursor = vim.api.nvim_win_get_cursor(state.window)
    cursor_path = state.nodes[cursor[1]] and state.nodes[cursor[1]].path
  end

  state.nodes = {}
  vim.api.nvim_buf_clear_namespace(state.buffer, namespace, 0, -1)
  local root_name = vim.fs.basename(state.root)
  local root_icon = icons.get_directory(root_name, true)
  local lines = { root_icon.glyph .. " " .. root_name }
  local highlights = { { group = "ExplorerRoot", line = 0 } }
  highlights[#highlights + 1] = {
    group = root_icon.highlight,
    line = 0,
    start_col = 0,
    end_col = #root_icon.glyph,
  }
  local entries = directory_entries(state.root)
  if entries then
    for index, entry in ipairs(entries) do
      add_entry(entry.path, 0, {}, index == #entries, lines, highlights)
    end
  else
    lines[#lines + 1] = "[Unable to read directory]"
  end
  set_buffer_lines(lines)

  for _, highlight in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(
      state.buffer,
      namespace,
      highlight.group,
      highlight.line,
      highlight.start_col or 0,
      highlight.end_col or -1
    )
  end

  if cursor_path and state.window and vim.api.nvim_win_is_valid(state.window) then
    for line, node in pairs(state.nodes) do
      if node.path == cursor_path then
        vim.api.nvim_win_set_cursor(state.window, { line, 0 })
        break
      end
    end
  end
end

local function node_at_cursor()
  if not state.window or not vim.api.nvim_win_is_valid(state.window) then
    return nil
  end
  local line = vim.api.nvim_win_get_cursor(state.window)[1]
  return state.nodes[line]
end

local function open_node(node)
  node = node or node_at_cursor()
  if not node then
    return
  end

  if node.directory then
    -- Directories expand in place; files load into the editor split.
    state.expanded[node.path] = not state.expanded[node.path]
    render()
    return
  end

  local path = node.path
  local tabpage = vim.api.nvim_win_get_tabpage(state.window)
  local editor_window = state.editor_window
  -- Recover the editor split if it was closed, invalidated, or moved to another tab.
  if not editor_window or not vim.api.nvim_win_is_valid(editor_window)
      or editor_window == state.window
      or vim.api.nvim_win_get_tabpage(editor_window) ~= tabpage then
    editor_window = nil
    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      if winid ~= state.window
          and vim.bo[vim.api.nvim_win_get_buf(winid)].filetype ~= "native-explorer" then
        editor_window = winid
        break
      end
    end
  end

  if not editor_window then
    return
  end

  state.editor_window = editor_window
  local bufnr = vim.fn.bufadd(path)
  vim.fn.bufload(bufnr)
  -- Make explorer-opened files participate in the editor's persistent tabline.
  vim.bo[bufnr].buflisted = true
  vim.api.nvim_win_set_buf(editor_window, bufnr)
  require("ui.tabs").track(editor_window, bufnr)
  require("ui.tabs").update_window_ui(editor_window)
end

local function click_node()
  if not state.window or not vim.api.nvim_win_is_valid(state.window) then
    return
  end

  local mouse = vim.fn.getmousepos()
  local row = mouse.line
  if row < 1 or (mouse.winid ~= 0 and mouse.winid ~= state.window) or not state.nodes[row] then
    return
  end

  local node = state.nodes[row]
  -- Wait for the mouse release to finish before changing the editor buffer.
  vim.schedule(function()
    if not state.window or not vim.api.nvim_win_is_valid(state.window) then
      return
    end
    vim.api.nvim_win_set_cursor(state.window, { row, 0 })
    open_node(node)
  end)
end

local function schedule_resize_check()
  cancel_resize_check()
  local window = state.window
  if not window or not vim.api.nvim_win_is_valid(window) then
    return
  end

  -- Wait for the drag to finish before closing the window that was resized.
  resize_check_timer = vim.defer_fn(function()
    resize_check_timer = nil
    if state.window ~= window or not vim.api.nvim_win_is_valid(window)
        or vim.api.nvim_win_get_width(window) > config.min_width then
      return
    end

    -- Apply the layout change after the resize callback has fully returned.
    vim.schedule(function()
      if state.window == window and vim.api.nvim_win_is_valid(window)
          and vim.api.nvim_win_get_width(window) <= config.min_width then
        M.close()
      end
    end)
  end, config.resize_delay)
end

local function create_buffer()
  if state.buffer and vim.api.nvim_buf_is_valid(state.buffer) then
    return
  end

  state.buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buffer].buftype = "nofile"
  vim.bo[state.buffer].bufhidden = "hide"
  vim.bo[state.buffer].swapfile = false
  vim.bo[state.buffer].filetype = "native-explorer"

  -- Buffer-local mappings keep explorer commands out of normal editing buffers.
  local function map(lhs, callback, description)
    vim.keymap.set("n", lhs, callback, {
      buffer = state.buffer,
      silent = true,
      desc = description,
    })
  end

  map("<CR>", open_node, "Open file or toggle directory")
  map("o", open_node, "Open file or toggle directory")
  map("R", render, "Refresh explorer")
  map("q", M.close, "Close explorer")
  map("<LeftRelease>", click_node, "Open or toggle clicked entry")
  local function prevent_split()
    vim.notify("The explorer cannot be split.", vim.log.levels.INFO)
  end
  map("<C-w>s", prevent_split, "Prevent splitting the explorer")
  map("<C-w>v", prevent_split, "Prevent splitting the explorer")
  map("<C-w><C-s>", prevent_split, "Prevent splitting the explorer")
  map("<C-w><C-v>", prevent_split, "Prevent splitting the explorer")
end

function M.open()
  if state.window and vim.api.nvim_win_is_valid(state.window) then
    vim.api.nvim_set_current_win(state.window)
    return
  end

  state.root = normalize(vim.fn.getcwd())
  state.expanded = { [state.root] = true }
  create_buffer()

  local previous_window = vim.api.nvim_get_current_win()
  vim.cmd("topleft vertical split")
  state.window = vim.api.nvim_get_current_win()
  state.editor_window = previous_window
  vim.api.nvim_win_set_buf(state.window, state.buffer)
  vim.api.nvim_win_set_width(state.window, config.width)
  vim.wo[state.window].number = false
  vim.wo[state.window].relativenumber = false
  vim.wo[state.window].signcolumn = "no"
  vim.wo[state.window].foldcolumn = "0"
  vim.wo[state.window].wrap = false
  -- Show the selection while the explorer has keyboard focus.
  vim.wo[state.window].cursorline = true

  render()
  vim.api.nvim_set_current_win(state.window)
end

function M.close()
  cancel_resize_check()
  local window = state.window
  local editor_window = state.editor_window
  state.window = nil

  if window and vim.api.nvim_win_is_valid(window) then
    if editor_window and vim.api.nvim_win_is_valid(editor_window)
        and vim.api.nvim_win_get_tabpage(editor_window) == vim.api.nvim_win_get_tabpage(window)
        and vim.api.nvim_get_current_win() == window then
      vim.api.nvim_set_current_win(editor_window)
    end
    vim.api.nvim_win_close(window, true)
  end
  state.editor_window = nil
end

function M.toggle()
  if state.window and vim.api.nvim_win_is_valid(state.window) then
    M.close()
  else
    M.open()
  end
end

function M.setup(options)
  options = options or {}
  config = vim.tbl_deep_extend("force", config, options)
  assert(
    type(config.min_width) == "number" and config.min_width >= 1
      and config.min_width % 1 == 0,
    "explorer min_width must be a positive integer"
  )
  assert(
    type(config.resize_delay) == "number" and config.resize_delay >= 1
      and config.resize_delay % 1 == 0,
    "explorer resize_delay must be a positive integer"
  )

  local group = vim.api.nvim_create_augroup("HandRolledExplorer", { clear = true })
  vim.api.nvim_create_autocmd("WinNew", {
    group = group,
    callback = function()
      local new_window = vim.api.nvim_get_current_win()
      vim.schedule(function()
        local explorer_window = state.window
        if not explorer_window or explorer_window == new_window
            or not vim.api.nvim_win_is_valid(explorer_window)
            or not vim.api.nvim_win_is_valid(new_window)
            or vim.bo[vim.api.nvim_win_get_buf(new_window)].filetype ~= "native-explorer" then
          return
        end

        if vim.api.nvim_get_current_win() == new_window then
          vim.api.nvim_set_current_win(explorer_window)
        end
        vim.api.nvim_win_close(new_window, true)
        vim.notify("The explorer cannot be split.", vim.log.levels.INFO)
      end)
    end,
  })
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      local winid = vim.api.nvim_get_current_win()
      local bufnr = vim.api.nvim_win_get_buf(winid)
      -- Track the last non-explorer window as the destination for opened files.
      if vim.bo[bufnr].filetype ~= "native-explorer" then
        state.editor_window = winid
      end
    end,
  })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = function()
      for index = 0, vim.fn.argc() - 1 do
        local argument = vim.fn.argv(index)
        local path = vim.fn.fnamemodify(argument, ":p")
        if is_directory(path) then
          -- Replace the default directory-buffer behavior with the custom explorer.
          vim.cmd.cd(vim.fn.fnameescape(path))
          local directory_buffer = vim.api.nvim_get_current_buf()
          if is_directory(vim.api.nvim_buf_get_name(directory_buffer)) then
            vim.cmd.enew()
            if vim.api.nvim_buf_is_valid(directory_buffer) then
              vim.api.nvim_buf_delete(directory_buffer, { force = false })
            end
          end
          M.open()
          return
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinResized", {
    group = group,
    callback = schedule_resize_check,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(event)
      local closed_window = tonumber(event.match)
      -- Clear stale references when either split is closed outside the explorer.
      if state.window == closed_window then
        state.window = nil
      end
      if state.editor_window == closed_window then
        state.editor_window = nil
      end
    end,
  })
end

return M
