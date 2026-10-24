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

- **lazy.nvim** installs and manages the configured plugins.
- **Telescope** fuzzy finding and search, with file previews.
- **mini.icons** provides file and folder icons for the custom explorer.
- **plenary.nvim** a dependency required by Telescope.

## Project structure

```text
.
├── init.lua
├── lazy-lock.json
├── nvim_erlang_rpc/         # Erlang/OTP MessagePack-RPC library (Rebar3)
├── nvim_erlang_host/        # Erlang/OTP extension host app (Rebar3, depends on nvim_rpc)
├── erlang/                  # Erlang extension modules loaded by the host
└── lua/
    ├── config/              # Options, keymaps, theme, and lazy.nvim bootstrap
    │   └── beam.lua         # Builds, starts, and manages the BEAM host
    ├── event/               # Event and notification handling
    ├── plugins/             # Plugin specifications
    ├── ui/                  # Hand-rolled explorer, tabs, statusline, and other UI
    └── utils/               # Shared helpers
```

`init.lua` loads the configuration modules. Plugin versions are recorded in `lazy-lock.json`.

## Erlang extensions

The configuration includes a BEAM-powered extension host that allows custom Erlang modules to
interact with Neovim through MessagePack-RPC.

On startup, `lua/config/beam.lua`:

1. Builds the Erlang host with `rebar3 compile` if the required BEAM files are missing or a rebuild is requested.
2. Compiles Erlang modules configured by `scripts_dir`.
3. Starts the `nvim_host` application as a Neovim RPC job.
4. Allows the host to load compiled modules and invoke their `run/0` function when they export one.
   Helper modules without `run/0` are loaded without being invoked.
5. Reports host startup and runtime logs through Neovim notifications.

To rebuild the host and scripts and restart the application after creating or editing an Erlang script, run:

```vim
:BeamReload
```

### Writing an Erlang extension

Create a module under `erlang/`. For example, `erlang/hello.erl`:

```erlang
-module(hello).

-export([run/0]).

run() ->
    Options = #{
        ~"desc" => ~"Show a notification from Erlang",
        ~"force" => true
    },
    NvimOptions = nvim_rpc:term_to_rpc(Options),
    nvim:create_user_command(~"ErlangHello", fun hello/1, NvimOptions).

hello(_CommandOptions) ->
    Args =
        nvim_rpc:term_to_rpc([
            ~"Hello from Erlang!",
            2,
            #{~"title" => ~"Erlang extension"}
        ])
    _ = nvim:api(nvim_notify, Args),
    ok.
```

Run `:BeamReload`, then execute the command inside Neovim:

```vim
:ErlangHello
```

This demonstrates that Erlang code can register Neovim commands and call Neovim APIs through the RPC wrapper.

### Evaluating Erlang expressions

An `erlang_eval` extension can provide an Erlang equivalent of Neovim's built-in `:lua` command.

For example:

```vim
:Erlang lists:reverse([1, 2, 3])
:Erlang erlang:system_info(otp_release)
:Erlang nvim:api(nvim_get_current_buf, [])
```

Because evaluation executes Erlang code in the running BEAM environment, it can perform side effects,
including calling Neovim APIs, modifying buffers, creating windows, and registering commands.

## Calling Erlang from Lua

The BEAM host can also serve as a runtime for functionality invoked directly from Lua.
This makes it possible to implement editor features in Erlang while keeping keymaps, UI, and configuration in Lua.

The intended Lua-facing API is exposed through `lua/config/beam.lua`.

### Direct function calls

```lua
local beam = require("config.beam")

local result = beam.call("lists", "reverse", {
    { 1, 2, 3 },
})

vim.notify(vim.inspect(result), vim.log.levels.INFO, { title = "ERLANG" })
```

### Module-style calls

A module proxy provides a more convenient syntax:

```lua
local beam = require("config.beam")
local lists = beam.module("lists")

local result = lists.reverse({ 1, 2, 3 })

vim.notify(vim.inspect(result), vim.log.levels.INFO, { title = "ERLANG" })
```
