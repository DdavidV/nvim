local map = vim.keymap.set

-- Toggle the hand-rolled file explorer.
map("n", "<C-b>", function()
  require("ui.explorer").toggle()
end, { desc = "Toggle file explorer" })

-- Move between the explorer and the editor without relying on window order.
map("n", "<C-h>", "<C-w>h", { desc = "Focus file explorer" })
map("n", "<C-l>", "<C-w>l", { desc = "Focus editor" })

-- Move between the open editor buffers shown in the custom winbar.
map("n", "<A-Left>", function()
  require("ui.tabs").move(-1)
end, { desc = "Previous editor tab" })
map("n", "<A-Right>", function()
  require("ui.tabs").move(1)
end, { desc = "Next editor tab" })

-- Close the current editor tab.
map("n", "<A-w>", function()
  require("ui.tabs").close_current()
end, { desc = "Close editor tab" })
local function close_all_editor_tabs()
  require("ui.tabs").close_all()
end

-- Support the VS Code-style chord (release Ctrl after K) with either W case.
map("n", "<C-k>w", close_all_editor_tabs, { desc = "Close all editor tabs" })
map("n", "<C-k>W", close_all_editor_tabs, { desc = "Close all editor tabs" })
map("n", "<C-k><C-w>", close_all_editor_tabs, { desc = "Close all editor tabs" })

-- Move the current tab between editor splits or duplicate it into another split.
map("n", "<A-S-Left>", function()
  require("ui.tabs").move_to_other_window(-1)
end, { desc = "Move tab to left split" })
map("n", "<A-S-Right>", function()
  require("ui.tabs").move_to_other_window(1)
end, { desc = "Move tab to right split" })
map("n", "<A-o>", function()
  require("ui.tabs").open_in_other_window(1)
end, { desc = "Open file in another split" })