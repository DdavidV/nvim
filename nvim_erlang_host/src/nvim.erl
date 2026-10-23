-module(nvim).

-type handler() :: fun(([term()]) -> term()).

-export_type([
    handler/0
]).

%% Generated API functions
-export([
    api/2,
    api/3
]).

%% Synchronous RPC calls
-export([
    call/1,
    call/2,
    call/3
]).

%% Asynchronous RPC calls
-export([
    cast/1,
    cast/2
]).

%% Handler registration
-export([
    register_handler/2,
    unregister_handler/1
]).

-spec api(Function, Params) -> Result when
    Function :: atom(),
    Params :: [term()],
    Result :: {ok, term()} | {error, term()}.
api(Function, Params) ->
    api(Function, Params, 5000).

-spec api(Function, Params, Timeout) -> Result when
    Function :: atom(),
    Params :: [term()],
    Timeout :: pos_integer(),
    Result :: {ok, term()} | {error, term()}.
api(Function, Params, Timeout) when
    is_atom(Function) andalso is_list(Params) andalso is_integer(Timeout) andalso Timeout > 0
->
    %% +1 is the request_id
    case validate_api_request(Function, length(Params) + 1) of
        ok ->
            server_call({api_call, Function, Params, Timeout});
        {error, Reason} ->
            {error, Reason}
    end;
api(_, _, _) ->
    {error, invalid_api_call_arguments}.

-spec call(Method) -> Result when
    Method :: nvim_rpc:rpc_method(),
    Result :: {ok, term()} | {error, term()}.
call(Method) ->
    call(Method, []).

-spec call(Method, Params) -> Result when
    Method :: nvim_rpc:rpc_method(),
    Params :: [term()],
    Result :: {ok, term()} | {error, term()}.
call(Method, Params) ->
    call(Method, Params, 5000).

-spec call(Method, Params, Timeout) -> Result when
    Method :: nvim_rpc:rpc_method(),
    Params :: [term()],
    Timeout :: pos_integer(),
    Result :: {ok, term()} | {error, term()}.
call(Method, Params, Timeout) when
    is_list(Params) andalso is_integer(Timeout) andalso Timeout > 0
->
    server_call({call, Method, Params, Timeout});
call(_, _, _) ->
    {error, invalid_call_arguments}.

-spec cast(Method) -> Result when
    Method :: nvim_rpc:rpc_method(),
    Result :: ok | {error, term()}.
cast(Method) ->
    cast(Method, []).

-spec cast(Method, Params) -> Result when
    Method :: nvim_rpc:rpc_method(),
    Params :: [term()],
    Result :: ok | {error, term()}.
cast(Method, Params) when is_list(Params) ->
    server_cast({Method, Params});
cast(_, _) ->
    {error, invalid_cast_arguments}.

-spec register_handler(Method, Handler) -> Result when
    Method :: nvim_rpc:rpc_method(),
    Handler :: handler(),
    Result :: ok | {error, term()}.
register_handler(Method, Handler) when is_function(Handler, 1) ->
    server_call({register_handler, Method, Handler});
register_handler(_, _) ->
    {error, invalid_handler}.

-spec unregister_handler(Method) -> Result when
    Method :: nvim_rpc:rpc_method(),
    Result :: ok | {error, term()}.
unregister_handler(Method) ->
    server_call({unregister_handler, Method}).

server_call(Request) ->
    case whereis(nvim_host_connection) of
        undefined ->
            {error, host_not_started};
        _Pid ->
            gen_server:call(nvim_host_connection, Request, infinity)
    end.

server_cast(Request) ->
    case whereis(nvim_host_connection) of
        undefined ->
            {error, host_not_started};
        _Pid ->
            gen_server:cast(nvim_host_connection, Request)
    end.

-spec validate_api_request(Function, Arity) -> Result when
    Function :: atom(),
    Arity :: non_neg_integer(),
    Result :: ok | {error, term()}.
validate_api_request(Function, Arity) when is_atom(Function) andalso is_integer(Arity) ->
    case code:ensure_loaded(nvim_api) of
        {module, nvim_api} ->
            case erlang:function_exported(nvim_api, Function, Arity) of
                true -> ok;
                false -> {error, {api_not_available, Function, Arity}}
            end;
        {error, Reason} ->
            {error, {api_bindings_unavailable, Reason}}
    end;
validate_api_request(_, _) ->
    {error, invalid_api_request}.
