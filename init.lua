local options = require("config.options")
require("config.lazy")
-- require("config.beam").setup(options.beam)
require("config.elixir").setup(options.elixir)

require("config.keymaps")

require("config.theme").apply()

require("event.notify").setup()
require("ui.notification").setup(options.ui.notification)
require("ui.cmdline").setup()
require("ui.statusline").setup()
require("ui.explorer").setup(options.ui.explorer)
require("ui.tabs").setup()
