local M = {}

local function normalize(path)
  return vim.fs.normalize(path)
end

local function merge_status(statuses, path, status)
  local current = statuses[path] or { untracked = false, modified = false }
  current[status == "U" and "untracked" or "modified"] = true
  statuses[path] = current
end

local function parse_status(root, output)
  local statuses = {}
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
      merge_status(statuses, absolute_path, marker)

      local parent = vim.fs.dirname(absolute_path)
      while parent and parent ~= absolute_path do
        merge_status(statuses, parent, marker)
        if parent == root then
          break
        end
        absolute_path, parent = parent, vim.fs.dirname(parent)
      end
    end

    index = index + ((status:find("[RC]")) and 2 or 1)
  end

  return statuses
end

-- Refresh asynchronously and ignore results from stale roots or requests.
function M.refresh(state, render)
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
        state.git_status = parse_status(root, result.stdout)
      else
        state.git_status = {}
      end
      render()
    end)
  end)
end

return M