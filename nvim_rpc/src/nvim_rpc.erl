-module(nvim_rpc).

-type rpc_request_id() :: integer().
-type rpc_method() :: atom() | binary() | {string, binary()}.
-type rpc_message() ::
    {request, rpc_request_id(), rpc_method(), [term()]}
    | {notification, rpc_method(), [term()]}
    | {response, rpc_request_id(), term(), term()}.

-export_type([rpc_message/0, rpc_request_id/0]).

-export([
    ensure_api_bindings/0,
    ensure_api_bindings/1
]).

-export([
    encode/1,
    decode/1
]).

-export([
    encode_rpc/1,
    decode_rpc/1
]).

-ifdef(TEST).
-export([
    ensure_length/3,
    take_extension_payload/2,
    string_header/1,
    binary_header/1,
    extension_header/1,
    array_header/1,
    map_header/1
]).
-endif.

-define(RPC_REQUEST, 0).
-define(RPC_RESPONSE, 1).
-define(RPC_NOTIFICATION, 2).

-define(MAX_UINT8, 16#ff).
-define(MAX_UINT16, 16#ffff).
-define(MAX_UINT32, 16#ffffffff).
-define(MAX_UINT64, 16#ffffffffffffffff).
-define(BYTE_VALUE_COUNT, 256).
-define(MIN_INT8, -128).
-define(MIN_INT16, -32768).
-define(MIN_INT32, -2147483648).
-define(MIN_INT64, -9223372036854775808).

%% MessagePack constants
-define(MP_POSITIVE_FIXINT_MAX, 16#7f).
-define(MP_NEGATIVE_FIXINT_MIN, -32).
-define(MP_NEGATIVE_FIXINT_MAX, -1).
-define(MP_FIXMAP_PREFIX, 16#80).
-define(MP_FIXMAP_MAX, 16#8f).
-define(MP_FIXARRAY_PREFIX, 16#90).
-define(MP_FIXARRAY_MAX, 16#9f).
-define(MP_FIXSTR_PREFIX, 16#a0).
-define(MP_FIXSTR_MAX, 16#bf).
-define(MP_FIXSTR_LENGTH_MASK, 16#1f).
-define(MP_FIXARRAY_LENGTH_MASK, 16#0f).
-define(MP_FIXMAP_LENGTH_MASK, 16#0f).
-define(MP_NEGATIVE_FIXINT_PREFIX, 16#e0).

-define(MP_NIL, 16#c0).
-define(MP_RESERVED, 16#c1).
-define(MP_FALSE, 16#c2).
-define(MP_TRUE, 16#c3).
-define(MP_BIN8, 16#c4).
-define(MP_BIN16, 16#c5).
-define(MP_BIN32, 16#c6).
-define(MP_EXT8, 16#c7).
-define(MP_EXT16, 16#c8).
-define(MP_EXT32, 16#c9).
-define(MP_FLOAT32, 16#ca).
-define(MP_FLOAT64, 16#cb).
-define(MP_UINT8, 16#cc).
-define(MP_UINT16, 16#cd).
-define(MP_UINT32, 16#ce).
-define(MP_UINT64, 16#cf).
-define(MP_INT8, 16#d0).
-define(MP_INT16, 16#d1).
-define(MP_INT32, 16#d2).
-define(MP_INT64, 16#d3).
-define(MP_FIXEXT1, 16#d4).
-define(MP_FIXEXT2, 16#d5).
-define(MP_FIXEXT4, 16#d6).
-define(MP_FIXEXT8, 16#d7).
-define(MP_FIXEXT16, 16#d8).
-define(MP_STR8, 16#d9).
-define(MP_STR16, 16#da).
-define(MP_STR32, 16#db).
-define(MP_ARRAY16, 16#dc).
-define(MP_ARRAY32, 16#dd).
-define(MP_MAP16, 16#de).
-define(MP_MAP32, 16#df).

-define(MAX_DEPTH, 128).

-spec ensure_api_bindings() -> Result when
    Result :: {ok, module()} | {error, term()}.
ensure_api_bindings() ->
    ensure_api_bindings(os:find_executable("nvim")).

-spec ensure_api_bindings(Executable) -> Result when
    Executable :: file:filename_all() | false,
    Result :: {ok, module()} | {error, term()}.
ensure_api_bindings(false) ->
    {error, nvim_not_found};
ensure_api_bindings(NvimExecutable) ->
    nvim_api_codegen:ensure(NvimExecutable).

-spec encode(Term) -> Result when
    Term :: term(),
    Result :: {ok, binary()} | {error, term()}.
encode(Term) ->
    try
        {ok, iolist_to_binary(encode_value(Term, 0))}
    catch
        throw:Reason ->
            {error, Reason}
    end.

-spec decode(Data) -> Result when
    Data :: term(),
    Result :: {ok, term(), binary()} | {error, term()}.
decode(Binary) when is_binary(Binary) ->
    try
        {Value, Rest} = decode_value(Binary, 0),
        {ok, Value, Rest}
    catch
        throw:Reason ->
            {error, Reason}
    end;
decode(_) ->
    {error, invalid_input}.

-spec encode_rpc(rpc_message()) -> Result when
    Result :: {ok, binary()} | {error, term()}.
encode_rpc(Message) ->
    try
        encode_rpc_message(Message)
    catch
        throw:Reason ->
            {error, Reason}
    end.

encode_rpc_message({request, Id, Method, Params}) when is_integer(Id) andalso is_list(Params) ->
    encode([?RPC_REQUEST, Id, {string, method_binary(Method)}, Params]);
encode_rpc_message({notification, Method, Params}) when is_list(Params) ->
    encode([?RPC_NOTIFICATION, {string, method_binary(Method)}, Params]);
encode_rpc_message({response, Id, Error, Result}) when is_integer(Id) ->
    encode([?RPC_RESPONSE, Id, Error, Result]);
encode_rpc_message(_) ->
    {error, invalid_rpc_message}.

-spec decode_rpc(Binary) -> Result when
    Binary :: binary(),
    Result :: {ok, rpc_message(), binary()} | {error, term()}.
decode_rpc(Binary) ->
    case decode(Binary) of
        {ok, [?RPC_REQUEST, Id, {string, Method}, Params], Rest} when
            is_integer(Id) andalso is_list(Params)
        ->
            {ok, {request, Id, Method, Params}, Rest};
        {ok, [?RPC_RESPONSE, Id, Error, Result], Rest} when is_integer(Id) ->
            {ok, {response, Id, Error, Result}, Rest};
        {ok, [?RPC_NOTIFICATION, {string, Method}, Params], Rest} when
            is_list(Params)
        ->
            {ok, {notification, Method, Params}, Rest};
        {ok, _Message, _Rest} ->
            {error, invalid_rpc_message};
        Error ->
            Error
    end.

encode_value(_, Depth) when Depth > ?MAX_DEPTH ->
    throw(maximum_nesting_depth_exceeded);
encode_value(nil, _) ->
    <<?MP_NIL>>;
encode_value(false, _) ->
    <<?MP_FALSE>>;
encode_value(true, _) ->
    <<?MP_TRUE>>;
encode_value({string, Binary}, _) when is_binary(Binary) ->
    validate_string(Binary);
encode_value(Binary, _) when is_binary(Binary) ->
    encode_binary(Binary);
encode_value({ext, Type, Payload}, _) when
    is_integer(Type) andalso Type >= -128 andalso Type =< 127 andalso is_binary(Payload)
->
    encode_extension(Type, Payload);
encode_value(Integer, _) when
    is_integer(Integer) andalso Integer >= 0 andalso Integer =< ?MP_POSITIVE_FIXINT_MAX
->
    <<Integer>>;
encode_value(Integer, _) when
    is_integer(Integer) andalso
        Integer >= ?MP_NEGATIVE_FIXINT_MIN andalso
        Integer =< ?MP_NEGATIVE_FIXINT_MAX
->
    <<Integer:8/signed>>;
encode_value(Integer, _) when
    is_integer(Integer) andalso Integer >= 0 andalso Integer =< ?MAX_UINT8
->
    <<?MP_UINT8, Integer:8>>;
encode_value(Integer, _) when
    is_integer(Integer) andalso Integer >= 0 andalso Integer =< ?MAX_UINT16
->
    <<?MP_UINT16, Integer:16/unsigned-big>>;
encode_value(Integer, _) when
    is_integer(Integer) andalso Integer >= 0 andalso Integer =< ?MAX_UINT32
->
    <<?MP_UINT32, Integer:32/unsigned-big>>;
encode_value(Integer, _) when
    is_integer(Integer) andalso Integer >= 0 andalso Integer =< ?MAX_UINT64
->
    <<?MP_UINT64, Integer:64/unsigned-big>>;
encode_value(Integer, _) when
    is_integer(Integer) andalso Integer >= ?MIN_INT8 andalso Integer < 0
->
    <<?MP_INT8, Integer:8/signed>>;
encode_value(Integer, _) when
    is_integer(Integer) andalso Integer >= ?MIN_INT16 andalso Integer < ?MIN_INT8
->
    <<?MP_INT16, Integer:16/signed-big>>;
encode_value(Integer, _) when
    is_integer(Integer) andalso Integer >= ?MIN_INT32 andalso Integer < ?MIN_INT16
->
    <<?MP_INT32, Integer:32/signed-big>>;
encode_value(Integer, _) when
    is_integer(Integer) andalso Integer >= ?MIN_INT64 andalso Integer < ?MIN_INT32
->
    <<?MP_INT64, Integer:64/signed-big>>;
encode_value(Integer, _) when is_integer(Integer) ->
    throw(integer_out_of_range);
encode_value(Float, _) when is_float(Float) ->
    <<?MP_FLOAT64, Float:64/float-big>>;
encode_value(List, Depth) when is_list(List) ->
    case is_proper_list(List) of
        true -> encode_array(List, Depth + 1);
        false -> throw(improper_list)
    end;
encode_value(Map, Depth) when is_map(Map) ->
    encode_map(maps:to_list(Map), Depth + 1);
encode_value(_, _) ->
    throw(unsupported_type).

encode_string(Binary) ->
    [string_header(byte_size(Binary)), Binary].

string_header(Size) ->
    ensure_length(Size, ?MAX_UINT32, string_too_large),
    case Size of
        N when N < 32 -> <<(?MP_FIXSTR_PREFIX bor N)>>;
        N when N =< ?MAX_UINT8 -> <<?MP_STR8, N:8>>;
        N when N =< ?MAX_UINT16 -> <<?MP_STR16, N:16/unsigned-big>>;
        N -> <<?MP_STR32, N:32/unsigned-big>>
    end.

encode_binary(Binary) ->
    Size = byte_size(Binary),
    [binary_header(Size), Binary].

binary_header(Size) ->
    ensure_length(Size, ?MAX_UINT32, binary_too_large),
    case Size of
        N when N =< ?MAX_UINT8 -> <<?MP_BIN8, N:8>>;
        N when N =< ?MAX_UINT16 -> <<?MP_BIN16, N:16/unsigned-big>>;
        N -> <<?MP_BIN32, N:32/unsigned-big>>
    end.

encode_extension(Type, Payload) ->
    Size = byte_size(Payload),
    [extension_header(Size), <<Type:8/signed>>, Payload].

extension_header(1) -> <<?MP_FIXEXT1>>;
extension_header(2) -> <<?MP_FIXEXT2>>;
extension_header(4) -> <<?MP_FIXEXT4>>;
extension_header(8) -> <<?MP_FIXEXT8>>;
extension_header(16) -> <<?MP_FIXEXT16>>;
extension_header(Size) when Size =< ?MAX_UINT8 -> <<?MP_EXT8, Size:8>>;
extension_header(Size) when Size =< ?MAX_UINT16 -> <<?MP_EXT16, Size:16/unsigned-big>>;
extension_header(Size) when Size =< ?MAX_UINT32 -> <<?MP_EXT32, Size:32/unsigned-big>>;
extension_header(_) -> throw(extension_too_large).

encode_array(List, Depth) ->
    Size = length(List),
    [array_header(Size), [encode_value(Value, Depth) || Value <- List]].

array_header(Size) when Size < 16 -> <<(?MP_FIXARRAY_PREFIX bor Size)>>;
array_header(Size) when Size =< ?MAX_UINT16 -> <<?MP_ARRAY16, Size:16/unsigned-big>>;
array_header(Size) when Size =< ?MAX_UINT32 -> <<?MP_ARRAY32, Size:32/unsigned-big>>;
array_header(_) -> throw(array_too_large).

encode_map(Pairs, Depth) ->
    Size = length(Pairs),
    [
        map_header(Size),
        [
            [encode_value(Key, Depth), encode_value(Value, Depth)]
         || {Key, Value} <- Pairs
        ]
    ].

map_header(Size) when Size < 16 -> <<(?MP_FIXMAP_PREFIX bor Size)>>;
map_header(Size) when Size =< ?MAX_UINT16 -> <<?MP_MAP16, Size:16/unsigned-big>>;
map_header(Size) when Size =< ?MAX_UINT32 -> <<?MP_MAP32, Size:32/unsigned-big>>;
map_header(_) -> throw(map_too_large).

decode_value(_, Depth) when Depth > ?MAX_DEPTH ->
    throw(maximum_nesting_depth_exceeded);
decode_value(<<>>, _) ->
    throw(incomplete);
decode_value(<<Tag, Rest/binary>>, _Depth) when Tag =< ?MP_POSITIVE_FIXINT_MAX ->
    {Tag, Rest};
decode_value(<<Tag, Rest/binary>>, _) when Tag >= ?MP_NEGATIVE_FIXINT_PREFIX ->
    {Tag - ?BYTE_VALUE_COUNT, Rest};
decode_value(<<Tag, Rest/binary>>, _Depth) when
    Tag >= ?MP_FIXSTR_PREFIX andalso Tag =< ?MP_FIXSTR_MAX
->
    take_string_size(Rest, Tag band ?MP_FIXSTR_LENGTH_MASK);
decode_value(<<Tag, Rest/binary>>, Depth) when
    Tag >= ?MP_FIXARRAY_PREFIX andalso Tag =< ?MP_FIXARRAY_MAX
->
    take_n_array(Rest, Tag band ?MP_FIXARRAY_LENGTH_MASK, Depth + 1, []);
decode_value(<<Tag, Rest/binary>>, Depth) when
    Tag >= ?MP_FIXMAP_PREFIX andalso Tag =< ?MP_FIXMAP_MAX
->
    take_n_map(Rest, Tag band ?MP_FIXMAP_LENGTH_MASK, Depth + 1, #{});
decode_value(<<?MP_NIL, Rest/binary>>, _) ->
    {nil, Rest};
decode_value(<<?MP_FALSE, Rest/binary>>, _) ->
    {false, Rest};
decode_value(<<?MP_TRUE, Rest/binary>>, _) ->
    {true, Rest};
decode_value(<<?MP_BIN8, Rest/binary>>, _) ->
    take_binary(Rest, 8);
decode_value(<<?MP_BIN16, Rest/binary>>, _) ->
    take_binary(Rest, 16);
decode_value(<<?MP_BIN32, Rest/binary>>, _) ->
    take_binary(Rest, 32);
decode_value(<<?MP_EXT8, Rest/binary>>, _) ->
    take_extension(Rest, 8);
decode_value(<<?MP_EXT16, Rest/binary>>, _) ->
    take_extension(Rest, 16);
decode_value(<<?MP_EXT32, Rest/binary>>, _) ->
    take_extension(Rest, 32);
decode_value(<<?MP_FLOAT32, Rest/binary>>, _) ->
    take_float(Rest, 32);
decode_value(<<?MP_FLOAT64, Rest/binary>>, _) ->
    take_float(Rest, 64);
decode_value(<<?MP_UINT8, Rest/binary>>, _) ->
    take_integer(Rest, 8, unsigned);
decode_value(<<?MP_UINT16, Rest/binary>>, _) ->
    take_integer(Rest, 16, unsigned);
decode_value(<<?MP_UINT32, Rest/binary>>, _) ->
    take_integer(Rest, 32, unsigned);
decode_value(<<?MP_UINT64, Rest/binary>>, _) ->
    take_integer(Rest, 64, unsigned);
decode_value(<<?MP_INT8, Rest/binary>>, _) ->
    take_integer(Rest, 8, signed);
decode_value(<<?MP_INT16, Rest/binary>>, _) ->
    take_integer(Rest, 16, signed);
decode_value(<<?MP_INT32, Rest/binary>>, _) ->
    take_integer(Rest, 32, signed);
decode_value(<<?MP_INT64, Rest/binary>>, _) ->
    take_integer(Rest, 64, signed);
decode_value(<<?MP_STR8, Rest/binary>>, _Depth) ->
    take_string(Rest, 8);
decode_value(<<?MP_STR16, Rest/binary>>, _Depth) ->
    take_string(Rest, 16);
decode_value(<<?MP_STR32, Rest/binary>>, _Depth) ->
    take_string(Rest, 32);
decode_value(<<?MP_ARRAY16, Rest/binary>>, Depth) ->
    take_array(Rest, 16, Depth + 1);
decode_value(<<?MP_ARRAY32, Rest/binary>>, Depth) ->
    take_array(Rest, 32, Depth + 1);
decode_value(<<?MP_MAP16, Rest/binary>>, Depth) ->
    take_map(Rest, 16, Depth + 1);
decode_value(<<?MP_MAP32, Rest/binary>>, Depth) ->
    take_map(Rest, 32, Depth + 1);
decode_value(<<?MP_RESERVED, _/binary>>, _) ->
    throw(reserved_messagepack_type);
decode_value(<<?MP_FIXEXT1, Rest/binary>>, _) ->
    take_fixed_extension(Rest, 1);
decode_value(<<?MP_FIXEXT2, Rest/binary>>, _) ->
    take_fixed_extension(Rest, 2);
decode_value(<<?MP_FIXEXT4, Rest/binary>>, _) ->
    take_fixed_extension(Rest, 4);
decode_value(<<?MP_FIXEXT8, Rest/binary>>, _) ->
    take_fixed_extension(Rest, 8);
decode_value(<<?MP_FIXEXT16, Rest/binary>>, _) ->
    take_fixed_extension(Rest, 16).

take_integer(Binary, Bits, Sign) ->
    case take_bytes(Binary, Bits div 8) of
        {ok, ValueBytes, Rest} ->
            Value =
                case Sign of
                    signed -> decode_signed(ValueBytes);
                    unsigned -> decode_unsigned(ValueBytes)
                end,
            {Value, Rest};
        incomplete ->
            throw(incomplete)
    end.

take_float(Binary, Bits) ->
    Size = Bits div 8,
    case take_bytes(Binary, Size) of
        {ok, FloatBytes, Rest} when Bits =:= 32 ->
            <<Value:32/float-big>> = FloatBytes,
            {Value, Rest};
        {ok, FloatBytes, Rest} ->
            <<Value:64/float-big>> = FloatBytes,
            {Value, Rest};
        incomplete ->
            throw(incomplete)
    end.

take_string(Binary, LengthBits) ->
    case take_length(Binary, LengthBits) of
        {ok, Size, Rest} -> take_string_value(Rest, Size);
        incomplete -> throw(incomplete)
    end.

take_string_size(Binary, Size) ->
    take_string_value(Binary, Size).

take_string_value(Binary, Size) ->
    case take_bytes(Binary, Size) of
        {ok, Value, Rest} ->
            ensure_valid_utf8(Value),
            {{string, Value}, Rest};
        incomplete ->
            throw(incomplete)
    end.

take_binary(Binary, LengthBits) ->
    case take_length(Binary, LengthBits) of
        {ok, Size, Rest} ->
            case take_bytes(Rest, Size) of
                {ok, Value, Tail} -> {Value, Tail};
                incomplete -> throw(incomplete)
            end;
        incomplete ->
            throw(incomplete)
    end.

take_extension(Binary, LengthBits) ->
    case take_length(Binary, LengthBits) of
        {ok, Size, Rest} -> take_extension_payload(Rest, Size);
        incomplete -> throw(incomplete)
    end.

take_fixed_extension(Binary, Size) ->
    take_extension_payload(Binary, Size).

take_extension_payload(<<Type:8/signed, Rest/binary>>, Size) ->
    case take_bytes(Rest, Size) of
        {ok, Payload, Tail} -> {{ext, Type, Payload}, Tail};
        incomplete -> throw(incomplete)
    end;
take_extension_payload(_, _) ->
    throw(incomplete).

take_array(Binary, LengthBits, Depth) ->
    case take_length(Binary, LengthBits) of
        {ok, Size, Rest} -> take_n_array(Rest, Size, Depth, []);
        incomplete -> throw(incomplete)
    end.

take_n_array(Rest, 0, _Depth, Acc) ->
    {lists:reverse(Acc), Rest};
take_n_array(Binary, Count, Depth, Acc) when Count > 0 ->
    {Value, Rest} = decode_value(Binary, Depth),
    take_n_array(Rest, Count - 1, Depth, [Value | Acc]).

take_map(Binary, LengthBits, Depth) ->
    case take_length(Binary, LengthBits) of
        {ok, Size, Rest} -> take_n_map(Rest, Size, Depth, #{});
        incomplete -> throw(incomplete)
    end.

take_n_map(Rest, 0, _Depth, Acc) ->
    {Acc, Rest};
take_n_map(Binary, Count, Depth, Acc) when Count > 0 ->
    {Key, AfterKey} = decode_value(Binary, Depth),
    {Value, Rest} = decode_value(AfterKey, Depth),
    take_n_map(Rest, Count - 1, Depth, maps:put(Key, Value, Acc)).

take_length(Binary, Bits) ->
    Size = Bits div 8,
    case take_bytes(Binary, Size) of
        {ok, LengthBytes, Rest} -> {ok, decode_unsigned(LengthBytes), Rest};
        incomplete -> incomplete
    end.

take_bytes(Binary, Size) when byte_size(Binary) >= Size ->
    <<Value:Size/binary, Rest/binary>> = Binary,
    {ok, Value, Rest};
take_bytes(_, _) ->
    incomplete.

decode_unsigned(<<Value:8/unsigned>>) -> Value;
decode_unsigned(<<Value:16/unsigned-big>>) -> Value;
decode_unsigned(<<Value:32/unsigned-big>>) -> Value;
decode_unsigned(<<Value:64/unsigned-big>>) -> Value.

decode_signed(<<Value:8/signed>>) -> Value;
decode_signed(<<Value:16/signed-big>>) -> Value;
decode_signed(<<Value:32/signed-big>>) -> Value;
decode_signed(<<Value:64/signed-big>>) -> Value.

method_binary(Method) when is_atom(Method) ->
    atom_to_binary(Method, utf8);
method_binary(Method) when is_binary(Method) ->
    Method;
method_binary({string, Method}) when is_binary(Method) ->
    Method;
method_binary(_) ->
    throw(invalid_method).

ensure_length(Size, Maximum, _Error) when Size =< Maximum -> ok;
ensure_length(_, _, Error) -> throw(Error).

validate_string(Binary) ->
    ensure_valid_utf8(Binary),
    encode_string(Binary).

ensure_valid_utf8(Binary) ->
    case unicode:characters_to_binary(Binary, utf8, utf8) of
        Binary -> ok;
        _ -> throw(invalid_utf8_string)
    end.

is_proper_list(List) ->
    try length(List) of
        _ -> true
    catch
        error:badarg -> false
    end.
