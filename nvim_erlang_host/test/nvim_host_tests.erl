-module(nvim_host_tests).

-include_lib("eunit/include/eunit.hrl").

nvim_host_test_() ->
    {foreach, fun start_host/0, fun stop_host/1, [
        fun(Fixture) -> fun() -> handles_requests_and_notifications(Fixture) end end,
        fun(Fixture) -> fun() -> sends_requests_to_neovim(Fixture) end end,
        fun(Fixture) -> fun() -> returns_timeout_for_unanswered_request(Fixture) end end,
        fun(Fixture) -> fun() -> rejects_unregistered_method(Fixture) end end,
        fun(Fixture) -> fun() -> reports_invalid_handler_results(Fixture) end end,
        fun(Fixture) -> fun() -> accepts_a_reconnecting_client(Fixture) end end,
        fun(Fixture) -> fun() -> drops_responses_from_disconnected_clients(Fixture) end end
    ]}.

generated_api_test_() ->
    case os:find_executable("nvim") of
        false ->
            [];
        Nvim ->
            {foreach,
                fun() ->
                    {ok, nvim_api} = nvim_rpc:ensure_api_bindings(Nvim),
                    start_host()
                end,
                fun stop_host/1, [
                    fun(Fixture) -> fun() -> uses_generated_api_bindings(Fixture) end end
                ]}
    end.

uses_generated_api_bindings({_Server, Socket, _Path}) ->
    ?assertEqual(
        {error, {api_not_available, nvim_missing_method, 1}},
        nvim:api(nvim_missing_method, [])
    ),
    ?assertEqual(
        {error, {api_not_available, nvim_get_current_buf, 2}},
        nvim:api(nvim_get_current_buf, [unexpected_argument])
    ),
    Parent = self(),
    _Caller = spawn(fun() ->
        Parent ! {api_result, nvim:api(nvim_get_current_buf, [], 1000)}
    end),
    {ok, {request, RequestId, <<"nvim_get_current_buf">>, []}, <<>>} = receive_rpc(Socket),
    send_rpc(Socket, {response, RequestId, nil, {ext, 0, <<0, 0, 0, 1>>}}),
    receive
        {api_result, Result} -> ?assertEqual({ok, {ext, 0, <<0, 0, 0, 1>>}}, Result)
    after 3000 ->
        ?assert(false)
    end.

handles_requests_and_notifications({_Server, Socket, _Path}) ->
    Parent = self(),
    ok = nvim:register_handler(<<"test_add">>, fun([Left, Right]) ->
        {ok, Left + Right}
    end),
    ok = nvim:register_handler(<<"test_event">>, fun(Params) ->
        Parent ! {notification_received, Params},
        ok
    end),
    send_rpc_fragmented(Socket, {request, 23, <<"test_add">>, [20, 22]}),
    ?assertEqual(
        {ok, {response, 23, nil, 42}, <<>>},
        receive_rpc(Socket)
    ),
    send_rpc(Socket, {notification, <<"test_event">>, [<<"ready">>]}),
    receive
        {notification_received, [<<"ready">>]} -> ok
    after 1000 ->
        ?assert(false)
    end.

sends_requests_to_neovim({_Server, Socket, _Path}) ->
    Parent = self(),
    _Caller = spawn(fun() ->
        Parent ! {call_result, nvim:call(<<"nvim_eval">>, [{string, <<"1 + 1">>}], 5000)}
    end),
    {ok, {request, RequestId, <<"nvim_eval">>, [{string, <<"1 + 1">>}]}, <<>>} =
        receive_rpc(Socket),
    send_rpc(Socket, {response, RequestId, nil, 2}),
    receive
        {call_result, Result} -> ?assertEqual({ok, 2}, Result)
    after 3000 ->
        ?assert(false)
    end,
    ok = nvim:cast(<<"nvim_command">>, [{string, <<"redraw">>}]),
    ?assertEqual(
        {ok, {notification, <<"nvim_command">>, [{string, <<"redraw">>}]}, <<>>},
        receive_rpc(Socket, 3000)
    ).

returns_timeout_for_unanswered_request({_Server, Socket, _Path}) ->
    Parent = self(),
    _Caller = spawn(fun() ->
        Parent ! {call_result, nvim:call(<<"nvim_eval">>, [], 1000)}
    end),
    ?assertMatch(
        {ok, {request, _RequestId, <<"nvim_eval">>, []}, <<>>},
        receive_rpc(Socket, 3000)
    ),
    receive
        {call_result, Result} -> ?assertEqual({error, timeout}, Result)
    after 3000 ->
        ?assert(false)
    end.

rejects_unregistered_method({_Server, Socket, _Path}) ->
    send_rpc(Socket, {request, 31, <<"unknown_method">>, []}),
    ?assertEqual(
        {ok, {response, 31, {string, <<"method_not_found">>}, nil}, <<>>},
        receive_rpc(Socket)
    ).

reports_invalid_handler_results({_Server, Socket, _Path}) ->
    ok = nvim:register_handler(<<"bad_result">>, fun([]) -> self() end),
    send_rpc(Socket, {request, 32, <<"bad_result">>, []}),
    ?assertEqual(
        {ok, {response, 32, {string, <<"invalid_handler_response">>}, nil}, <<>>},
        receive_rpc(Socket)
    ).

accepts_a_reconnecting_client({_Server, Socket, Path}) ->
    ok = nvim:register_handler(<<"reconnected">>, fun([]) ->
        {string, <<"connected">>}
    end),
    _ = gen_tcp:close(Socket),
    timer:sleep(10),
    {ok, NewSocket} = gen_tcp:connect(
        {local, Path},
        0,
        [binary, {packet, raw}, {active, false}],
        1000
    ),
    send_rpc(NewSocket, {request, 33, <<"reconnected">>, []}),
    ?assertEqual(
        {ok, {response, 33, nil, {string, <<"connected">>}}, <<>>},
        receive_rpc(NewSocket)
    ),
    _ = gen_tcp:close(NewSocket),
    ok.

drops_responses_from_disconnected_clients({_Server, Socket, Path}) ->
    Parent = self(),
    ok = nvim:register_handler(<<"delayed">>, fun([]) ->
        Parent ! {handler_started, self()},
        receive
            release_handler -> {string, <<"late">>}
        after 5000 ->
            {error, {string, <<"handler_timeout">>}}
        end
    end),
    send_rpc(Socket, {request, 34, <<"delayed">>, []}),
    Worker =
        receive
            {handler_started, Pid} -> Pid
        after 1000 ->
            ?assert(false)
        end,
    _ = gen_tcp:close(Socket),
    timer:sleep(10),
    {ok, NewSocket} = gen_tcp:connect(
        {local, Path},
        0,
        [binary, {packet, raw}, {active, false}],
        1000
    ),
    send_rpc(NewSocket, {request, 35, <<"not_registered">>, []}),
    ?assertEqual(
        {ok, {response, 35, {string, <<"method_not_found">>}, nil}, <<>>},
        receive_rpc(NewSocket)
    ),
    Worker ! release_handler,
    ?assertEqual({error, timeout}, gen_tcp:recv(NewSocket, 0, 50)),
    _ = gen_tcp:close(NewSocket),
    ok.

start_host() ->
    Path = socket_path(),
    {ok, Server} = nvim_host_connection:start_link({unix, Path}),
    unlink(Server),
    {ok, Socket} = gen_tcp:connect(
        {local, Path},
        0,
        [binary, {packet, raw}, {active, false}],
        1000
    ),
    ok = send_rpc(Socket, {request, 0, <<"test_host_ready">>, []}),
    {ok, {response, 0, {string, <<"method_not_found">>}, nil}, <<>>} = receive_rpc(Socket),
    {Server, Socket, Path}.

stop_host({Server, Socket, _Path}) ->
    _ = gen_tcp:close(Socket),
    ok = gen_server:stop(Server).

send_rpc(Socket, Message) ->
    {ok, Packet} = nvim_rpc:encode_rpc(Message),
    ok = gen_tcp:send(Socket, Packet).

send_rpc_fragmented(Socket, Message) ->
    {ok, Packet} = nvim_rpc:encode_rpc(Message),
    <<FirstByte, Rest/binary>> = Packet,
    ok = gen_tcp:send(Socket, <<FirstByte>>),
    timer:sleep(10),
    ok = gen_tcp:send(Socket, Rest).

receive_rpc(Socket) ->
    receive_rpc(Socket, 3000).

receive_rpc(Socket, Timeout) ->
    {ok, Packet} = gen_tcp:recv(Socket, 0, Timeout),
    nvim_rpc:decode_rpc(Packet).

socket_path() ->
    filename:join(
        os:getenv("TMPDIR", "/tmp"),
        "nvim-host-test-" ++
            integer_to_list(erlang:system_time(nanosecond)) ++
            "-" ++ integer_to_list(erlang:unique_integer([positive])) ++
            ".sock"
    ).
