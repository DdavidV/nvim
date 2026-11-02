local M = {}

local default_filetypes = { "elixir", "eelixir", "heex", "surface" }

-- Prefer Mix roots, including umbrella roots; use Git for standalone Elixir files.
local function find_root(bufnr, on_dir)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local mix_files = vim.fs.find({ "mix.exs" }, {
    upward = true,
    limit = 2,
    path = filename,
  })
  local mix_file = mix_files[2] or mix_files[1]
  if mix_file then
    on_dir(vim.fs.dirname(mix_file))
    return
  end

  local git_dir = vim.fs.find({ ".git" }, { upward = true, path = filename })[1]
  if git_dir then
    on_dir(vim.fs.dirname(git_dir))
  end
end

-- Register ElixirLS and describe how the generic loader checks and installs it.
function M.setup(options)
  options = options or {}
  local command = { vim.fn.stdpath("data") .. "/servers/elixir-ls/language_server.sh" }

  vim.lsp.config("elixirls", {
    cmd = command,
    filetypes = options.filetypes or default_filetypes,
    root_dir = find_root,
  })

  return {
    name = "elixirls",
    command = command,
    setup_script = "scripts/setup_elixir_ls.sh",
  }
end

return M