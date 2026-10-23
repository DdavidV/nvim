# Neovim configuration

A Lua-based Neovim configuration focused on a hand-rolled custom UI and
built-in Neovim functionality. Plugins are kept to a minimum and are used only
where they provide useful functionality that would otherwise be costly to
recreate.

## Requirements

- **Neovim 0.12.6**  the version this configuration currently runs on.
- **Nerd Font** required to display file and folder icons. JetBrainsMono Nerd
  Font Mono is one option.
- **ripgrep** (`rg`) required by Telescope's `live_grep`.

## Plugins

Plugin usage is kept minimal and managed with lazy.nvim:

- **lazy.nvim** — installs and manages the configured plugins.
- **Telescope** — fuzzy finding and search, with file previews. 
- **mini.icons** — provides file and folder icons for the custom explorer.
- **plenary.nvim** — a dependency required by Telescope.

## Project structure

```text
.
├── init.lua
├── lazy-lock.json
├── nvim_erlang_rpc/         # Erlang/OTP MessagePack-RPC library (Rebar3)
├── nvim_erlang_host/        # Erlang/OTP extension host app (Rebar3, depends on nvim_rpc)
└── lua/
    ├── config/       # Options, keymaps, theme, and lazy.nvim bootstrap
    ├── event/        # Event and notification handling
    ├── plugins/      # Plugin specifications
    ├── ui/           # Hand-rolled explorer, tabs, statusline, and other UI
    └── utils/        # Shared helpers
```

`init.lua` loads the configuration modules. Plugin versions are recorded in
`lazy-lock.json`.
