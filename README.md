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
- **Erlang/OTP** and **Rebar3** required for the Erlang extension host.

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
├── erlang/                  # Erlang extension modules loaded by the host
└── lua/
    ├── config/       # Options, keymaps, theme, and lazy.nvim bootstrap
    ├── event/        # Event and notification handling
    ├── plugins/      # Plugin specifications
    ├── ui/           # Hand-rolled explorer, tabs, statusline, and other UI
    └── utils/        # Shared helpers
```

`init.lua` loads the configuration modules. Plugin versions are recorded in
`lazy-lock.json`.

## Erlang extensions

On startup, `lua/config/beam.lua` builds the Erlang host with `rebar3 compile`
if it has not been built yet, compiles modules in `erlang/`, and launches the configured `nvim_host`
application as a Neovim RPC job.
The application loads each compiled module and invokes its `run/0` function if it exports one
helper modules without `run/0` are just loaded.
The host logs its successful startup as an info notification.
Create or edit a script while Neovim is running, then run `:BeamReload` to rebuild the host and
scripts and restart the application.

