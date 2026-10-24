
-module(eval_erlang).

-export([run/0]).

-define(INFO, 2).
-define(Error, 4).

run() ->
    Options = #{
        ~"desc" => ~"Evaluate an Erlang expression",
        ~"nargs" => ~"+"
    },
    nvim:create_user_command(~"Erlang", fun command/1, nvim_rpc:term_to_rpc(Options)).

command(CommandOptions) ->
    Options = nvim_rpc:rpc_to_term(CommandOptions),
    case maps:get(~"args", Options, undefined) of
        undefined ->
            notify(<<"Could not read Erlang command arguments">>, ?Error);
        Args ->
            case eval(Args) of
                {ok, Value} ->
                    notify(format_value(Value), ?INFO);
                {error, Reason} ->
                    notify(format_error(Reason), ?Error)
            end
    end.

eval(Expression) when is_binary(Expression) ->
    eval(binary_to_list(Expression));
eval(Expression) when is_list(Expression) ->
    try
        parse_and_eval(Expression)
    catch
        Class:R:Stacktrace ->
            {error, {eval, Class, R, Stacktrace}}
    end.

parse_and_eval(Expression) ->
    maybe
        Source = ensure_period(string:trim(Expression)),
        {scan, {ok, Tokens, _}} ?= {scan, erl_scan:string(Source)},
        {parse, {ok, Exprs}} ?= {parse, erl_parse:parse_exprs(Tokens)},
        {eval, {value, Value, _Bindings}} = {eval, erl_eval:exprs(Exprs, erl_eval:new_bindings())},
        {ok, Value}
    else
        Error ->
            {error, Error}
    end.

%% Make sure that the source ends with a period.
ensure_period([]) ->
    ".";
ensure_period(Source) ->
    case lists:last(Source) of
        $. -> Source;
        _ -> Source ++ "."
    end.

format_value(Value) ->
    iolist_to_binary(io_lib:format("~tp", [Value])).

format_error({parse, Reason}) ->
    iolist_to_binary(io_lib:format("Parse error: ~tp", [Reason]));
format_error({scan, Reason}) ->
    iolist_to_binary(io_lib:format("Scanner error: ~tp", [Reason]));
format_error({eval, Class, Reason, _Stacktrace}) ->
    iolist_to_binary(io_lib:format("~p: ~tp", [Class, Reason])).

notify(Message, Level) ->
    Options = #{
        ~"title" => ~"Erlang",
        ~"timeout" => 5000
    },
    nvim:api(nvim_notify, [{string, Message}, Level, nvim_rpc:term_to_rpc(Options)]),
    ok.
