-module(nvim_rpc_message_tests).

-include_lib("eunit/include/eunit.hrl").

rpc_request_golden_test() ->
    Expected = <<16#94, 0, 42, 16#a4, "ping", 16#90>>,
    ?assertEqual({ok, Expected}, nvim_rpc:encode_rpc({request, 42, <<"ping">>, []})),
    ?assertEqual({ok, {request, 42, <<"ping">>, []}, <<>>}, nvim_rpc:decode_rpc(Expected)).

rpc_message_roundtrip_test() ->
    Messages = [
        {request, 9, <<"nvim_get_current_buf">>, []},
        {request, -1, <<"nvim_get_current_buf">>, []},
        {request, 10, {string, <<"method">>}, [1]},
        {request, 11, method_atom, []},
        {notification, <<"nvim_buf_changed">>, [4]},
        {response, 9, nil, {ext, 0, <<0, 0, 0, 4>>}}
    ],
    lists:foreach(
        fun(Message) ->
            {ok, Encoded} = nvim_rpc:encode_rpc(Message),
            ?assertEqual({ok, normalize_method(Message), <<>>}, nvim_rpc:decode_rpc(Encoded))
        end,
        Messages
    ).

invalid_rpc_message_test() ->
    InvalidMessages = [
        invalid,
        {request, not_integer, <<"method">>, []},
        {request, 1, <<"method">>, not_a_list},
        {notification, <<"method">>, not_a_list},
        {response, not_integer, nil, nil}
    ],
    lists:foreach(
        fun(Message) ->
            ?assertEqual({error, invalid_rpc_message}, nvim_rpc:encode_rpc(Message))
        end,
        InvalidMessages
    ),
    ?assertEqual(
        {error, invalid_method},
        nvim_rpc:encode_rpc({request, 1, {string, not_binary}, []})
    ),
    ?assertEqual({error, invalid_rpc_message}, nvim_rpc:decode_rpc(encoded([3]))),
    ?assertEqual({error, invalid_rpc_message}, nvim_rpc:decode_rpc(encoded([0, 1]))),
    ?assertEqual({error, invalid_rpc_message}, nvim_rpc:decode_rpc(encoded([0, 1, 2, []]))),
    ?assertEqual({error, invalid_rpc_message}, nvim_rpc:decode_rpc(encoded([0, 1, <<"m">>, []]))),
    ?assertEqual(
        {error, invalid_rpc_message}, nvim_rpc:decode_rpc(encoded([1, <<"id">>, nil, nil]))
    ),
    ?assertEqual({error, invalid_rpc_message}, nvim_rpc:decode_rpc(encoded([2, <<"m">>, 42]))),
    ?assertEqual({error, incomplete}, nvim_rpc:decode_rpc(<<>>)).

normalize_method({request, Id, {string, Method}, Params}) ->
    {request, Id, Method, Params};
normalize_method({request, Id, Method, Params}) when is_atom(Method) ->
    {request, Id, atom_to_binary(Method), Params};
normalize_method(Message) ->
    Message.

encoded(Term) ->
    {ok, Binary} = nvim_rpc:encode(Term),
    Binary.
