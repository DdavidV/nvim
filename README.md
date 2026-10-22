# Neovim configuration

A Lua-based Neovim configuration focused on a hand-rolled custom UI and
built-in Neovim functionality. Plugins are kept to a minimum and are used only
where they provide useful functionality that would otherwise be costly to
recreate.

## Principles

- **Hand-rolled UI:** The file explorer, editor tabs, statusline, command line,
  notifications, and theme are implemented in this config using Neovim's APIs.
- **Nerd Font icons:** Use a Nerd Font in your terminal for the file and folder
  icons to display correctly. JetBrainsMono Nerd Font Mono is a good option.

## Plugins

Plugin usage is kept minimal and managed with lazy.nvim:

- **lazy.nvim** — installs and manages the configured plugins.
- **Telescope** — fuzzy finding and search, with file previews. `<leader>ff`
  finds files, `<leader>fg` searches file contents, `<leader>fb` finds open
  buffers, and `<leader>fh` searches help tags.
- **mini.icons** — provides file and folder icons for the custom explorer.
- **plenary.nvim** — a dependency required by Telescope.

## Project structure

```text
.
├── init.lua
├── lazy-lock.json
└── lua/
    ├── config/       # Options, keymaps, theme, and lazy.nvim bootstrap
    ├── event/        # Event and notification handling
    ├── plugins/      # Plugin specifications
    ├── ui/           # Hand-rolled explorer, tabs, statusline, and other UI
    └── utils/        # Shared helpers
```

`init.lua` loads the configuration modules. Plugin versions are recorded in
`lazy-lock.json`.
