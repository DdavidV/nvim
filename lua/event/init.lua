local M = {}

function M.setup(ui_options)
  ui_options = ui_options or {}
  require("ui.notification").setup(ui_options.notification)
  require("event.notify").setup()
  require("event.lsp_notifications").setup({
    statusbar_scale = ui_options.notification
      and ui_options.notification.statusbar
      and ui_options.notification.statusbar.scale,
  })
end

return M