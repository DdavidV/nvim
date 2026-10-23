-module(nvim_host_extensions).

-export([
    run/1
]).

-spec run(Directory) -> Result when
    Directory :: file:filename_all(),
    Result :: ok | {error, term()}.
run(Directory) when is_list(Directory) orelse is_binary(Directory) ->
    AbsoluteDirectory = filename:absname(Directory),
    case file:list_dir(AbsoluteDirectory) of
        {ok, Files} ->
            BeamFiles = lists:sort([
                File
             || File <- Files,
                filename:extension(File) =:= ".beam"
            ]),
            case code:add_patha(AbsoluteDirectory) of
                true ->
                    load_extensions(BeamFiles, AbsoluteDirectory);
                {error, bad_directory} ->
                    {error, {extension_path_add_failed, AbsoluteDirectory}}
            end;
        {error, Reason} ->
            {error, {extension_directory_read_failed, AbsoluteDirectory, Reason}}
    end;
run(Directory) ->
    {error, {invalid_extension_directory, Directory}}.

load_extensions([], _Directory) ->
    ok;
load_extensions([BeamFile | Rest], Directory) ->
    BeamPath = filename:join(Directory, filename:rootname(BeamFile)),
    case code:load_abs(BeamPath) of
        {module, Module} ->
            case run_extension(Module) of
                ok -> load_extensions(Rest, Directory);
                {error, Reason} -> {error, Reason}
            end;
        {error, Reason} ->
            {error, {extension_load_failed, BeamFile, Reason}}
    end.

run_extension(Module) ->
    case erlang:function_exported(Module, run, 0) of
        false ->
            ok;
        true ->
            try erlang:apply(Module, run, []) of
                ok ->
                    ok;
                {ok, _Value} ->
                    ok;
                Result ->
                    {error, {extension_run_failed, Module, Result}}
            catch
                Class:Reason:Stack ->
                    logger:error("Erlang extension ~p:run/0 failed (~p): ~p~n~p", [
                        Module,
                        Class,
                        Reason,
                        Stack
                    ]),
                    {error, {extension_run_exception, Module, Class, Reason}}
            end
    end.
