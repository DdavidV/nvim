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
    {ok, nvim_api} = nvim_rpc:ensure_api_bindings(),
    ok = configure_logging(),
    nvim_host_sup:start_link().

configure_logging() ->
    ok = logger:remove_handler(default),
    LogDir = filename:basedir(user_log, "nvim-beam"),
    LogFile = filename:join(LogDir, "erlang.server.log"),
    ok = filelib:ensure_path(LogDir),
    ok = logger:add_handler(nvim_file, logger_std_h, #{
        level => info,
        config => #{
            file => LogFile,
            max_no_bytes => 10 * 1024 * 1024,
            max_no_files => 10
        },
        formatter => {logger_formatter, #{single_line => true}}
    }),
    logger:info("Logging initialized").

-spec stop(State) -> Result when
    State :: term(),
    Result :: ok.
stop(_State) ->
    ok.
