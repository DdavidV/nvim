local M = {}

-- Edit this palette to change the colors used throughout the configuration.
M.palette = {
  background = "#14161b", -- Main editor background
  surface = "#1b1e26", -- Elevated surfaces such as menus and cursor line
  foreground = "#d8dee9", -- Primary text
  muted = "#778092", -- Secondary text and inactive UI
  border = "#c9ced8", -- Float and separator outlines
  selection = "#303745", -- Selected text and completion items
  accent = "#8bd5ca", -- Emphasis, active line numbers, and titles
  -- Syntax and severity colors
  blue = "#82aaff",
  cyan = "#80d4e8",
  purple = "#c792ea",
  green = "#a6da95",
  yellow = "#eed49f",
  orange = "#f5a97f",
  red = "#ed8796",
  pink = "#f5bde6",
}

local function highlight(name, settings)
  vim.api.nvim_set_hl(0, name, settings)
end

-- Define editor, syntax, diagnostic, and custom UI highlight groups.
function M.apply()
  local p = M.palette
  vim.o.termguicolors = true
  vim.o.background = "dark"

  local groups = {
    -- Editor backgrounds, cursor, and line indicators
    Normal = { fg = p.foreground, bg = p.background },
    NormalNC = { fg = p.foreground, bg = p.background },
    NormalFloat = { fg = p.foreground, bg = p.surface },
    FloatBorder = { fg = p.border, bg = p.background },
    FloatTitle = { fg = p.accent, bg = p.background, bold = true },
    FloatFooter = { fg = p.muted, bg = p.background },
    Cursor = { fg = p.background, bg = p.foreground },
    CursorLine = { bg = p.surface },
    CursorColumn = { bg = p.surface },
    LineNr = { fg = p.muted },
    CursorLineNr = { fg = p.accent, bold = true },
    SignColumn = { fg = p.muted, bg = p.background },
    ColorColumn = { bg = p.surface },
    Visual = { bg = p.selection },

    -- Search matches and matching delimiters
    Search = { fg = p.background, bg = p.yellow },
    IncSearch = { fg = p.background, bg = p.orange },
    Substitute = { fg = p.background, bg = p.red },
    MatchParen = { fg = p.accent, bold = true, underline = true },

    -- Completion menus, statusline, tabs, and window separators
    Pmenu = { fg = p.foreground, bg = p.surface },
    PmenuSel = { fg = p.foreground, bg = p.selection, bold = true },
    PmenuSbar = { bg = p.surface },
    PmenuThumb = { bg = p.muted },
    StatusLine = { fg = p.foreground, bg = p.selection },
    StatusLineNC = { fg = p.muted, bg = p.surface },
    StatusLineModeNormal = { fg = p.background, bg = p.purple, bold = true },
    StatusLineModeInsert = { fg = p.background, bg = p.green, bold = true },
    StatusLineModeVisual = { fg = p.background, bg = p.blue, bold = true },
    StatusLineModeReplace = { fg = p.background, bg = p.red, bold = true },
    StatusLineModeCommand = { fg = p.background, bg = p.yellow, bold = true },
    StatusLineBranch = { fg = p.green, bg = p.surface },
    StatusLineFile = { fg = p.foreground, bg = p.selection, bold = true },
    StatusLineMeta = { fg = p.muted, bg = p.selection },
    StatusLinePosition = { fg = p.foreground, bg = p.selection, bold = true },
    ExplorerRoot = { fg = p.accent, bg = p.surface, bold = true },
    ExplorerDirectory = { fg = p.blue, bg = p.background },
    ExplorerFile = { fg = p.foreground, bg = p.background },
    ExplorerTree = { fg = p.muted, bg = p.background },
    ExplorerIconDirectory = { fg = p.blue, bg = p.background },
    ExplorerIconDirectoryOpen = { fg = p.cyan, bg = p.background },
    ExplorerIconFile = { fg = p.accent, bg = p.background },
    WinSeparator = { fg = p.selection },
    VertSplit = { fg = p.selection },
    TabLine = { fg = p.muted, bg = p.surface },
    TabLineSel = { fg = p.foreground, bg = p.background, bold = true },
    TabLineClose = { fg = p.muted, bg = p.surface },
    TabLineCloseSel = { fg = p.muted, bg = p.background },
    WinBar = { fg = p.muted, bg = p.surface },
    WinBarNC = { fg = p.muted, bg = p.surface },
    Folded = { fg = p.accent, bg = p.surface },
    FoldColumn = { fg = p.muted, bg = p.background },

    -- Whitespace, messages, prompts, and common built-in UI text
    NonText = { fg = p.selection },
    Whitespace = { fg = p.selection },
    EndOfBuffer = { fg = p.background },
    Directory = { fg = p.blue },
    Title = { fg = p.accent, bold = true },
    Question = { fg = p.cyan },
    MoreMsg = { fg = p.green },
    WarningMsg = { fg = p.yellow },
    ErrorMsg = { fg = p.red, bold = true },
    MsgArea = { fg = p.foreground, bg = p.background },
    MatchWord = { bg = p.selection },
    MatchWordCur = { bg = p.selection, bold = true },

    -- Vim syntax highlighting
    Comment = { fg = p.muted, italic = true },
    Constant = { fg = p.orange },
    String = { fg = p.green },
    Character = { fg = p.green },
    Number = { fg = p.orange },
    Boolean = { fg = p.orange },
    Float = { fg = p.orange },
    Identifier = { fg = p.cyan },
    Function = { fg = p.blue },
    Statement = { fg = p.purple },
    Conditional = { fg = p.purple },
    Repeat = { fg = p.purple },
    Label = { fg = p.yellow },
    Operator = { fg = p.cyan },
    Keyword = { fg = p.purple },
    Exception = { fg = p.red },
    PreProc = { fg = p.pink },
    Include = { fg = p.pink },
    Define = { fg = p.pink },
    Macro = { fg = p.pink },
    PreCondit = { fg = p.pink },
    Type = { fg = p.yellow },
    StorageClass = { fg = p.purple },
    Structure = { fg = p.yellow },
    Typedef = { fg = p.yellow },
    Special = { fg = p.cyan },
    SpecialChar = { fg = p.orange },
    Tag = { fg = p.red },
    Delimiter = { fg = p.foreground },
    SpecialComment = { fg = p.muted, italic = true },
    Debug = { fg = p.red },
    Underlined = { fg = p.blue, underline = true },
    Error = { fg = p.red, bold = true },
    Todo = { fg = p.yellow, bold = true },

    -- Diagnostics and their underlines
    DiagnosticError = { fg = p.red },
    DiagnosticWarn = { fg = p.yellow },
    DiagnosticInfo = { fg = p.cyan },
    DiagnosticHint = { fg = p.blue },
    DiagnosticOk = { fg = p.green },
    DiagnosticUnderlineError = { undercurl = true, sp = p.red },
    DiagnosticUnderlineWarn = { undercurl = true, sp = p.yellow },
    DiagnosticUnderlineInfo = { undercurl = true, sp = p.cyan },
    DiagnosticUnderlineHint = { undercurl = true, sp = p.blue },
    DiagnosticUnderlineOk = { undercurl = true, sp = p.green },

    -- Diff views
    DiffAdd = { fg = p.green, bg = p.surface },
    DiffChange = { fg = p.yellow, bg = p.surface },
    DiffDelete = { fg = p.red, bg = p.surface },
    DiffText = { fg = p.blue, bg = p.selection, bold = true },

    -- Custom command-line popup and completion highlights
    ThemeCmdlineFloat = { fg = p.foreground, bg = p.background },
    ThemeCmdlineBorder = { fg = p.border, bg = p.background },
    ThemeCmdlineCursor = { fg = p.background, bg = p.foreground },
    ThemeCompletionSelected = { fg = p.foreground, bg = p.selection, bold = true },

    -- Custom notification body and severity styles
    ThemeNotifyFloat = { fg = p.foreground, bg = p.background },
    ThemeNotifyError = { fg = p.red, bg = p.background, bold = true },
    ThemeNotifyWarn = { fg = p.yellow, bg = p.background, bold = true },
    ThemeNotifyInfo = { fg = p.cyan, bg = p.background, bold = true },
    ThemeNotifyDebug = { fg = p.muted, bg = p.background, bold = true },
  }

  for name, settings in pairs(groups) do
    highlight(name, settings)
  end

  -- Keep Tree-sitter captures consistent with the built-in syntax groups.
  local links = {
    ["@comment"] = "Comment",
    ["@constant"] = "Constant",
    ["@constant.builtin"] = "Special",
    ["@string"] = "String",
    ["@string.escape"] = "SpecialChar",
    ["@character"] = "Character",
    ["@number"] = "Number",
    ["@boolean"] = "Boolean",
    ["@function"] = "Function",
    ["@function.builtin"] = "Special",
    ["@method"] = "Function",
    ["@constructor"] = "Type",
    ["@parameter"] = "Identifier",
    ["@property"] = "Identifier",
    ["@variable"] = "Identifier",
    ["@variable.builtin"] = "Special",
    ["@keyword"] = "Keyword",
    ["@operator"] = "Operator",
    ["@type"] = "Type",
    ["@type.builtin"] = "Type",
    ["@attribute"] = "PreProc",
    ["@tag"] = "Tag",
    ["@punctuation.delimiter"] = "Delimiter",
  }
  for name, target in pairs(links) do
    highlight(name, { link = target })
  end

  vim.g.colors_name = "native"
end

return M
