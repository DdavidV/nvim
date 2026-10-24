nvim_host
=========

An Erlang/OTP application that connects Erlang extensions to Neovim over MessagePack-RPC.
It depends on the `nvim_rpc` application for the codec and runtime-generated Neovim API metadata.

## Start and use

The host generates or loads the bindings for the selected Neovim executable before starting
its stdio transport.

The Neovim bootstrap sets `nvim_host.scripts_dir` with `application:set_env/2` before starting the host.
At application start, the host loads every `.beam` file from that directory's `ebin/` subdirectory.
The bootstrap compiles `.erl` files from the configured scripts directory before starting the application.

The local Neovim integration uses `rebar3 compile` and launches the Erlang application as a
foreground RPC job, a Rebar3 release is unnecessary for this development workflow.

After all configured extensions start, the host shows a Neovim INFO notification through the generated
`nvim_notify`.

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

Neovim user-command callbacks execute in Neovim's Lua runtime and cannot directly
hold an Erlang function. Use `nvim:create_user_command/3` to bridge them: it
creates the command with a Lua callback that forwards command options to an
Erlang handler over RPC.

```erlang
Options = #{
    {string, <<"desc">>} => {string, <<"Describe the command">>},
    {string, <<"force">>} => true
},
ok = nvim:create_user_command(<<"MyCommand">>, fun(CommandOptions) ->
    logger:info("Command invoked with options: ~p", [CommandOptions]),
    ok
end, Options).
```

Use MessagePack string tuples for option keys and string values, as shown;
the RPC encoder does not automatically convert arbitrary Erlang atoms.

The handler receives Neovim's command options map asynchronously; its return
value is not sent back to the user-command callback.

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
