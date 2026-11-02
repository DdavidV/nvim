local options = require("config.options")
require("config.lazy")
-- require("config.erlang").setup(options.erlang)
-- require("config.elixir").setup(options.elixir)

require("config.keymaps")

require("config.theme").apply()

require("event").setup(options.ui)
require("ui.cmdline").setup()
require("ui.statusline").setup()
require("ui.explorer").setup(options.ui.explorer)
require("ui.tabs").setup()
require("lsp").setup(options.lsp)
