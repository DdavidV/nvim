nvim_rpc
=====

An Erlang/OTP library for integrating BEAM code with Neovim over MessagePack-RPC.

The package implements MessagePack value encoding/decoding and Neovim's MessagePack-RPC request,
response, and notification envelopes.
Decoded strings are represented as `{string, Binary}`, MessagePack binary values remain `binary()`.
Use `{ext, Type, Payload}` for extension values such as Neovim handles.
`decode/1` returns the decoded value and any unconsumed bytes, or `{error, incomplete}` when
it needs more input.

## API bindings

Bindings are generated from the output of `nvim --api-info`.
Generated source and BEAM files are stored in this Neovim configuration's `nvim_rpc/.nvim_api/api/`
directory, keyed by a SHA-256 hash of the generator version and that Neovim's API metadata.

Generate or warm the cache from this directory:
```sh
scripts/generate_api [path/to/nvim]
```

In a BEAM process, call `nvim_rpc:ensure_api_bindings/0,1` before starting the extension host.
It checks the selected Neovim's API metadata, loads the matching cached module when available,
and generates it on a cache miss.
Generated `nvim_api` functions take the RPC request ID followed by the API parameters and
return `{ok, EncodedMessagePack}`. For example:
```erlang
{ok, nvim_api} = nvim_rpc:ensure_api_bindings(),
{ok, Packet} = nvim_api:nvim_get_current_buf(1).
```

For Neovim API string arguments, pass `{string, Binary}`, plain Erlang binaries encode as
MessagePack binary values.
The generated module also exposes `type_id/1` and `type_name/1` for the Neovim handle type IDs
advertised by the selected API version.
Handle payloads remain opaque `{ext, TypeId, Payload}` values in the generic codec.

Build
-----

Run these commands from this directory:
```sh
rebar3 compile
rebar3 eunit
```
