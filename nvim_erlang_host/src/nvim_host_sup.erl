-module(nvim_host_sup).

-behaviour(supervisor).

-export([
    start_link/0,
    init/1
]).

-spec start_link() -> Result when
    Result :: supervisor:startlink_ret().
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec init(Args) -> Result when
    Args :: term(),
    Result :: {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init(_Args) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 10
    },
    ChildSpecs = [
        #{
            id => nvim_host_connection,
            start => {nvim_host_connection, start_link, []},
            restart => transient,
            shutdown => 5000,
            type => worker,
            modules => [nvim_host_connection]
        }
    ],
    {ok, {SupFlags, ChildSpecs}}.
