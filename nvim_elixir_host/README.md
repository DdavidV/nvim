# NvimHost

An Elixir host for Neovim that provides an Elixir-friendly API for interacting with Neovim through RPC.
It uses [`nvim_rpc`](../nvim_erlang_rpc) for the underlying Erlang RPC implementation and generated Neovim API bindings.

## Features

- **Elixir API** call Neovim API functions through `Nvim.api/3`.
- **Generated API wrappers** generate Elixir wrappers from the exports provided by `nvim_rpc`.
- **Compile-time integration** a custom Mix compiler task prepares the Neovim API bindings during compilation.
- **RPC integration** delegate communication, request IDs, and response handling to `nvim_rpc`.

## Compilation

The application includes a custom Mix compiler task for preparing the Neovim API bindings.
The compiler ensures that the `nvim_rpc` application is available and invokes its API-binding
generator before the remaining compilation steps complete.

The compiler calls:

```elixir
Application.ensure_all_started(:nvim_rpc)
{:ok, :nvim_api} = :nvim_rpc.ensure_api_bindings()
```

This generates the Erlang module containing wrappers for Neovim's API functions.
The application can then use those exports to generate its Elixir-facing API wrappers.

To compile the project, run:

```bash
mix compile
```

Ensure the `nvim_rpc` dependency is available and compiled before the API bindings are generated.

## Usage

Call Neovim API functions through the `Nvim` module:

```elixir
Nvim.api(:nvim_get_current_buf, [])
```

The third argument optionally specifies a timeout in milliseconds:

```elixir
Nvim.api(:nvim_get_current_buf, [], 5000)
```

If generated convenience wrappers are available, you can call them through `Nvim.API` instead:

```elixir
Nvim.API.nvim_get_current_buf()
```
