local M = {}

local function normalize(path)
  return vim.fs.normalize(path)
end

local function is_directory(path)
  return vim.fn.isdirectory(path) == 1
end

local function notify_filesystem_error(action, err)
  vim.notify(action .. ": " .. (err or "unknown filesystem error"), vim.log.levels.ERROR)
end

local function remap_expanded_paths(state, old_path, new_path)
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

local function remove_expanded_paths(state, path)
  local separator = package.config:sub(1, 1)
  for expanded_path in pairs(state.expanded) do
    if expanded_path == path or expanded_path:sub(1, #path + 1) == path .. separator then
      state.expanded[expanded_path] = nil
    end
  end
end

-- Build filesystem actions around explorer state and its render/refresh callbacks.
function M.new(state, tree, render, refresh_git_status)
  local actions = {}

  local function selected_node()
    return tree.node_at_cursor(state)
  end

  local function selected_parent()
    local node = selected_node()
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

  function actions.create_file()
    create_entry(false)
  end

  function actions.create_directory()
    create_entry(true)
  end

  function actions.delete()
    local node = selected_node()
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
        remove_expanded_paths(state, node.path)
      end
      render()
      refresh_git_status()
    end)
  end

  function actions.rename()
    local node = selected_node()
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
        remap_expanded_paths(state, node.path, new_path)
      end
      render(new_path)
      refresh_git_status()
    end)
  end

  function actions.move()
    local node = selected_node()
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
        remap_expanded_paths(state, node.path, new_path)
      end
      state.expanded[destination] = true
      render(new_path)
      refresh_git_status()
    end)
  end

  return actions
end

return M