#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
rebar3 compile

NVIM_EXECUTABLE="${1:-nvim}" erl -noshell \
  -pa _build/default/lib/nvim_rpc/ebin \
  -eval '
    case nvim_rpc:ensure_api_bindings(os:getenv("NVIM_EXECUTABLE")) of
      {ok, Module} ->
        io:format("Generated/loaded ~p for Neovim ~p (~s)~n",
          [Module, Module:api_version(), Module:api_hash()]),
        halt(0);
      {error, Reason} ->
        io:format(standard_error, "API binding generation failed: ~p~n", [Reason]),
        halt(1)
    end.'
