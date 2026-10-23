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
        strategy => one_for_all,
        intensity => 0,
        period => 1
    },
    ChildSpecs = [],
    {ok, {SupFlags, ChildSpecs}}.
