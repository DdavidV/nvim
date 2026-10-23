-module(nvim_host_app).

-behaviour(application).

-export([
    start/2,
    stop/1
]).

-spec start(StartType, StartArgs) -> Result when
    StartType :: application:start_type(),
    StartArgs :: term(),
    Result :: supervisor:startlink_ret().
start(_StartType, _StartArgs) ->
    nvim_host_sup:start_link().

-spec stop(State) -> Result when
    State :: term(),
    Result :: ok.
stop(_State) ->
    ok.
