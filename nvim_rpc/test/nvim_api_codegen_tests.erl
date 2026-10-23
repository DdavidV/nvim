-module(nvim_api_codegen_tests).

-include_lib("eunit/include/eunit.hrl").

ensure_bindings_test_() ->
    case os:find_executable("nvim") of
        false ->
            [];
        Nvim ->
            {timeout, 60, fun() ->
                {ok, nvim_api} = nvim_rpc:ensure_api_bindings(Nvim),
                ?assertMatch({_, _, _}, nvim_api:api_version()),
                ?assertMatch({ok, _}, nvim_api:type_id(<<"Buffer">>)),
                {ok, BufferType} = nvim_api:type_id(<<"Buffer">>),
                ?assertEqual({ok, <<"Buffer">>}, nvim_api:type_name(BufferType)),
                ?assertEqual(error, nvim_api:type_id(<<"Unknown">>)),
                ?assertEqual(error, nvim_api:type_name(255)),
                {ok, Packet} = nvim_api:nvim_get_current_buf(17),
                ?assertEqual(
                    {ok, {request, 17, <<"nvim_get_current_buf">>, []}, <<>>},
                    nvim_rpc:decode_rpc(Packet)
                )
            end}
    end.

missing_executable_test() ->
    Path = os:getenv("PATH"),
    try
        true = os:putenv("PATH", ""),
        ?assertEqual({error, nvim_not_found}, nvim_rpc:ensure_api_bindings())
    after
        case Path of
            false -> os:unsetenv("PATH");
            _ -> os:putenv("PATH", Path)
        end
    end,
    ?assertEqual(
        {error, {nvim_executable_not_found, "/no/such/nvim"}},
        nvim_api_codegen:read_api_info("/no/such/nvim")
    ),
    ?assertEqual({error, nvim_not_found}, nvim_rpc:ensure_api_bindings(false)),
    ?assertEqual({error, invalid_nvim_executable}, nvim_api_codegen:ensure(42)).

function_metadata_test() ->
    Valid = function(<<"nvim_valid">>, [[<<"Integer">>, <<"value">>]]),
    ?assertEqual({ok, [{<<"nvim_valid">>, 1}]}, nvim_api_codegen:collect_functions([Valid], [])),
    ?assertEqual({ok, []}, nvim_api_codegen:collect_functions([], [])),
    ?assertEqual(
        {error, {invalid_api_function, <<"Bad">>}},
        nvim_api_codegen:collect_functions([function(<<"Bad">>, [])], [])
    ),
    ?assertEqual(
        {error, {invalid_api_function, <<"nvim_bad">>}},
        nvim_api_codegen:collect_functions(
            [
                #{
                    {string, <<"name">>} => {string, <<"nvim_bad">>},
                    {string, <<"parameters">>} =>
                        [[{string, <<"Type">>}, {string, <<"Name">>}, {string, <<"Extra">>}]]
                }
            ],
            []
        )
    ),
    ?assertEqual(
        {error, invalid_api_function_metadata},
        nvim_api_codegen:collect_functions([#{}], [])
    ),
    ?assertEqual(
        {error, invalid_api_function_metadata},
        nvim_api_codegen:collect_functions([malformed], [])
    ).

type_metadata_test() ->
    Valid = #{{string, <<"id">>} => 2},
    ?assertEqual(
        {ok, [{<<"Buffer">>, 2}]},
        nvim_api_codegen:collect_types([{{string, <<"Buffer">>}, Valid}], [])
    ),
    ?assertEqual({ok, []}, nvim_api_codegen:collect_types([], [])),
    ?assertEqual(
        {error, {invalid_api_type, <<"bad">>}},
        nvim_api_codegen:collect_types(
            [{{string, <<"bad">>}, #{{string, <<"id">>} => 1}}],
            []
        )
    ),
    ?assertEqual(
        {error, {invalid_api_type, <<"Buffer">>}},
        nvim_api_codegen:collect_types(
            [{{string, <<"Buffer">>}, #{{string, <<"id">>} => 128}}],
            []
        )
    ),
    ?assertEqual(
        {error, invalid_api_type_metadata},
        nvim_api_codegen:collect_types([not_a_type], [])
    ).

metadata_shape_test() ->
    ?assertEqual(
        {error, invalid_api_info_shape},
        nvim_api_codegen:generate_bindings(<<>>, #{{string, <<"version">>} => #{}})
    ),
    BadVersion = version(<<"wrong">>, 0, 0),
    BadFunctions = #{
        {string, <<"version">>} => BadVersion,
        {string, <<"functions">>} => [],
        {string, <<"types">>} => #{}
    },
    ?assertEqual(
        {error, invalid_api_version}, nvim_api_codegen:generate_bindings(<<>>, BadFunctions)
    ),
    BadTypes = #{
        {string, <<"version">>} => version(0, 1, 0),
        {string, <<"functions">>} => [],
        {string, <<"types">>} => [bad]
    },
    ?assertEqual(
        {error, invalid_api_info_shape}, nvim_api_codegen:generate_bindings(<<>>, BadTypes)
    ),
    BadFunction = #{
        {string, <<"version">>} => version(0, 1, 0),
        {string, <<"functions">>} => [bad],
        {string, <<"types">>} => #{}
    },
    ?assertEqual(
        {error, invalid_api_function_metadata},
        nvim_api_codegen:generate_bindings(<<>>, BadFunction)
    ).

renderer_test() ->
    Source = nvim_api_codegen:render_module(
        <<1, 2, 255>>,
        {0, 12, 6},
        [{<<"nvim_example">>, 2}],
        [{<<"Buffer">>, 0}]
    ),
    ?assertMatch(
        {match, _},
        re:run(Source, <<"nvim_example\\(RequestId, Arg1, Arg2\\)">>)
    ),
    ?assertNotEqual(nomatch, binary:match(Source, <<"type_id(<<\"Buffer\">>)">>)).

api_info_decoding_test() ->
    InvalidNvim = executable_script(<<"printf '\\301'">>),
    TrailingDataNvim = executable_script(<<"printf '\\300\\300'">>),
    FailedNvim = executable_script(<<"exit 7">>),
    try
        ?assertEqual(
            {ok, InvalidNvim},
            nvim_api_codegen:resolve_executable(list_to_binary(InvalidNvim))
        ),
        ?assertEqual(
            {error, {invalid_api_info, reserved_messagepack_type}},
            nvim_api_codegen:ensure(InvalidNvim)
        ),
        ?assertEqual(
            {error, trailing_api_info_data},
            nvim_api_codegen:ensure(TrailingDataNvim)
        ),
        ?assertEqual(
            {error, {nvim_api_info_failed, 7}},
            nvim_api_codegen:ensure(FailedNvim)
        ),
        assert_path_resolution(InvalidNvim)
    after
        file:delete(InvalidNvim),
        file:delete(TrailingDataNvim),
        file:delete(FailedNvim)
    end.

assert_path_resolution(Executable) ->
    Path = os:getenv("PATH"),
    try
        true = os:putenv("PATH", filename:dirname(Executable)),
        ?assertEqual(
            {ok, Executable},
            nvim_api_codegen:resolve_executable(filename:basename(Executable))
        ),
        true = os:putenv("PATH", ""),
        ?assertEqual(
            error,
            nvim_api_codegen:resolve_executable(filename:basename(Executable))
        )
    after
        case Path of
            false -> os:unsetenv("PATH");
            _ -> os:putenv("PATH", Path)
        end
    end.

invalid_api_info_input_test() ->
    ?assertEqual(
        {error, invalid_api_info_shape},
        nvim_api_codegen:generate_bindings(<<>>, not_a_map)
    ).

project_root_not_found_test() ->
    ?assertEqual(error, nvim_api_codegen:project_root("/")),
    ?assertEqual(
        {error, nvim_rpc_project_root_not_found},
        nvim_api_codegen:cache_dir(<<>>, "/")
    ).

port_exit_test() ->
    PreviousTrapExit = process_flag(trap_exit, true),
    try
        Port = spawn_link(fun() ->
            receive
                stop -> ok
            after 60000 -> ok
            end
        end),
        exit(Port, forced_failure),
        ?assertEqual(
            {error, {nvim_port_failed, forced_failure}},
            nvim_api_codegen:collect_api_info(Port, [])
        )
    after
        process_flag(trap_exit, PreviousTrapExit)
    end.

cache_path_errors_test() ->
    CacheFile = executable_script(<<"exit 0">>),
    CacheDir = temp_directory(),
    EbinDir = filename:join(CacheDir, "ebin"),
    BeamPath = filename:join(EbinDir, "nvim_api.beam"),
    ok = filelib:ensure_dir(BeamPath),
    ok = file:make_dir(BeamPath),
    try
        ?assertMatch(
            {error, {cache_directory_failed, _}},
            nvim_api_codegen:compile_or_load(CacheFile, <<>>, {0, 0, 0}, [], [])
        ),
        ?assertMatch(
            {error, {cache_read_failed, _}},
            nvim_api_codegen:compile_or_load(CacheDir, <<>>, {0, 0, 0}, [], [])
        )
    after
        file:delete(CacheFile),
        file:del_dir_r(CacheDir)
    end.

corrupt_cache_test() ->
    CacheDir = temp_directory(),
    EbinDir = filename:join(CacheDir, "ebin"),
    BeamPath = filename:join(EbinDir, "nvim_api.beam"),
    ok = filelib:ensure_dir(BeamPath),
    ok = file:write_file(BeamPath, <<"not a beam">>),
    try
        ?assertEqual(
            {error, api_binding_compile_failed},
            nvim_api_codegen:compile_or_load(
                CacheDir,
                <<>>,
                {0, 0, 0},
                [{<<"invalid-name">>, 0}],
                []
            )
        )
    after
        file:del_dir_r(CacheDir)
    end.

load_binding_errors_test() ->
    EbinDir = temp_directory(),
    ok = file:write_file(filename:join(EbinDir, "nvim_api.beam"), <<"not a beam">>),
    try
        ?assertMatch(
            {error, {api_binding_load_failed, _}},
            nvim_api_codegen:load_bindings(EbinDir)
        )
    after
        code:del_path(EbinDir),
        file:del_dir_r(EbinDir)
    end.

write_error_test() ->
    CacheDir = temp_directory(),
    try
        ?assertMatch(
            {error, {api_binding_write_failed, _}},
            nvim_api_codegen:write_and_compile(
                CacheDir,
                CacheDir,
                <<>>,
                {0, 0, 0},
                [],
                []
            )
        )
    after
        file:del_dir_r(CacheDir)
    end.

function(Name, Parameters) ->
    #{
        {string, <<"name">>} => {string, Name},
        {string, <<"parameters">>} =>
            [[{string, Type}, {string, Param}] || [Type, Param] <- Parameters]
    }.

version(Major, Minor, Patch) ->
    #{
        {string, <<"major">>} => Major,
        {string, <<"minor">>} => Minor,
        {string, <<"patch">>} => Patch
    }.

executable_script(Command) ->
    Path = temp_path(),
    ok = file:write_file(Path, ["#!/bin/sh\n", Command, "\n"]),
    ok = file:change_mode(Path, 8#700),
    Path.

temp_directory() ->
    Path = temp_path(),
    ok = file:make_dir(Path),
    Path.

temp_path() ->
    filename:join(
        os:getenv("TMPDIR", "/tmp"),
        "nvim-rpc-test-" ++
            integer_to_list(erlang:system_time(nanosecond)) ++
            "-" ++ integer_to_list(erlang:unique_integer([positive]))
    ).
