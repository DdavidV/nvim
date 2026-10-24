-module(nvim_host_extentions).

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
    Directory = application:get_env(nvim_erlang_host, scripts_dir, ""),
    ScriptsDir = filename:absname(Directory),
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 10
    },
    ChildSpecs = start_extentions(ScriptsDir),
    {ok, {SupFlags, ChildSpecs}}.

start_extentions(ScriptsDir) ->
    EbinDir = filename:join(ScriptsDir, "ebin"),
    BeamFiles = filelib:wildcard(filename:join(EbinDir, "*.beam")),
    case code:add_patha(EbinDir) of
        true ->
            Modules = load_all(BeamFiles, EbinDir, []),
            lists:flatten([retrieve_child_specs(Module) || Module <- Modules]);
        {error, bad_directory} ->
            logger:error("Cannot add ~p to code path", [EbinDir]),
            []
    end.

load_all([], _EbinDir, Modules) ->
    Modules;
load_all([BeamFile | Rest], EbinDir, Modules) ->
    BeamPath = filename:join(
        EbinDir,
        filename:rootname(BeamFile)
    ),
    case code:load_abs(BeamPath) of
        {module, Module} ->
            run_script_part(Module),
            load_all(Rest, EbinDir, [Module | Modules]);
        {error, Reason} ->
            logger:error("Cannot load beamfile: ~p Reason:~n~p", [BeamFile, Reason]),
            load_all(Rest, EbinDir, Modules)
    end.

run_script_part(Module) ->
    case erlang:function_exported(Module, run, 0) of
        false ->
            ok;
        true ->
            try
                erlang:apply(Module, run, [])
            catch
                Class:Reason:Stack ->
                    logger:error("Erlang extension ~p:run/0 failed (~p): ~p~n~p", [
                        Module,
                        Class,
                        Reason,
                        Stack
                    ]),
                    {error, {Module, Class, Reason}}
            end
    end.

retrieve_child_specs(Module) ->
    case erlang:function_exported(Module, child_specs, 0) of
        false ->
            case erlang:function_exported(Module, start_link, 0) of
                false ->
                    [];
                true ->
                    [
                        #{
                            id => Module,
                            start => {Module, start_link, []},
                            restart => transient,
                            shutdown => 5000,
                            type => worker,
                            modules => [Module]
                        }
                    ]
            end;
        true ->
            [apply(Module, child_specs, [])]
    end.
