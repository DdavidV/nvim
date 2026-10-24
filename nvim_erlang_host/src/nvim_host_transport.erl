-module(nvim_host_transport).

-behaviour(gen_server).

-export([
    send/2
]).

-export([
    start_link/1,
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2
]).

-record(state, {
    owner :: pid(),
    port :: port()
}).

-type state() :: #state{}.

-spec send(TransportPid, Data) -> Result when
    TransportPid :: pid(),
    Data :: binary(),
    Result :: ok | {error, term()}.
send(TransportPid, Data) ->
    gen_server:call(TransportPid, {send, Data}).

-spec start_link(Owner) -> Result when
    Owner :: pid(),
    Result :: gen_server:start_ret().
start_link(Owner) ->
    gen_server:start_link(?MODULE, Owner, []).

-spec init(Owner) -> Result when
    Owner :: pid(),
    Result :: {ok, state()} | {stop, term()}.
init(Owner) ->
    process_flag(trap_exit, true),
    Port = open_port({fd, 0, 1}, [binary, eof]),
    {ok, #state{owner = Owner, port = Port}}.

-spec handle_call(Request, From, State) -> Result when
    Request :: term(),
    From :: gen_server:from(),
    State :: state(),
    Result :: {reply, term(), state()} | {stop, port_closed, {error, port_closed}, state()}.
handle_call({send, Data}, _From, State) ->
    port_command(State#state.port, Data),
    {reply, ok, State}.

-spec handle_cast(Request, State) -> Result when
    Request :: term(),
    State :: state(),
    Result :: {noreply, state()}.
handle_cast(_Request, State) ->
    {noreply, State}.

-spec handle_info(Message, State) -> Result when
    Message :: term(),
    State :: state(),
    Result :: {noreply, state()} | {stop, term(), state()}.
handle_info({Port, {data, Data}}, #state{port = Port, owner = Owner} = State) ->
    Owner ! {transport_data, Data},
    {noreply, State};
handle_info({Port, eof}, #state{port = Port, owner = Owner} = State) ->
    Owner ! transport_input_closed,
    {noreply, State};
handle_info(_Message, State) ->
    {noreply, State}.

-spec terminate(Reason, State) -> Result when
    Reason :: term(),
    State :: state(),
    Result :: ok.
terminate(_Reason, #state{port = Port}) ->
    erlang:port_info(Port) =/= undefined andalso port_close(Port),
    ok.
