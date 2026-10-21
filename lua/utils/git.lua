local M = {}
local branch_cache = {}

local function finish_lookup(bufnr, entry, branch)
  if branch_cache[bufnr] ~= entry then
    return
  end

  entry.branch = branch ~= "" and branch or false

  -- Notify callers on the main loop; Git process callbacks can run in a fast event.
  vim.schedule(function()
    if branch_cache[bufnr] ~= entry then
      return
    end

    for callback in pairs(entry.listeners) do
      callback(bufnr, entry.branch ~= false and entry.branch or nil)
    end
  end)
end

local function run_git(args, callback)
  vim.system(args, { text = true }, callback)
end

local function lookup_branch(bufnr, entry, directory)
  if vim.fn.executable("git") ~= 1 then
    finish_lookup(bufnr, entry, "")
    return
  end

  -- Pass arguments directly rather than through a shell, so paths need no quoting.
  run_git({ "git", "-C", directory, "branch", "--show-current" }, function(result)
    if result.code ~= 0 then
      finish_lookup(bufnr, entry, "")
      return
    end

    local branch = vim.trim(result.stdout)
    if branch ~= "" then
      finish_lookup(bufnr, entry, branch)
      return
    end

    -- Detached HEAD has no current branch name; show its short commit hash instead.
    run_git({ "git", "-C", directory, "rev-parse", "--short", "HEAD" }, function(hash_result)
      local hash = hash_result.code == 0 and vim.trim(hash_result.stdout) or ""
      finish_lookup(bufnr, entry, hash)
    end)
  end)
end

function M.branch(bufnr, on_update)
  local entry = branch_cache[bufnr]
  if entry then
    if on_update and entry.branch == nil then
      entry.listeners[on_update] = true
    end
    return entry.branch ~= false and entry.branch or nil
  end

  entry = { listeners = {} }
  if on_update then
    entry.listeners[on_update] = true
  end
  branch_cache[bufnr] = entry

  local filename = vim.api.nvim_buf_get_name(bufnr)
  local directory = filename == "" and vim.fn.getcwd() or vim.fs.dirname(filename)
  lookup_branch(bufnr, entry, directory)

  return nil
end

function M.clear_cache()
  -- In-flight callbacks check their entry before updating, so cleared results stay stale.
  branch_cache = {}
end

return M
