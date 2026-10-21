local M = {}

-- Generic Nerd Font placeholders; extend this table with filetype-specific icons later.
local definitions = {
  directory = {
    closed = { glyph = "󰉋", highlight = "ExplorerIconDirectory" },
    open = { glyph = "󰝰", highlight = "ExplorerIconDirectoryOpen" },
  },
  file = {
    default = { glyph = "󰈔", highlight = "ExplorerIconFile" },
  },
}

-- Keep directory lookup separate because it also depends on expansion state.
function M.get_directory(name, expanded)
  return expanded and definitions.directory.open or definitions.directory.closed
end

-- File lookup uses the filename so extension-specific icons can be added here.
function M.get_file(name)
  local extension = name:match("%.([^%.]+)$")
  return definitions.file[extension and extension:lower()] or definitions.file.default
end

return M
