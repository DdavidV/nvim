-module(nvim_host_sup).

-behaviour(supervisor).

-export([
    start_link/0,
    start_link/1,
    init/1
]).

-spec start_link() -> Result when
    Result :: supervisor:startlink_ret().
start_link() ->
    start_link(application:get_env(nvim_host, transport, stdio)).

-spec start_link(Transport) -> Result when
    Transport :: nvim_host_transport:transport(),
    Result :: supervisor:startlink_ret().
start_link(Transport) ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, [Transport]).

-spec init(Args) -> Result when
    Args :: term(),
    Result :: {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([Transport]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 10
    },
    ChildSpecs = [
        #{
            id => nvim_host_connection,
            start => {nvim_host_connection, start_link, [Transport]},
            restart => transient,
            shutdown => 5000,
            type => worker,
            modules => [nvim_host_connection]
        }
    ],
    {ok, {SupFlags, ChildSpecs}}.
