nvim_host
=========

An Erlang/OTP application that connects Erlang extensions to Neovim over MessagePack-RPC.
It depends on the `nvim_rpc` application for the codec and runtime-generated Neovim API metadata.

## Transports

The default transport is stdio, intended for a Neovim-launched RPC job. RPC bytes use stdin and stdout.

To use a Unix-domain socket instead, configure the application before starting it:

```erlang
application:set_env(nvim_host, transport, {unix, "/tmp/nvim-erlang-host.sock"}).
```

The host listens on that path and accepts a Neovim RPC client connection.
The socket directory is created if needed. The host does not remove an existing socket path when
startup fails.

Both transports support requests and notifications in both directions. A disconnected Unix-socket
client may reconnect to the still-running host.

## Start and use

The host generates or loads the bindings for the selected Neovim executable before starting
its transport. By default, it resolves `nvim` from `PATH`.
Override the executable with application configuration:

```erlang
application:set_env(nvim_host, nvim_executable, "/path/to/nvim").
application:ensure_all_started(nvim_host).
```

Send a request to Neovim; calls default to a five-second timeout:

```erlang
{ok, CurrentBuffer} = nvim:call(<<"nvim_get_current_buf">>, []).
```

`nvim:call` waits for Neovim's RPC response. `nvim:cast/2` instead enqueues an asynchronous,
one-way notification and returns without waiting for a send result or Neovim response.
Local notification send failures are logged.

Use `nvim:api/2,3` to call a function from the generated `nvim_api` bindings.
It checks that the function is exported at the arity required for the supplied parameters,
then uses that binding to encode the request:

```erlang
{ok, CurrentWindow} = nvim:api(nvim_get_current_win, []).
{ok, Width} = nvim:api(window_get_width, [CurrentWindow]).
```

An unavailable function returns `{error, {api_not_available, Function, Arity}}` without sending an
RPC request. Use `nvim:call` for generic or custom RPC methods that are not present in the
generated bindings.

Register an Erlang handler for a request or notification received from Neovim:

```erlang
ok = nvim:register_handler(<<"my_extension_ping">>, fun([Value]) ->
    {ok, Value}
end).
```

Handlers receive the RPC parameter list. A request handler may return
`{ok, Result}` or `{error, RpcError}`; any other return value is treated as a successful result.
Notification handler results are ignored. Handler exceptions are logged and returned to Neovim as
`handler_failed`.

Use `nvim:unregister_handler/1` to remove a handler. `nvim:call/3` accepts an explicit positive
timeout in milliseconds.

## Build and test

Run from this directory:

```sh
rebar3 compile
rebar3 eunit
rebar3 lint
```
