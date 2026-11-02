local M = {}

-- Keep UI startup and its option routing in one place.
function M.setup(options)
  options = options or {}
  require("ui.cmdline").setup()
  require("ui.statusline").setup()
  require("ui.explorer").setup(options.explorer)
  require("ui.tabs").setup()
end

return M