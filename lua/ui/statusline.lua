local M = {}
local git = require("utils.git")

-- Git invokes this after the asynchronous lookup; the UI owns the redraw.
local function redraw_statusline()
  vim.cmd("redrawstatus")
end

-- Neovim reports short mode codes; map them to labels suitable for the statusline.
local mode_names = {
  n = "NORMAL",
  no = "OP",
  nov = "OP",
  noV = "OP",
  ["no\22"] = "OP",
  niI = "NORMAL",
  niR = "NORMAL",
  niV = "NORMAL",
  nt = "NORMAL",
  v = "VISUAL",
  V = "V-LINE",
  ["\22"] = "V-BLOCK",
  s = "SELECT",
  S = "S-LINE",
  ["\19"] = "S-BLOCK",
  i = "INSERT",
  ic = "INSERT",
  ix = "INSERT",
  R = "REPLACE",
  Rc = "REPLACE",
  Rx = "REPLACE",
  Rv = "V-REPLACE",
  c = "COMMAND",
  cv = "EX",
  ce = "EX",
  r = "PROMPT",
  rm = "MORE",
  ["r?"] = "CONFIRM",
  ["!"] = "SHELL",
  t = "TERMINAL",
}

-- Keep mode colors separate from labels so related modes can share a highlight.
local mode_highlights = {
  NORMAL = "StatusLineModeNormal",
  OP = "StatusLineModeNormal",
  VISUAL = "StatusLineModeVisual",
  ["V-LINE"] = "StatusLineModeVisual",
  ["V-BLOCK"] = "StatusLineModeVisual",
  SELECT = "StatusLineModeVisual",
  ["S-LINE"] = "StatusLineModeVisual",
  ["S-BLOCK"] = "StatusLineModeVisual",
  INSERT = "StatusLineModeInsert",
  REPLACE = "StatusLineModeReplace",
  ["V-REPLACE"] = "StatusLineModeReplace",
  COMMAND = "StatusLineModeCommand",
  EX = "StatusLineModeCommand",
  PROMPT = "StatusLineModeCommand",
  MORE = "StatusLineModeCommand",
  CONFIRM = "StatusLineModeCommand",
  SHELL = "StatusLineModeCommand",
  TERMINAL = "StatusLineModeInsert",
}

-- Escape statusline syntax so filenames and Git branch names are shown literally.
local function statusline_escape(value)
  return tostring(value):gsub("%%", "%%%%"):gsub("[\r\n]", " ")
end

local function current_window()
  -- Neovim sets statusline_winid while evaluating a statusline for a window.
  local winid = tonumber(vim.g.statusline_winid)
  if winid and vim.api.nvim_win_is_valid(winid) then
    return winid
  end
  return vim.api.nvim_get_current_win()
end

local function progress_label(line, line_count)
  if line_count <= 1 or line == 1 then
    return "Top"
  elseif line >= line_count then
    return "Bot"
  end

  -- Normalize interior lines to a percentage between the first and last lines.
  return string.format("%d%%", math.floor((line - 1) * 100 / (line_count - 1)))
end

function M.render()
  local winid = current_window()
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local mode = vim.api.nvim_get_mode().mode
  local mode_name = mode_names[mode] or mode_names[mode:sub(1, 1)] or "NORMAL"
  local cursor = vim.api.nvim_win_get_cursor(winid)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  -- The cursor API uses zero-based positions; the statusline displays 1-based ones.
  local line = cursor[1] + 1
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local file_name = filename == "" and "[No Name]" or vim.fs.basename(filename)
  local modified = vim.bo[bufnr].modified and " [+]" or ""
  local readonly = vim.bo[bufnr].readonly and " [RO]" or ""
  local fileencoding = vim.bo[bufnr].fileencoding
  local encoding = fileencoding ~= "" and fileencoding or vim.o.encoding
  local filetype = vim.bo[bufnr].filetype
  local branch = git.branch(bufnr, redraw_statusline)

  -- Statusline format codes select highlights; %= pushes following items to the right.
  local left = {
    "%#" .. (mode_highlights[mode_name] or "StatusLineModeNormal") .. "# " .. mode_name .. " ",
  }

  if branch then
    left[#left + 1] = "%#StatusLineBranch#  " .. statusline_escape(branch) .. " "
  end

  left[#left + 1] = "%#StatusLineFile# " .. statusline_escape(file_name .. modified .. readonly) .. " "

  local right = {
    "%#StatusLineMeta# " .. statusline_escape(encoding) .. " ",
    "%#StatusLineMeta# " .. statusline_escape(vim.bo[bufnr].fileformat) .. " ",
  }

  if filetype ~= "" then
    right[#right + 1] = "%#StatusLineMeta# " .. statusline_escape(filetype) .. " "
  end

  right[#right + 1] = "%#StatusLinePosition# " .. progress_label(line, line_count) .. " "
  right[#right + 1] = "%#StatusLinePosition# " .. line .. ":" .. (cursor[2] + 1) .. " "

  return table.concat(left) .. "%=" .. table.concat(right)
end

function M.setup()
  vim.o.laststatus = 2
  vim.o.statusline = "%!v:lua.require'ui.statusline'.render()"

  -- Repository changes can happen while Neovim is open, so refresh cached branches
  -- when switching buffers, renaming files, changing directories, or refocusing.
  local group = vim.api.nvim_create_augroup("HandRolledStatusline", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufFilePost", "DirChanged", "FocusGained" }, {
    group = group,
    callback = function()
      git.clear_cache()
    end,
  })
end

return M
