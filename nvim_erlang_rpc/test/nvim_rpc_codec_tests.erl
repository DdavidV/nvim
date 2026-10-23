-module(nvim_rpc_codec_tests).

-include_lib("eunit/include/eunit.hrl").

primitive_roundtrip_test() ->
    lists:foreach(
        fun roundtrip/1,
        [
            nil,
            false,
            true,
            0,
            127,
            128,
            255,
            256,
            65535,
            65536,
            16#ffffffff,
            16#100000000,
            16#ffffffffffffffff,
            -1,
            -32,
            -33,
            -128,
            -129,
            -32768,
            -32769,
            -2147483648,
            -2147483649,
            -9223372036854775808,
            1.5,
            -1.25,
            {string, <<"Neovim">>},
            <<0, 1, 255>>
        ]
    ).

container_roundtrip_test() ->
    lists:foreach(
        fun roundtrip/1,
        [
            [],
            [1, {string, <<"text">>}, nil, true],
            lists:seq(1, 16),
            #{},
            #{{string, <<"name">>} => {string, <<"value">>}},
            {ext, 1, <<0, 0, 0, 42>>},
            {ext, -1, <<1>>},
            {ext, 127, <<0:128>>},
            {ext, -128, <<0:24>>},
            nested(128)
        ]
    ).

string_header_boundaries_test() ->
    lists:foreach(
        fun(Size) -> roundtrip({string, binary:copy(<<$a>>, Size)}) end,
        [31, 32, 255, 256, 65535, 65536]
    ).

binary_header_boundaries_test() ->
    lists:foreach(
        fun(Size) -> roundtrip(binary:copy(<<$a>>, Size)) end,
        [255, 256, 65535, 65536]
    ).

array_header_boundaries_test() ->
    lists:foreach(
        fun(Size) -> roundtrip(lists:seq(1, Size)) end,
        [15, 16, 65535, 65536]
    ).

map_header_boundaries_test() ->
    lists:foreach(
        fun(Size) ->
            Map = maps:from_list([{Index, Index} || Index <- lists:seq(1, Size)]),
            roundtrip(Map)
        end,
        [15, 16, 65535, 65536]
    ).

extension_header_boundaries_test() ->
    lists:foreach(
        fun(Size) -> roundtrip({ext, -2, binary:copy(<<$x>>, Size)}) end,
        [1, 2, 4, 8, 16, 3, 255, 256, 65535, 65536]
    ).

header_size_limit_test() ->
    ?assertThrow(string_too_large, nvim_rpc:string_header(16#100000000)),
    ?assertThrow(binary_too_large, nvim_rpc:binary_header(16#100000000)),
    ?assertThrow(extension_too_large, nvim_rpc:extension_header(16#100000000)),
    ?assertThrow(array_too_large, nvim_rpc:array_header(16#100000000)),
    ?assertThrow(map_too_large, nvim_rpc:map_header(16#100000000)),
    ?assertThrow(length_error, nvim_rpc:ensure_length(2, 1, length_error)).

float32_decode_test() ->
    ?assertEqual({ok, 1.5, <<>>}, nvim_rpc:decode(<<16#ca, 1.5:32/float-big>>)).

extension_payload_truncation_test() ->
    ?assertThrow(incomplete, nvim_rpc:take_extension_payload(<<>>, 1)).

incremental_decode_test() ->
    {ok, First} = nvim_rpc:encode({string, <<"first">>}),
    {ok, Second} = nvim_rpc:encode([1, 2]),
    {ok, {string, <<"first">>}, Second} =
        nvim_rpc:decode(<<First/binary, Second/binary>>),
    {ok, [1, 2], <<>>} = nvim_rpc:decode(Second).

invalid_inputs_test() ->
    ?assertEqual({error, invalid_input}, nvim_rpc:decode(not_binary)),
    ?assertEqual({error, incomplete}, nvim_rpc:decode(<<>>)),
    ?assertEqual({error, incomplete}, nvim_rpc:decode(<<16#d9>>)),
    ?assertEqual({error, incomplete}, nvim_rpc:decode(<<16#d9, 2, $a>>)),
    ?assertEqual({error, incomplete}, nvim_rpc:decode(<<16#cc>>)),
    ?assertEqual({error, incomplete}, nvim_rpc:decode(<<16#ca>>)),
    ?assertEqual({error, incomplete}, nvim_rpc:decode(<<16#c4, 1>>)),
    ?assertEqual({error, incomplete}, nvim_rpc:decode(<<16#c4>>)),
    ?assertEqual({error, incomplete}, nvim_rpc:decode(<<16#c7>>)),
    ?assertEqual({error, incomplete}, nvim_rpc:decode(<<16#c7, 1, 0>>)),
    ?assertEqual({error, incomplete}, nvim_rpc:decode(<<16#dc>>)),
    ?assertEqual({error, incomplete}, nvim_rpc:decode(<<16#de>>)),
    ?assertEqual({error, incomplete}, nvim_rpc:decode(<<16#92, 1>>)),
    ?assertEqual({error, reserved_messagepack_type}, nvim_rpc:decode(<<16#c1>>)),
    ?assertEqual({error, invalid_utf8_string}, nvim_rpc:decode(<<16#a1, 16#ff>>)),
    ?assertEqual({error, invalid_utf8_string}, nvim_rpc:encode({string, <<16#ff>>})),
    ?assertEqual({error, integer_out_of_range}, nvim_rpc:encode(1 bsl 64)),
    ?assertEqual({error, integer_out_of_range}, nvim_rpc:encode(-1 bsl 63 - 1)),
    ?assertEqual({error, improper_list}, nvim_rpc:encode([1 | broken])),
    ?assertEqual({error, unsupported_type}, nvim_rpc:encode(self())),
    ?assertEqual({error, unsupported_type}, nvim_rpc:encode({not_supported})),
    ?assertEqual({error, maximum_nesting_depth_exceeded}, nvim_rpc:encode(nested(130))),
    ?assertEqual(
        {error, maximum_nesting_depth_exceeded},
        nvim_rpc:decode(<<
            (binary:copy(<<16#91>>, 130))/binary,
            0
        >>)
    ).

invalid_extension_test() ->
    ?assertEqual({error, unsupported_type}, nvim_rpc:encode({ext, 128, <<1>>})),
    ?assertEqual({error, unsupported_type}, nvim_rpc:encode({ext, 0, not_binary})).

roundtrip(Term) ->
    {ok, Binary} = nvim_rpc:encode(Term),
    ?assertEqual({ok, Term, <<>>}, nvim_rpc:decode(Binary)).

nested(0) ->
    0;
nested(Depth) ->
    [nested(Depth - 1)].
