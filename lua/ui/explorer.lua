local M = {}

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
  git_status = {},
  git_status_request = 0,
}

local namespace = vim.api.nvim_create_namespace("HandRolledExplorer")
local resize_check_timer
local render

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

local function status_highlight(status)
  if status.untracked then
    return "ExplorerGitUntracked"
  end
  return "ExplorerGitModified"
end

local function merge_git_status(path, status)
  local current = state.git_status[path] or { untracked = false, modified = false }
  current[status == "U" and "untracked" or "modified"] = true
  state.git_status[path] = current
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

local function parse_git_status(root, output)
  state.git_status = {}
  local entries = vim.split(output, "\0", { plain = true, trimempty = true })
  local index = 1

  while index <= #entries do
    local entry = entries[index]
    local status = entry:sub(1, 2)
    local path = entry:sub(4)
    local marker
    if status == "??" then
      marker = "U"
    elseif status:find("[^ ]") then
      marker = "M"
    end

    if marker and path ~= "" then
      local absolute_path = normalize(vim.fs.joinpath(root, path))
      merge_git_status(absolute_path, marker)

      local parent = vim.fs.dirname(absolute_path)
      while parent and parent ~= absolute_path do
        merge_git_status(parent, marker)
        if parent == root then
          break
        end
        absolute_path, parent = parent, vim.fs.dirname(parent)
      end
    end

    index = index + ((status:find("[RC]")) and 2 or 1)
  end
end

local function refresh_git_status()
  if not state.root or vim.fn.executable("git") ~= 1 then
    return
  end

  local root = state.root
  state.git_status_request = state.git_status_request + 1
  local request = state.git_status_request
  vim.system({
    "git",
    "-C",
    root,
    "status",
    "--porcelain=v1",
    "-z",
    "--untracked-files=all",
  }, { text = true }, function(result)
    vim.schedule(function()
      if request ~= state.git_status_request or root ~= state.root then
        return
      end
      if result.code == 0 then
        parse_git_status(root, result.stdout)
      else
        state.git_status = {}
      end
      render()
    end)
  end)
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
  local status = state.git_status[normalize(path)]
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
    group = icon_highlight,
    line = #lines - 1,
    start_col = #connector,
    end_col = #connector + #icon,
  }
  add_status_highlights(
    highlights,
    #lines - 1,
    #connector + #icon + 1,
    #name,
    status
  )

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

render = function(preferred_path)
  if not state.buffer or not vim.api.nvim_buf_is_valid(state.buffer) then
    return
  end

  -- Remember the selected path so expanding a folder doesn't move the selection.
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

local function open_node(node, preview)
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
  require("ui.tabs").open_in_window(editor_window, bufnr, preview)
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
    open_node(node, true)
  end)
end

local function notify_filesystem_error(action, err)
  vim.notify(action .. ": " .. (err or "unknown filesystem error"), vim.log.levels.ERROR)
end

local function selected_parent()
  local node = node_at_cursor()
  if node and node.directory then
    return node.path
  end
  return node and vim.fs.dirname(node.path) or state.root
end

local function entry_name_is_valid(name)
  return name ~= "" and name ~= "." and name ~= ".." and not name:find("/", 1, true)
end

local function create_entry(directory)
  local parent = selected_parent()
  vim.ui.input({ prompt = directory and "New directory: " or "New file: " }, function(name)
    if not name or name == "" then
      return
    end
    if not entry_name_is_valid(name) then
      vim.notify("Enter a name without path separators.", vim.log.levels.WARN)
      return
    end

    local path = normalize(vim.fs.joinpath(parent, name))
    local result, err
    if directory then
      result, err = vim.uv.fs_mkdir(path, 493)
    else
      local fd
      fd, err = vim.uv.fs_open(
        path,
        vim.uv.constants.O_CREAT | vim.uv.constants.O_EXCL | vim.uv.constants.O_WRONLY,
        420
      )
      if fd then
        result, err = vim.uv.fs_close(fd)
      end
    end

    if not result then
      notify_filesystem_error("Unable to create " .. path, err)
      return
    end
    if directory then
      state.expanded[parent] = true
      state.expanded[path] = true
    end
    render(path)
    refresh_git_status()
  end)
end

local function remap_expanded_paths(old_path, new_path)
  local separator = package.config:sub(1, 1)
  local remapped = {}
  for path, expanded in pairs(state.expanded) do
    if path == old_path or path:sub(1, #old_path + 1) == old_path .. separator then
      remapped[new_path .. path:sub(#old_path + 1)] = expanded
    else
      remapped[path] = expanded
    end
  end
  state.expanded = remapped
end

local function remove_expanded_paths(path)
  local separator = package.config:sub(1, 1)
  for expanded_path in pairs(state.expanded) do
    if expanded_path == path
        or expanded_path:sub(1, #path + 1) == path .. separator then
      state.expanded[expanded_path] = nil
    end
  end
end

local function delete_node()
  local node = node_at_cursor()
  if not node then
    return
  end

  local entry_type = node.directory and "directory" or "file"
  vim.ui.select({ "Delete", "Cancel" }, {
    prompt = ("Delete %s %s?"):format(entry_type, vim.fs.basename(node.path)),
  }, function(choice)
    if choice ~= "Delete" then
      return
    end

    local ok, err = pcall(vim.fs.rm, node.path, { recursive = node.directory })
    if not ok then
      notify_filesystem_error("Unable to delete " .. node.path, err)
      return
    end
    if node.directory then
      remove_expanded_paths(node.path)
    end
    render()
    refresh_git_status()
  end)
end

local function rename_node()
  local node = node_at_cursor()
  if not node then
    return
  end

  vim.ui.input({ prompt = "Rename to: ", default = vim.fs.basename(node.path) }, function(name)
    if not name or name == "" or name == vim.fs.basename(node.path) then
      return
    end
    if not entry_name_is_valid(name) then
      vim.notify("Enter a name without path separators.", vim.log.levels.WARN)
      return
    end

    local new_path = normalize(vim.fs.joinpath(vim.fs.dirname(node.path), name))
    if vim.uv.fs_lstat(new_path) then
      vim.notify("The destination already exists: " .. new_path, vim.log.levels.WARN)
      return
    end
    local ok, err = vim.uv.fs_rename(node.path, new_path)
    if not ok then
      notify_filesystem_error("Unable to rename " .. node.path, err)
      return
    end
    if node.directory then
      remap_expanded_paths(node.path, new_path)
    end
    render(new_path)
    refresh_git_status()
  end)
end

local function move_node()
  local node = node_at_cursor()
  if not node then
    return
  end

  local source_parent = vim.fs.dirname(node.path)
  vim.ui.input({ prompt = "Move into directory: ", default = source_parent }, function(destination)
    if not destination or destination == "" then
      return
    end

    destination = vim.fn.expand(destination)
    if destination:sub(1, 1) ~= "/" then
      destination = vim.fs.joinpath(source_parent, destination)
    end
    destination = normalize(destination)
    if not is_directory(destination) then
      vim.notify("Destination is not a directory: " .. destination, vim.log.levels.WARN)
      return
    end

    local separator = package.config:sub(1, 1)
    if node.directory and (destination == node.path
        or destination:sub(1, #node.path + 1) == node.path .. separator) then
      vim.notify("A directory cannot be moved into itself.", vim.log.levels.WARN)
      return
    end

    local new_path = normalize(vim.fs.joinpath(destination, vim.fs.basename(node.path)))
    if new_path == node.path then
      return
    end
    if vim.uv.fs_lstat(new_path) then
      vim.notify("The destination already exists: " .. new_path, vim.log.levels.WARN)
      return
    end
    local ok, err = vim.uv.fs_rename(node.path, new_path)
    if not ok then
      notify_filesystem_error("Unable to move " .. node.path, err)
      return
    end
    if node.directory then
      remap_expanded_paths(node.path, new_path)
    end
    state.expanded[destination] = true
    render(new_path)
    refresh_git_status()
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

  local function open_preview()
    open_node(nil, true)
  end
  map("<CR>", open_preview, "Preview file or toggle directory")
  map("o", open_preview, "Preview file or toggle directory")
  map("a", function() create_entry(false) end, "Create file")
  map("A", function() create_entry(true) end, "Create directory")
  map("r", rename_node, "Rename file or directory")
  map("m", move_node, "Move file or directory")
  map("d", delete_node, "Delete file or directory")
  map("R", refresh_git_status, "Refresh explorer")
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
  vim.wo[state.window].list = false
  -- Show the selection while the explorer has keyboard focus.
  vim.wo[state.window].cursorline = true

  render()
  refresh_git_status()
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
            or vim.api.nvim_win_get_config(new_window).relative ~= ""
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
      if vim.api.nvim_win_get_config(winid).relative == ""
          and vim.bo[bufnr].filetype ~= "native-explorer" then
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
  vim.api.nvim_create_autocmd({ "BufWritePost", "FocusGained" }, {
    group = group,
    callback = function()
      if state.window and vim.api.nvim_win_is_valid(state.window) then
        refresh_git_status()
      end
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "GitSignsUpdate",
    callback = refresh_git_status,
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
