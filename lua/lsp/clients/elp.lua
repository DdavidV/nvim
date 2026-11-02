local M = {}

local default_filetypes = { "erlang" }

-- Register ELP and describe how the generic loader checks and installs it.
function M.setup(options)
  options = options or {}
  local command = { vim.fn.stdpath("data") .. "/servers/elp/elp", "server" }

  vim.lsp.config("elp", {
    cmd = command,
    filetypes = options.filetypes or default_filetypes,
    root_markers = { { "rebar.config", "erlang.mk" }, ".git" },
  })

  return {
    name = "elp",
    command = command,
    setup_script = "scripts/setup_elp.sh",
  }
end

return M