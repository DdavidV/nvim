-module(nvim_host_connection).

-behaviour(gen_server).

-record(state, {
    transport :: pid(),
    buffer = <<>> :: binary(),
    next_id = 1 :: nvim_rpc:rpc_request_id(),
    pending = #{} :: #{nvim_rpc:rpc_request_id() => {gen_server:from(), reference()}},
    handlers = #{} :: #{binary() => nvim:handler()},
    workers = #{} :: #{pid() => {reference(), term(), nvim_rpc:rpc_request_id(), integer()}},
    input_closed = false :: boolean(),
    connection_generation = 0 :: integer()
}).

-type state() :: #state{}.

-export([
    start_link/1,
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

-spec start_link(Transport) -> Result when
    Transport :: nvim_host_transport:transport(),
    Result :: gen_server:start_ret().
start_link(Transport) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [Transport], []).

-spec init(Args) -> Result when
    Args :: [nvim_host_transport:transport()],
    Result :: {ok, state()} | {stop, term()}.
init([Transport]) ->
    case nvim_host_transport:start_link(self(), Transport) of
        {ok, TransportPid} ->
            {ok, #state{transport = TransportPid}};
        {error, Reason} ->
            {stop, {transport_start_failed, Reason}}
    end.

-spec handle_call(Request, From, State) -> Result when
    Request :: term(),
    From :: gen_server:from(),
    State :: state(),
    Result ::
        {reply, term(), state()}
        | {noreply, state()}
        | {stop, term(), term(), state()}.
handle_call({call, Method, Params, Timeout}, From, State) ->
    RequestId = State#state.next_id,
    Message = {request, RequestId, Method, Params},
    case encode_and_send(Message, State#state.transport) of
        ok ->
            wait_for_response(RequestId, Timeout, From, State);
        {error, Reason} ->
            {reply, {error, Reason}, State#state{next_id = RequestId + 1}}
    end;
handle_call({api_call, Function, Params, Timeout}, From, State) ->
    RequestId = State#state.next_id,
    case apply(nvim_api, Function, [RequestId | Params]) of
        {ok, Packet} when is_binary(Packet) ->
            case nvim_host_transport:send(State#state.transport, Packet) of
                ok ->
                    wait_for_response(RequestId, Timeout, From, State);
                {error, Reason} ->
                    {reply, {error, {transport_send_failed, Reason}}, advance_request_id(State)}
            end;
        {error, Reason} ->
            {reply, {error, {api_request_encode_failed, Reason}}, advance_request_id(State)};
        _Unexpected ->
            {reply, {error, invalid_api_binding_response}, advance_request_id(State)}
    end;
handle_call({register_handler, Method, Handler}, _From, State) ->
    case normalize_method(Method) of
        {ok, MethodBinary} ->
            Handlers = maps:put(MethodBinary, Handler, State#state.handlers),
            {reply, ok, State#state{handlers = Handlers}};
        {error, Reason} ->
            {reply, {error, Reason}, State}
    end;
handle_call({unregister_handler, Method}, _From, State) ->
    case normalize_method(Method) of
        {ok, MethodBinary} ->
            {reply, ok, State#state{handlers = maps:remove(MethodBinary, State#state.handlers)}};
        {error, Reason} ->
            {reply, {error, Reason}, State}
    end;
handle_call(_Request, _From, State) ->
    {reply, {error, unsupported_request}, State}.

wait_for_response(RequestId, Timeout, From, State) ->
    Timer = erlang:send_after(Timeout, self(), {request_timeout, RequestId}),
    Pending = maps:put(RequestId, {From, Timer}, State#state.pending),
    {noreply, State#state{next_id = RequestId + 1, pending = Pending}}.

advance_request_id(State) ->
    State#state{next_id = State#state.next_id + 1}.

-spec handle_cast(Request, State) -> Result when
    Request :: term(),
    State :: state(),
    Result :: {noreply, state()}.
handle_cast({Method, Params}, State) ->
    send_notification(Method, Params, State);
handle_cast(_Request, State) ->
    {noreply, State}.

-spec handle_info(Message, State) -> Result when
    Message :: term(),
    State :: state(),
    Result :: {noreply, state()} | {stop, term(), state()}.
handle_info({transport_data, Data}, State) ->
    decode_messages(<<(State#state.buffer)/binary, Data/binary>>, State#state{buffer = <<>>});
handle_info(transport_input_closed, State) ->
    fail_pending(disconnected, State),
    maybe_stop_after_input_closed(State#state{input_closed = true, pending = #{}});
handle_info(transport_connected, State) ->
    {noreply, State#state{connection_generation = State#state.connection_generation + 1}};
handle_info(transport_disconnected, State) ->
    fail_pending(disconnected, State),
    {noreply, State#state{
        buffer = <<>>,
        pending = #{},
        connection_generation = State#state.connection_generation + 1
    }};
handle_info({request_timeout, RequestId}, State) ->
    case maps:take(RequestId, State#state.pending) of
        {{From, _Timer}, Pending} ->
            gen_server:reply(From, {error, timeout}),
            {noreply, State#state{pending = Pending}};
        error ->
            {noreply, State}
    end;
handle_info({handler_result, WorkerPid, Result}, State) ->
    case maps:take(WorkerPid, State#state.workers) of
        {{MonitorRef, request, RequestId, Generation}, Workers} ->
            erlang:demonitor(MonitorRef, [flush]),
            State1 = State#state{workers = Workers},
            case Generation =:= State#state.connection_generation of
                true -> handle_handler_response(RequestId, Result, State1);
                false -> maybe_stop_after_input_closed(State1)
            end;
        {{MonitorRef, notification, Method, _Generation}, Workers} ->
            erlang:demonitor(MonitorRef, [flush]),
            log_notification_result(Method, Result),
            maybe_stop_after_input_closed(State#state{workers = Workers});
        error ->
            {noreply, State}
    end;
handle_info({'DOWN', MonitorRef, process, Pid, Reason}, State) ->
    case maps:take(Pid, State#state.workers) of
        {{MonitorRef, request, RequestId, Generation}, Workers} ->
            State1 = State#state{workers = Workers},
            case Generation =:= State#state.connection_generation of
                true ->
                    handle_handler_response(
                        RequestId,
                        {exception, exit, Reason, []},
                        State1
                    );
                false ->
                    maybe_stop_after_input_closed(State1)
            end;
        {{MonitorRef, notification, Method, _Generation}, Workers} ->
            logger:error("Neovim notification handler ~ts exited: ~p", [Method, Reason]),
            maybe_stop_after_input_closed(State#state{workers = Workers});
        error ->
            {noreply, State}
    end;
handle_info(_Message, State) ->
    {noreply, State}.

-spec terminate(Reason, State) -> Result when
    Reason :: term(),
    State :: state(),
    Result :: ok.
terminate(_Reason, _State) ->
    ok.

-spec code_change(OldVersion, State, Extra) -> Result when
    OldVersion :: term(),
    State :: state(),
    Extra :: term(),
    Result :: {ok, state()}.
code_change(_OldVersion, State, _Extra) ->
    {ok, State}.

decode_messages(<<>>, State) ->
    {noreply, State};
decode_messages(Binary, State) ->
    case nvim_rpc:decode_rpc(Binary) of
        {ok, Message, Rest} ->
            case handle_rpc_message(Message, State) of
                {ok, State1} -> decode_messages(Rest, State1);
                {error, Reason, State1} -> {stop, {invalid_rpc_message, Reason}, State1}
            end;
        {error, incomplete} ->
            {noreply, State#state{buffer = Binary}};
        {error, Reason} ->
            {stop, {invalid_messagepack_rpc, Reason}, State}
    end.

handle_rpc_message({request, RequestId, Method, Params}, State) ->
    dispatch_handler(request, RequestId, Method, Params, State);
handle_rpc_message({notification, Method, Params}, State) ->
    dispatch_handler(notification, undefined, Method, Params, State);
handle_rpc_message({response, RequestId, Error, Result}, State) ->
    case maps:take(RequestId, State#state.pending) of
        {{From, Timer}, Pending} ->
            _ = erlang:cancel_timer(Timer),
            Reply =
                case Error of
                    nil -> {ok, Result};
                    _ -> {error, Error}
                end,
            gen_server:reply(From, Reply),
            {ok, State#state{pending = Pending}};
        error ->
            logger:warning("Received response for unknown Neovim RPC request ~p", [RequestId]),
            {ok, State}
    end.

dispatch_handler(Kind, RequestId, Method, Params, State) ->
    case maps:find(Method, State#state.handlers) of
        {ok, Handler} ->
            Parent = self(),
            {Pid, MonitorRef} = spawn_monitor(fun() ->
                Result = invoke_handler(Handler, Params),
                Parent ! {handler_result, self(), Result}
            end),
            Workers = maps:put(
                Pid,
                {
                    MonitorRef,
                    Kind,
                    request_id_or_method(Kind, RequestId, Method),
                    State#state.connection_generation
                },
                State#state.workers
            ),
            {ok, State#state{workers = Workers}};
        error ->
            handler_not_found(Kind, RequestId, Method, State)
    end.

invoke_handler(Handler, Params) ->
    try Handler(Params) of
        {ok, Result} -> {ok, Result};
        {error, Error} -> {error, Error};
        Result -> {ok, Result}
    catch
        Class:Reason:Stack ->
            {exception, Class, Reason, Stack}
    end.

handler_not_found(request, RequestId, _Method, State) ->
    Error = {string, <<"method_not_found">>},
    send_response(RequestId, Error, nil, State);
handler_not_found(notification, _RequestId, Method, State) ->
    logger:warning("No handler registered for Neovim notification ~ts", [Method]),
    {ok, State}.

respond_to_request(RequestId, {ok, Result}, State) ->
    send_response(RequestId, nil, Result, State);
respond_to_request(RequestId, {error, Error}, State) ->
    send_response(RequestId, Error, nil, State);
respond_to_request(RequestId, {exception, Class, Reason, Stack}, State) ->
    logger:error("Neovim RPC handler failed (~p): ~p~n~p", [Class, Reason, Stack]),
    send_response(RequestId, {string, <<"handler_failed">>}, nil, State).

send_response(RequestId, Error, ResponseResult, State) ->
    case send_message({response, RequestId, Error, ResponseResult}, State) of
        {error, {rpc_encode_failed, Reason}, State1} ->
            logger:error("Could not encode handler response: ~p", [Reason]),
            send_message(
                {response, RequestId, {string, <<"invalid_handler_response">>}, nil},
                State1
            );
        OtherResult ->
            OtherResult
    end.

send_message(Message, State) ->
    case encode_and_send(Message, State#state.transport) of
        ok -> {ok, State};
        {error, Reason} -> {error, Reason, State}
    end.

handle_handler_response(RequestId, Result, State) ->
    case respond_to_request(RequestId, Result, State) of
        {ok, State1} -> maybe_stop_after_input_closed(State1);
        {error, Reason, State1} -> {stop, Reason, State1}
    end.

maybe_stop_after_input_closed(#state{input_closed = true, workers = Workers} = State) when
    map_size(Workers) =:= 0
->
    _ = spawn(fun() -> application:stop(nvim_host) end),
    {stop, normal, State};
maybe_stop_after_input_closed(State) ->
    {noreply, State}.

encode_and_send(Message, Transport) ->
    case nvim_rpc:encode_rpc(Message) of
        {ok, Packet} ->
            case nvim_host_transport:send(Transport, Packet) of
                ok -> ok;
                {error, Reason} -> {error, {transport_send_failed, Reason}}
            end;
        {error, Reason} ->
            {error, {rpc_encode_failed, Reason}}
    end.

send_notification(Method, Params, State) ->
    case encode_and_send({notification, Method, Params}, State#state.transport) of
        ok ->
            {noreply, State};
        {error, Reason} ->
            logger:error("Could not send Neovim notification: ~p", [Reason]),
            {noreply, State}
    end.

normalize_method(Method) when is_atom(Method) ->
    normalize_method_binary(atom_to_binary(Method, utf8));
normalize_method(Method) when is_binary(Method) ->
    normalize_method_binary(Method);
normalize_method({string, Method}) when is_binary(Method) ->
    normalize_method_binary(Method);
normalize_method(_) ->
    {error, invalid_method}.

normalize_method_binary(Method) ->
    case nvim_rpc:encode_rpc({notification, {string, Method}, []}) of
        {ok, _Packet} -> {ok, Method};
        {error, Reason} -> {error, {invalid_method, Reason}}
    end.

fail_pending(Reason, State) ->
    maps:foreach(
        fun(_RequestId, {From, Timer}) ->
            _ = erlang:cancel_timer(Timer),
            gen_server:reply(From, {error, Reason})
        end,
        State#state.pending
    ).

log_notification_result(Method, {exception, Class, Reason, Stack}) ->
    logger:error("Neovim notification handler ~ts failed (~p): ~p~n~p", [
        Method,
        Class,
        Reason,
        Stack
    ]);
log_notification_result(Method, {error, Reason}) ->
    logger:error("Neovim notification handler ~ts returned an error: ~p", [Method, Reason]);
log_notification_result(_Method, {ok, _Result}) ->
    ok.

request_id_or_method(request, RequestId, _Method) ->
    RequestId;
request_id_or_method(notification, _RequestId, Method) ->
    Method.
