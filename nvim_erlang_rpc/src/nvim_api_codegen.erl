-module(nvim_api_codegen).

-export([ensure/1]).

-ifdef(TEST).
-export([
    read_api_info/1,
    resolve_executable/1,
    collect_api_info/2,
    generate_bindings/2,
    collect_functions/2,
    collect_types/2,
    render_module/4,
    api_version/1,
    cache_dir/1,
    cache_dir/2,
    project_root/1,
    field/2,
    hex/1,
    write_and_compile/6,
    compile_or_load/5,
    load_bindings/1
]).
-endif.

-define(GENERATION_TIMEOUT_MS, 30000).
-define(GENERATOR_VERSION, <<"nvim_rpc_codegen_v1">>).

-spec ensure(NvimExecutable) -> Result when
    NvimExecutable :: file:filename_all(),
    Result :: {ok, module()} | {error, term()}.
ensure(NvimExecutable) when is_list(NvimExecutable) orelse is_binary(NvimExecutable) ->
    case application:ensure_all_started([crypto, compiler]) of
        {ok, _Started} -> generate_for_executable(NvimExecutable);
        {error, Reason} -> {error, {crypto_start_failed, Reason}}
    end;
ensure(_) ->
    {error, invalid_nvim_executable}.

generate_for_executable(NvimExecutable) ->
    case read_api_info(NvimExecutable) of
        {ok, ApiInfoBinary} ->
            case nvim_rpc:decode(ApiInfoBinary) of
                {ok, ApiInfo, <<>>} ->
                    generate_bindings(ApiInfoBinary, ApiInfo);
                {ok, _ApiInfo, _TrailingBytes} ->
                    {error, trailing_api_info_data};
                {error, Reason} ->
                    {error, {invalid_api_info, Reason}}
            end;
        Error ->
            Error
    end.

read_api_info(NvimExecutable) ->
    case resolve_executable(NvimExecutable) of
        {ok, Executable} ->
            Port = open_port(
                {spawn_executable, Executable},
                [binary, use_stdio, exit_status, {args, ["--api-info"]}]
            ),
            collect_api_info(Port, []);
        error ->
            {error, {nvim_executable_not_found, NvimExecutable}}
    end.

resolve_executable(Executable) when is_binary(Executable) ->
    resolve_executable(binary_to_list(Executable));
resolve_executable(Executable) ->
    case filename:pathtype(Executable) of
        absolute ->
            resolve_file(Executable);
        relative ->
            case filename:dirname(Executable) of
                "." ->
                    case os:find_executable(Executable) of
                        false -> error;
                        Path -> {ok, Path}
                    end;
                _ ->
                    resolve_file(filename:absname(Executable))
            end
    end.

resolve_file(Path) ->
    case filelib:is_regular(Path) of
        true -> {ok, Path};
        false -> error
    end.

collect_api_info(Port, Chunks) ->
    receive
        {Port, {data, Data}} ->
            collect_api_info(Port, [Data | Chunks]);
        {Port, {exit_status, 0}} ->
            {ok, iolist_to_binary(lists:reverse(Chunks))};
        {Port, {exit_status, Status}} ->
            {error, {nvim_api_info_failed, Status}};
        {'EXIT', Port, Reason} ->
            {error, {nvim_port_failed, Reason}}
    after ?GENERATION_TIMEOUT_MS ->
        port_close(Port),
        {error, nvim_api_info_timeout}
    end.

generate_bindings(ApiInfoBinary, ApiInfo) when is_map(ApiInfo) ->
    case
        {
            field(<<"version">>, ApiInfo),
            field(<<"functions">>, ApiInfo),
            field(<<"types">>, ApiInfo)
        }
    of
        {Version, Functions, Types} when
            is_map(Version) andalso
                is_list(Functions) andalso
                is_map(Types)
        ->
            generate_bindings(ApiInfoBinary, Version, Functions, Types);
        _ ->
            {error, invalid_api_info_shape}
    end;
generate_bindings(_, _) ->
    {error, invalid_api_info_shape}.

generate_bindings(ApiInfoBinary, Version, Functions, Types) ->
    case collect_functions(Functions, []) of
        {ok, Bindings} ->
            case collect_types(maps:to_list(Types), []) of
                {ok, TypeBindings} ->
                    prepare_bindings(
                        ApiInfoBinary, Version, Bindings, TypeBindings
                    );
                Error ->
                    Error
            end;
        Error ->
            Error
    end.

prepare_bindings(ApiInfoBinary, Version, Bindings, TypeBindings) ->
    case api_version(Version) of
        {ok, VersionTuple} ->
            Hash = crypto:hash(sha256, [?GENERATOR_VERSION, ApiInfoBinary]),
            load_or_generate(Hash, VersionTuple, Bindings, TypeBindings);
        error ->
            {error, invalid_api_version}
    end.

load_or_generate(Hash, Version, Bindings, TypeBindings) ->
    case cache_dir(Hash) of
        {ok, CacheDir} ->
            LockId = {{?MODULE, CacheDir}, self()},
            Generate = fun() ->
                compile_or_load(CacheDir, Hash, Version, Bindings, TypeBindings)
            end,
            case global:trans(LockId, Generate) of
                aborted -> {error, api_binding_cache_lock_failed};
                Result -> Result
            end;
        Error ->
            Error
    end.

collect_functions([], Acc) ->
    {ok, lists:reverse(Acc)};
collect_functions([Function | Rest], Acc) when is_map(Function) ->
    case {field(<<"name">>, Function), field(<<"parameters">>, Function)} of
        {{string, Name}, Parameters} when is_list(Parameters) ->
            case valid_function_name(Name) andalso valid_parameters(Parameters) of
                true -> collect_functions(Rest, [{Name, length(Parameters)} | Acc]);
                false -> {error, {invalid_api_function, Name}}
            end;
        _ ->
            {error, invalid_api_function_metadata}
    end;
collect_functions(_, _) ->
    {error, invalid_api_function_metadata}.

valid_function_name(Name) ->
    case re:run(Name, <<"^[a-z][a-zA-Z0-9_]*$">>, [{capture, none}]) of
        match -> true;
        nomatch -> false
    end.

valid_parameters(Parameters) ->
    lists:all(
        fun
            ([{string, _Type}, {string, _Name}]) -> true;
            (_) -> false
        end,
        Parameters
    ).

collect_types([], Acc) ->
    {ok, lists:reverse(Acc)};
collect_types([{{string, Name}, Metadata} | Rest], Acc) when is_map(Metadata) ->
    case {valid_type_name(Name), field(<<"id">>, Metadata)} of
        {true, Id} when is_integer(Id) andalso Id >= -128 andalso Id =< 127 ->
            collect_types(Rest, [{Name, Id} | Acc]);
        _ ->
            {error, {invalid_api_type, Name}}
    end;
collect_types(_, _) ->
    {error, invalid_api_type_metadata}.

valid_type_name(Name) ->
    case re:run(Name, <<"^[A-Z][a-zA-Z0-9_]*$">>, [{capture, none}]) of
        match -> true;
        nomatch -> false
    end.

compile_or_load(CacheDir, Hash, Version, Bindings, TypeBindings) ->
    EbinDir = filename:join(CacheDir, "ebin"),
    SourcePath = filename:join(CacheDir, "nvim_api.erl"),
    BeamPath = filename:join(EbinDir, "nvim_api.beam"),
    case filelib:ensure_dir(BeamPath) of
        ok ->
            case file:read_file(BeamPath) of
                {ok, Beam} ->
                    case beam_lib:chunks(Beam, [exports]) of
                        {ok, {nvim_api, _Chunks}} ->
                            load_bindings(EbinDir);
                        _ ->
                            _ = file:delete(BeamPath),
                            write_and_compile(
                                SourcePath, EbinDir, Hash, Version, Bindings, TypeBindings
                            )
                    end;
                {error, enoent} ->
                    write_and_compile(
                        SourcePath, EbinDir, Hash, Version, Bindings, TypeBindings
                    );
                {error, Reason} ->
                    {error, {cache_read_failed, Reason}}
            end;
        {error, Reason} ->
            {error, {cache_directory_failed, Reason}}
    end.

write_and_compile(SourcePath, EbinDir, Hash, Version, Bindings, TypeBindings) ->
    Source = render_module(Hash, Version, Bindings, TypeBindings),
    case file:write_file(SourcePath, Source) of
        ok ->
            case
                compile:file(SourcePath, [
                    {outdir, EbinDir},
                    report_errors,
                    report_warnings
                ])
            of
                {ok, nvim_api} -> load_bindings(EbinDir);
                {ok, nvim_api, _Warnings} -> load_bindings(EbinDir);
                error -> {error, api_binding_compile_failed};
                {error, Errors, Warnings} -> {error, {api_binding_compile_failed, Errors, Warnings}}
            end;
        {error, Reason} ->
            {error, {api_binding_write_failed, Reason}}
    end.

load_bindings(EbinDir) ->
    case code:add_patha(EbinDir) of
        true ->
            case code:load_file(nvim_api) of
                {module, nvim_api} -> {ok, nvim_api};
                {error, Reason} -> {error, {api_binding_load_failed, Reason}}
            end;
        {error, bad_directory} ->
            {error, {api_binding_path_failed, EbinDir}}
    end.

render_module(Hash, {Major, Minor, Patch}, Bindings, TypeBindings) ->
    HashHex = hex(Hash),
    Exports = [
        "api_hash/0",
        "api_version/0",
        "type_id/1",
        "type_name/1"
        | [
            binary_to_list(Name) ++ "/" ++ integer_to_list(Arity + 1)
         || {Name, Arity} <- Bindings
        ]
    ],
    ExportLine = io_lib:format("-export([~s]).~n", [string:join(Exports, ", ")]),
    Functions = [render_binding(Name, Arity) || {Name, Arity} <- Bindings],
    TypeFunctions = render_types(TypeBindings),
    iolist_to_binary([
        "-module(nvim_api).\n",
        ExportLine,
        io_lib:format("api_hash() -> <<\"~s\">>.~n", [HashHex]),
        io_lib:format("api_version() -> {~B, ~B, ~B}.~n", [Major, Minor, Patch]),
        TypeFunctions,
        Functions
    ]).

render_types(TypeBindings) ->
    IdClauses = [
        io_lib:format("type_id(<<\"~s\">>) -> {ok, ~B};~n", [Name, Id])
     || {Name, Id} <- TypeBindings
    ],
    NameClauses = [
        io_lib:format("type_name(~B) -> {ok, <<\"~s\">>};~n", [Id, Name])
     || {Name, Id} <- TypeBindings
    ],
    [
        IdClauses,
        "type_id(_) -> error.\n",
        NameClauses,
        "type_name(_) -> error.\n"
    ].

render_binding(Name, Arity) ->
    FunctionName = binary_to_list(Name),
    Args = ["Arg" ++ integer_to_list(Index) || Index <- lists:seq(1, Arity)],
    Parameters = ["RequestId" | Args],
    ParamListText = string:join(Args, ", "),
    io_lib:format(
        "~s(~s) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<\"~s\">>}, [~s]}).~n",
        [FunctionName, string:join(Parameters, ", "), FunctionName, ParamListText]
    ).

api_version(Version) ->
    case
        {
            field(<<"major">>, Version),
            field(<<"minor">>, Version),
            field(<<"patch">>, Version)
        }
    of
        {Major, Minor, Patch} when
            is_integer(Major) andalso
                is_integer(Minor) andalso
                is_integer(Patch)
        ->
            {ok, {Major, Minor, Patch}};
        _ ->
            error
    end.

cache_dir(Hash) ->
    cache_dir(Hash, filename:dirname(code:which(?MODULE))).

cache_dir(Hash, ModuleDir) ->
    case project_root(ModuleDir) of
        {ok, Root} ->
            {ok, filename:join([Root, ".nvim_api", "api", hex(Hash)])};
        error ->
            {error, nvim_rpc_project_root_not_found}
    end.

project_root(Path) ->
    RebarConfig = filename:join(Path, "rebar.config"),
    MixFile = filename:join(Path, "mix.exs"),

    case filelib:is_regular(RebarConfig) orelse
         filelib:is_regular(MixFile) of
        true ->
            {ok, Path};
        false ->
            Parent = filename:dirname(Path),
            case Parent =:= Path of
                true ->
                    error;
                false ->
                    project_root(Parent)
            end
    end.

field(Name, Map) ->
    maps:get({string, Name}, Map, undefined).

hex(Binary) ->
    lists:flatten([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Binary]).
