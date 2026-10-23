-module(nvim_host_transport).

-behaviour(gen_server).

-include_lib("kernel/include/file.hrl").

-export([
    start_link/2,
    send/2
]).

-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

-type transport() :: stdio | {unix, file:filename_all()}.
-export_type([transport/0]).

-record(state, {
    owner :: pid(),
    mode :: stdio | unix,
    stdio_port :: port() | undefined,
    listen_socket :: gen_tcp:socket() | undefined,
    acceptor :: pid() | undefined,
    socket :: gen_tcp:socket() | undefined,
    socket_path :: file:filename_all() | undefined,
    socket_info :: file:file_info() | undefined
}).

-type state() :: #state{}.

-spec start_link(Owner, Transport) -> Result when
    Owner :: pid(),
    Transport :: transport(),
    Result :: gen_server:start_ret().
start_link(Owner, Transport) ->
    gen_server:start_link(?MODULE, [Owner, Transport], []).

-spec send(TransportPid, Data) -> Result when
    TransportPid :: pid(),
    Data :: binary(),
    Result :: ok | {error, term()}.
send(TransportPid, Data) ->
    gen_server:call(TransportPid, {send, Data}).

-spec init(Args) -> Result when
    Args :: [pid() | transport()],
    Result :: {ok, state()} | {stop, term()}.
init([Owner, stdio]) ->
    process_flag(trap_exit, true),
    try open_port({fd, 0, 1}, [binary, eof]) of
        Port ->
            {ok, #state{owner = Owner, mode = stdio, stdio_port = Port}}
    catch
        error:Reason ->
            {stop, {stdio_port_open_failed, Reason}}
    end;
init([Owner, {unix, Path}]) when is_list(Path); is_binary(Path) ->
    process_flag(trap_exit, true),
    case start_unix_listener(self(), Path) of
        {ok, ListenSocket, Acceptor, SocketInfo} ->
            {ok, #state{
                owner = Owner,
                mode = unix,
                listen_socket = ListenSocket,
                acceptor = Acceptor,
                socket_path = Path,
                socket_info = SocketInfo
            }};
        {error, Reason} ->
            {stop, {unix_listener_start_failed, Reason}}
    end;
init([_Owner, Transport]) ->
    {stop, {invalid_transport, Transport}}.

-spec handle_call(Request, From, State) -> Result when
    Request :: term(),
    From :: gen_server:from(),
    State :: state(),
    Result :: {reply, term(), state()}.
handle_call({send, Data}, _From, #state{mode = stdio, stdio_port = Port} = State) ->
    try port_command(Port, Data) of
        true ->
            {reply, ok, State}
    catch
        error:Reason -> {reply, {error, {stdio_write_failed, Reason}}, State}
    end;
handle_call({send, Data}, _From, #state{mode = unix, socket = Socket} = State) when
    Socket =/= undefined
->
    {reply, gen_tcp:send(Socket, Data), State};
handle_call({send, _Data}, _From, State) ->
    {reply, {error, not_connected}, State};
handle_call(_Request, _From, State) ->
    {reply, {error, unsupported_request}, State}.

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
handle_info({tcp, Socket, Data}, #state{socket = Socket, owner = Owner} = State) ->
    Owner ! {transport_data, Data},
    case inet:setopts(Socket, [{active, once}]) of
        ok -> {noreply, State};
        {error, Reason} -> {stop, {unix_socket_read_failed, Reason}, State}
    end;
handle_info(
    {tcp_closed, Socket},
    #state{socket = Socket, owner = Owner, acceptor = Acceptor} = State
) ->
    Owner ! transport_disconnected,
    Acceptor ! accept_next,
    {noreply, State#state{socket = undefined}};
handle_info({tcp_error, Socket, Reason}, #state{socket = Socket} = State) ->
    {stop, {unix_socket_error, Reason}, State};
handle_info({unix_accept_failed, Reason}, State) ->
    logger:error("Neovim Unix socket accept failed: ~p", [Reason]),
    {noreply, State};
handle_info({unix_socket_accepted, Socket}, #state{owner = Owner} = State) ->
    case inet:setopts(Socket, [{active, once}]) of
        ok ->
            Owner ! transport_connected,
            {noreply, State#state{socket = Socket}};
        {error, Reason} ->
            _ = gen_tcp:close(Socket),
            {stop, {unix_socket_setup_failed, Reason}, State}
    end;
handle_info({Port, {data, Data}}, #state{stdio_port = Port, owner = Owner} = State) ->
    Owner ! {transport_data, Data},
    {noreply, State};
handle_info({Port, eof}, #state{stdio_port = Port, owner = Owner} = State) ->
    Owner ! transport_input_closed,
    {noreply, State};
handle_info({Port, {exit_status, Status}}, #state{stdio_port = Port} = State) ->
    {stop, {stdio_port_exit, Status}, State};
handle_info({'EXIT', Acceptor, Reason}, #state{acceptor = Acceptor} = State) when
    Reason =/= normal
->
    {stop, {unix_acceptor_failed, Reason}, State};
handle_info({'EXIT', Owner, _Reason}, #state{owner = Owner} = State) ->
    {stop, normal, State};
handle_info(_Message, State) ->
    {noreply, State}.

-spec terminate(Reason, State) -> Result when
    Reason :: term(),
    State :: state(),
    Result :: ok.
terminate(_Reason, #state{mode = stdio, stdio_port = Port}) ->
    _ = port_close(Port),
    ok;
terminate(_Reason, #state{
    listen_socket = ListenSocket,
    socket = Socket,
    acceptor = Acceptor,
    socket_path = Path,
    socket_info = SocketInfo
}) ->
    exit(Acceptor, shutdown),
    close_socket(Socket),
    close_socket(ListenSocket),
    remove_socket_file(Path, SocketInfo),
    ok.

-spec code_change(OldVersion, State, Extra) -> Result when
    OldVersion :: term(),
    State :: state(),
    Extra :: term(),
    Result :: {ok, state()}.
code_change(_OldVersion, State, _Extra) ->
    {ok, State}.

start_unix_listener(TransportPid, Path) ->
    case filelib:ensure_dir(Path) of
        ok -> listen_unix_socket(TransportPid, Path);
        {error, Reason} -> {error, {socket_directory_failed, Reason}}
    end.

listen_unix_socket(TransportPid, Path) ->
    Options = [
        {ifaddr, {local, Path}},
        binary,
        {packet, raw},
        {active, false}
    ],
    case gen_tcp:listen(0, Options) of
        {ok, ListenSocket} ->
            track_unix_listener(TransportPid, Path, ListenSocket);
        {error, Reason} ->
            {error, {listen_failed, Reason}}
    end.

track_unix_listener(TransportPid, Path, ListenSocket) ->
    case file:change_mode(Path, 8#600) of
        ok ->
            track_socket_file(TransportPid, Path, ListenSocket);
        {error, Reason} ->
            _ = gen_tcp:close(ListenSocket),
            {error, {socket_permissions_failed, Reason}}
    end.

track_socket_file(TransportPid, Path, ListenSocket) ->
    case file:read_file_info(Path) of
        {ok, SocketInfo} ->
            Acceptor = spawn_link(fun() -> accept_loop(ListenSocket, TransportPid) end),
            {ok, ListenSocket, Acceptor, SocketInfo};
        {error, Reason} ->
            _ = gen_tcp:close(ListenSocket),
            {error, {socket_file_stat_failed, Reason}}
    end.

accept_loop(ListenSocket, Owner) ->
    case gen_tcp:accept(ListenSocket) of
        {ok, Socket} ->
            case gen_tcp:controlling_process(Socket, Owner) of
                ok ->
                    Owner ! {unix_socket_accepted, Socket},
                    receive
                        accept_next ->
                            accept_loop(ListenSocket, Owner);
                        stop ->
                            _ = gen_tcp:close(Socket),
                            ok
                    after infinity ->
                        ok
                    end;
                {error, Reason} ->
                    _ = gen_tcp:close(Socket),
                    Owner ! {unix_accept_failed, Reason},
                    accept_loop(ListenSocket, Owner)
            end;
        {error, closed} ->
            ok;
        {error, Reason} ->
            Owner ! {unix_accept_failed, Reason},
            timer:sleep(100),
            accept_loop(ListenSocket, Owner)
    end.

close_socket(undefined) ->
    ok;
close_socket(Socket) ->
    gen_tcp:close(Socket).

remove_socket_file(Path, #file_info{
    inode = Inode,
    major_device = MajorDevice,
    minor_device = MinorDevice
}) ->
    case file:read_file_info(Path) of
        {ok, #file_info{
            inode = Inode,
            major_device = MajorDevice,
            minor_device = MinorDevice
        }} ->
            case file:delete(Path) of
                ok ->
                    ok;
                {error, enoent} ->
                    ok;
                {error, Reason} ->
                    logger:warning("Could not remove Unix socket ~ts: ~p", [
                        Path,
                        Reason
                    ])
            end;
        {error, enoent} ->
            ok;
        {error, Reason} ->
            logger:warning("Could not inspect Unix socket ~ts: ~p", [
                Path,
                Reason
            ]);
        _ ->
            ok
    end;
remove_socket_file(_Path, _SocketInfo) ->
    ok.
