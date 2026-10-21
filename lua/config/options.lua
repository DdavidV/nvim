local opt = vim.opt
local M = {}

-- Notification UI defaults
M.ui = {
  notification = {
    timeout = 5000, -- default timeout for notifications in milliseconds
    max_width = 100, -- maximum width of notification in columns
    gap = 2, -- gap between notifications in lines
  },
}

-- Disable welcome screen
vim.opt.shortmess:append("I")

-- Enable 24-bit color support in the terminal
opt.termguicolors = true

-- Show the current line number
opt.number = true

-- Insert spaces when you press Tab
opt.expandtab = true
-- Use two spaces for each indentation level
opt.shiftwidth = 2
-- Display a Tab character as two spaces wide
opt.tabstop = 2
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
