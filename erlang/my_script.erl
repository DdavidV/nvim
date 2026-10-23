-module(my_script).

-export([run/0]).

run() ->
    Options = #{
        {string, ~"desc"} => {string, ~"Show a notification from Erlang"},
        {string, ~"force"} => true
    },
    nvim:create_user_command(~"ErlangHello", fun hello_callback/1, Options).

hello_callback(_CommandOptions) ->
    maybe
        {ok, TypeId} ?= nvim_api:type_id(~"Buffer"),
        {ok, {ext, TypeId, Buffer}} ?= nvim:api(nvim_get_current_buf),
        Msg = iolist_to_binary(io_lib:format("Hello from Erlang! Current buffer: ~p", [Buffer])),
        Options = #{{string, ~"title"} => {string, ~"Erlang extension"}},
        {ok, nil} ?= nvim:api(nvim_notify, [{string, Msg}, 2, Options]),
        ok
    end.
