local M = {}

local function is_directory(path)
  return vim.fn.isdirectory(path) == 1
end

local function set_buffer_lines(buffer, lines)
  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].modifiable = false
end

local function status_highlight(status)
  return status.untracked and "ExplorerGitUntracked" or "ExplorerGitModified"
end

local function status_marker(status)
  if not status then
    return ""
  end

  local markers = {}
  if status.untracked then
    markers[#markers + 1] = "U"
  end
  if status.modified then
    markers[#markers + 1] = "M"
  end
  return "  " .. table.concat(markers, " ")
end

local function add_status_highlights(highlights, line, name_start, name_length, status)
  if not status then
    return
  end

  highlights[#highlights + 1] = {
    group = status_highlight(status),
    line = line,
    start_col = name_start,
    end_col = name_start + name_length,
  }

  local marker_col = name_start + name_length + 2
  if status.untracked then
    highlights[#highlights + 1] = {
      group = "ExplorerGitUntracked",
      line = line,
      start_col = marker_col,
      end_col = marker_col + 1,
    }
    marker_col = marker_col + 2
  end
  if status.modified then
    highlights[#highlights + 1] = {
      group = "ExplorerGitModified",
      line = line,
      start_col = marker_col,
      end_col = marker_col + 1,
    }
  end
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
    if left.directory ~= right.directory then
      return left.directory
    end
    return left.name:lower() < right.name:lower()
  end)

  return entries
end

local function add_entry(state, path, depth, ancestor_is_last, is_last, lines, highlights)
  local name = vim.fs.basename(path)
  local directory = is_directory(path)
  local expanded = directory and state.expanded[path]
  local status = state.git_status[vim.fs.normalize(path)]
  local marker = status_marker(status)
  local prefix = {}
  for _, ancestor_is_last_entry in ipairs(ancestor_is_last) do
    prefix[#prefix + 1] = ancestor_is_last_entry and "  " or "│ "
  end
  prefix[#prefix + 1] = is_last and "└─ " or "├─ "

  local icon, icon_highlight
  if directory then
    icon, icon_highlight = MiniIcons.get("directory", path)
  else
    icon, icon_highlight = MiniIcons.get("file", path)
  end
  local connector = table.concat(prefix)
  lines[#lines + 1] = connector .. icon .. " " .. name .. marker
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
    group = icon_highlight,
    line = #lines - 1,
    start_col = #connector,
    end_col = #connector + #icon,
  }
  add_status_highlights(highlights, #lines - 1, #connector + #icon + 1, #name, status)

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
    add_entry(state, entry.path, depth + 1, child_ancestors, index == #entries, lines, highlights)
  end
end

-- Render the filesystem tree and preserve selection by path across redraws.
function M.render(state, namespace, preferred_path)
  if not state.buffer or not vim.api.nvim_buf_is_valid(state.buffer) then
    return
  end

  local cursor_path = preferred_path
  if not cursor_path and state.window and vim.api.nvim_win_is_valid(state.window) then
    local cursor = vim.api.nvim_win_get_cursor(state.window)
    cursor_path = state.nodes[cursor[1]] and state.nodes[cursor[1]].path
  end

  state.nodes = {}
  vim.api.nvim_buf_clear_namespace(state.buffer, namespace, 0, -1)
  local root_name = vim.fs.basename(state.root)
  local root_icon, root_icon_highlight = MiniIcons.get("directory", state.root)
  local root_status = state.git_status[state.root]
  local root_marker = status_marker(root_status)
  local lines = { root_icon .. " " .. root_name .. root_marker }
  local highlights = { { group = "ExplorerRoot", line = 0 } }
  add_status_highlights(highlights, 0, #root_icon + 1, #root_name, root_status)
  highlights[#highlights + 1] = {
    group = root_icon_highlight,
    line = 0,
    start_col = 0,
    end_col = #root_icon,
  }

  local entries = directory_entries(state.root)
  if entries then
    for index, entry in ipairs(entries) do
      add_entry(state, entry.path, 0, {}, index == #entries, lines, highlights)
    end
  else
    lines[#lines + 1] = "[Unable to read directory]"
  end
  set_buffer_lines(state.buffer, lines)

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

function M.node_at_cursor(state)
  if not state.window or not vim.api.nvim_win_is_valid(state.window) then
    return nil
  end
  local line = vim.api.nvim_win_get_cursor(state.window)[1]
  return state.nodes[line]
end

return M