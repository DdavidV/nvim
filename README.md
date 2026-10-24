# Neovim configuration

A Lua-based Neovim configuration focused on a hand-rolled custom UI and built-in Neovim functionality.
Plugins are kept to a minimum and are used only where they provide useful functionality that would
otherwise be costly to recreate.

## Requirements

- **Neovim 0.12.6** the version this configuration currently runs on.
- **Nerd Font** required to display file and folder icons. JetBrainsMono Nerd Font Mono is one option.
- **ripgrep (`rg`)** required by Telescope's `live_grep`.
- **Erlang/OTP** required by the Erlang and Elixir runtimes.
- **Rebar3** required to build the Erlang RPC library and host.
- **Elixir** required to build and run the Elixir extension host.
- **Mix** included with Elixir and used to manage the Elixir host application.

## Plugins

Plugin usage is kept minimal and managed with `lazy.nvim`.

- **lazy.nvim** installs and manages configured plugins.
- **Telescope** fuzzy finding and search, including file previews.
- **mini.icons** provides file and folder icons for the custom explorer.
- **plenary.nvim** a dependency required by Telescope.

## Project Structure

```text
.
├── init.lua
├── lazy-lock.json
├── nvim_erlang_rpc/          # Erlang/OTP MessagePack-RPC library (Rebar3)
├── nvim_erlang_host/         # Erlang/OTP extension host application
├── nvim_elixir_host/         # Elixir extension host application (Mix)
├── erlang/                   # User Erlang extensions
├── elixir/                   # User Elixir extensions
└── lua/
    ├── config/               # Options, keymaps, theme, and plugin setup
    │   ├── erlang.lua        # Builds and manages the Erlang host
    │   └── elixir.lua        # Builds and manages the Elixir host
    ├── event/                # Event and notification handling
    ├── plugins/              # Plugin specifications
    ├── ui/                   # Custom explorer, tabs, statusline, and other UI
    └── utils/                # Shared helpers
```

`init.lua` loads the configuration modules. Plugin versions are recorded in `lazy-lock.json`.

The Erlang and Elixir hosts run as separate Neovim RPC jobs.
Their compiled extension modules are stored in each scripts directory's `ebin/` subdirectory.

## Extension Hosts

The configuration provides two BEAM-powered extension hosts:

- **Erlang host** runs Erlang extensions using the Erlang/OTP runtime.
- **Elixir host** runs Elixir extensions using the Elixir runtime on the BEAM.

Both hosts allow extensions to interact with Neovim through MessagePack-RPC.
Extensions can register user commands, invoke Neovim API functions, and start background processes under supervision.

### Extension lifecycle

Extensions can participate in the host lifecycle through two optional conventions:

- **`run/0`** invoked when an extension module is loaded, if the function is exported.
Use it to register commands, configure integrations, or perform one-time initialization.
- **`start_link/0`** used to start a supervised process when the extension exports it and does not
provide its own child specifications.

Extensions may instead export **`child_specs/0`** to provide one or more custom supervisor child specifications.
When this function is available, the host uses its returned specifications to determine which processes to start.

A helper module that exports none of these functions can still be loaded and used by other code,
provided it is compiled and available on the runtime's code path.

The `run/0` callback is for initialization, `start_link/0` is for starting a process.
Use supervision for long-running workers, stateful services, and background tasks.

## Erlang Extensions

The Erlang host is built with Rebar3 and exposes a Neovim-facing RPC API.

On startup, `lua/config/erlang.lua`:

1. Builds the Erlang host with `rebar3 compile` when required or when a rebuild is requested.
2. Compiles Erlang extension modules from the configured scripts directory.
3. Starts the `nvim_host` application as a Neovim RPC job.
4. Loads the compiled extension modules.
5. Invokes `run/0` when exported and starts any declared supervised children.
6. Reports host startup and runtime logs through Neovim notifications.

After creating or editing an Erlang extension, rebuild and restart the host with:

```vim
:ErlangReload
```

### Writing an Erlang Extension

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
        ]),
    _ = nvim:api(nvim_notify, Args),
    ok.
```

Run `:ErlangReload`, then execute the command in Neovim:

```vim
:ErlangHello
```

This example registers a Neovim user command from Erlang and uses the RPC wrapper to display a notification.

### Evaluating Erlang Expressions

An `erlang_eval` extension can provide an Erlang equivalent of Neovim's built-in `:lua` command.

For example:

```vim
:Erlang lists:reverse([1, 2, 3])
:Erlang erlang:system_info(otp_release)
:Erlang nvim:api(nvim_get_current_buf, [])
```

Expressions execute inside the running BEAM environment.
They can call Neovim APIs, modify buffers, create windows, register commands, and perform other side effects.

## Elixir Extensions

The Elixir host provides the same general integration model using Elixir modules and the Elixir runtime.

On startup, `lua/config/elixir.lua`:

1. Compiles Elixir extension source files from the configured scripts directory into `ebin/`.
2. Starts the Elixir host application using Mix and the Elixir runtime.
3. Loads the compiled extension modules.
4. Invokes `run/0` when exported.
5. Collects child specifications and starts supervised extension processes.
6. Reports errors and runtime logs through the host's logging mechanism.

### Writing an Elixir Extension

Create a module under `elixir/`. For example, `elixir/hello.ex`:

```elixir
defmodule Hello do
  @moduledoc false

  def run do
    options = %{
      "desc" => "Show a notification from Elixir",
      "force" => true
    }

    Nvim.create_user_command("ElixirHello", &hello/1, options)
  end

  def hello(_command_options) do
    Nvim.api(:nvim_notify, [
      "Hello from Elixir!",
      2,
      %{"title" => "Elixir extension"}
    ])

    :ok
  end
end
```

The `run/0` callback registers the `:ElixirHello` command when the module is loaded.
The command handler then calls the Neovim notification API through the Elixir RPC wrapper.

Use the Elixir host's reload command after editing scripts, if configured, or restart the host to compile and load the changes.

### Starting a Supervised Elixir Process

An extension can implement `start_link/0` when it needs to maintain state or run in the background:

```elixir
defmodule MyWorker do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end
end
```

The host can start this worker under its supervisor when the module is discovered and its child specification is collected.

For more control, an extension can export `child_specs/0` and return custom child specifications
instead of relying on the host's default worker specification.

## Calling the BEAM from Lua

Both Erlang and Elixir hosts can expose functionality to Lua through Neovim's MessagePack-RPC interface.
This allows editor features and business logic to be implemented in either language while keeping keymaps,
UI, and configuration in Lua.

The Lua-facing APIs are exposed through `lua/config/erlang.lua` for Erlang and `lua/config/elixir.lua` for Elixir.

### Erlang

#### Direct Function Calls

```lua
local beam = require("config.beam")

local result = beam.call("lists", "reverse", {
  { 1, 2, 3 },
})

vim.notify(vim.inspect(result), vim.log.levels.INFO, {
  title = "ERLANG",
})
```

#### Module-Style Calls

A module proxy provides a more convenient syntax:

```lua
local beam = require("config.beam")
local lists = beam.module("lists")

local result = lists.reverse({ 1, 2, 3 })

vim.notify(vim.inspect(result), vim.log.levels.INFO, {
  title = "ERLANG",
})
```

### Elixir

#### Direct Function Calls

The Elixir host can expose functions from Elixir modules through its Lua-facing API:

```lua
local elixir = require("config.elixir")

local result = elixir.call("Enum", "reverse", {
  { 1, 2, 3 },
})

vim.notify(vim.inspect(result), vim.log.levels.INFO, {
  title = "ELIXIR",
})
```

#### Module-Style Calls

If the Elixir API provides a module proxy, calls can use a similar syntax:

```lua
local elixir = require("config.elixir")
local enum = elixir.module("Enum")

local result = enum.reverse({ 1, 2, 3 })

vim.notify(vim.inspect(result), vim.log.levels.INFO, {
  title = "ELIXIR",
})
```
