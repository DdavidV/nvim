-- Toggle the hand-rolled file explorer.
vim.keymap.set("n", "<C-b>", function()
  require("ui.explorer").toggle()
end, { desc = "Toggle file explorer" })

-- Move between the explorer and the editor without relying on window order.
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Focus file explorer" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Focus editor" })