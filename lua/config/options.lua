local opt = vim.opt
local M = {}

-- Use the hand-rolled explorer instead of Neovim's bundled netrw browser.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Notification UI defaults
M.ui = {
  notification = {
    scale = 0.85, -- Compact notification sizing; 1.0 is the normal size.
    statusbar = {
      scale = 0.85, -- Compact statusbar spacing; 1.0 shows all metadata.
    },
    timeout = 5000, -- default timeout for notifications in milliseconds
    max_width = 100, -- maximum width of notification in columns
    gap = 2, -- gap between notifications in lines
  },
  explorer = {
    min_width = 12, -- close the explorer when it is resized to this width or narrower
    resize_delay = 1000, -- wait this many milliseconds after resizing before closing
  },
}

-- Erlang host config
M.erlang = {
  scripts_dir = vim.fn.stdpath("config") .. "/erlang",
}

M.elixir = {
  scripts_dir = vim.fn.stdpath("config") .. "/elixir"
}

-- Filetypes that are allowed to start each language server.
M.lsp = {
  filetypes = {
    elixirls = { "elixir", "eelixir", "heex", "surface" },
    elp = { "erlang" },
  },
}

-- Disable welcome screen
vim.opt.shortmess:append("I")

-- Enable 24-bit color support in the terminal
opt.termguicolors = true

-- Enable mouse interaction so vertical split separators can be dragged to resize.
opt.mouse = "a"
-- Use smaller wheel increments and smooth scrolling for wrapped lines.
opt.mousescroll = "ver:1,hor:1"
opt.smoothscroll = true

-- Show the current line number
opt.number = true
-- Mark the preferred maximum line length.
opt.colorcolumn = "120"

-- Insert spaces when you press Tab
opt.expandtab = true
-- Use two spaces for each indentation level
opt.shiftwidth = 2
-- Display a Tab character as two spaces wide
opt.tabstop = 2
-- Show guides in leading indentation without marking other whitespace.
opt.list = true
opt.listchars = {
  leadmultispace = "│ ",
  eol = " ",
  tab = "  ",
  trail = " ",
  nbsp = " ",
  extends = " ",
  precedes = " ",
}
-- Automatically indent new lines in common cases
opt.smartindent = true

-- Ignore case when searching
opt.ignorecase = true
-- Make searches case-sensitive if they contain capitals
opt.smartcase = true

-- Keep undo history after closing a file
opt.undofile = true

-- Open horizontal splits below the current window
opt.splitbelow = true
 -- Open vertical splits to the right
opt.splitright = true
-- Keep at least four screen lines above and below the cursor
opt.scrolloff = 4

-- Sync with system clipboard
opt.clipboard = "unnamedplus"

opt.fillchars = {
  eob = " ", -- Replace empty line indicator
}

return M
