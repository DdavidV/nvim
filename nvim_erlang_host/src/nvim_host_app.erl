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
    Transport = application:get_env(nvim_host, transport, stdio),
    case configure_logging(Transport) of
        ok ->
            start_host(Transport);
        {error, Reason} ->
            {error, {host_logging_setup_failed, Reason}}
    end.

start_host(Transport) ->
    case ensure_configured_api_bindings() of
        ok ->
            start_host_and_extensions(Transport);
        {error, Reason} ->
            {error, {nvim_api_bindings_failed, Reason}}
    end.

start_host_and_extensions(Transport) ->
    case nvim_host_sup:start_link(Transport) of
        {ok, Supervisor} ->
            case start_extensions() of
                ok ->
                    notify_started(),
                    {ok, Supervisor};
                {error, Reason} ->
                    unlink(Supervisor),
                    exit(Supervisor, shutdown),
                    {error, {extensions_start_failed, Reason}}
            end;
        Error ->
            Error
    end.

notify_started() ->
    Message = {string, <<"Started Neovim Beam host">>},
    Options = #{{string, <<"title">>} => {string, <<"BEAM Host">>}},
    case nvim:api(nvim_notify, [Message, 2, Options]) of
        {ok, NotificationId} when is_integer(NotificationId) ->
            ok;
        {error, Reason} ->
            logger:warning("Could not show Neovim host-started notification: ~p", [Reason])
    end.

start_extensions() ->
    case application:get_env(nvim_host, scripts_dir) of
        {ok, ScriptsDirectory} ->
            nvim_host_extensions:run(filename:join(ScriptsDirectory, "ebin"));
        undefined ->
            ok
    end.

-spec stop(State) -> Result when
    State :: term(),
    Result :: ok.
stop(_State) ->
    ok.

ensure_configured_api_bindings() ->
    case application:get_env(nvim_host, nvim_executable) of
        {ok, Executable} ->
            ensure_api_bindings_for(Executable);
        undefined ->
            ensure_default_api_bindings()
    end.

ensure_default_api_bindings() ->
    case nvim_rpc:ensure_api_bindings() of
        {ok, nvim_api} -> ok;
        {error, Reason} -> {error, Reason}
    end.

ensure_api_bindings_for(Executable) ->
    case nvim_rpc:ensure_api_bindings(Executable) of
        {ok, nvim_api} -> ok;
        {error, Reason} -> {error, Reason}
    end.

configure_logging(stdio) ->
    case logger:get_handler_config(default) of
        {ok, #{module := logger_std_h, config := #{type := standard_io} = Config} = Handler} ->
            NewHandler = maps:with(
                [level, filter_default, filters, formatter],
                Handler
            ),
            redirect_logger(NewHandler, Config);
        {ok, _Handler} ->
            ok;
        {error, Reason} ->
            {error, {default_logger_unavailable, Reason}}
    end;
configure_logging(_Transport) ->
    ok.

redirect_logger(Handler, Config) ->
    case logger:remove_handler(default) of
        ok ->
            NewConfig = Config#{type => standard_error},
            logger:add_handler(default, logger_std_h, Handler#{config => NewConfig});
        {error, Reason} ->
            {error, {default_logger_remove_failed, Reason}}
    end.
