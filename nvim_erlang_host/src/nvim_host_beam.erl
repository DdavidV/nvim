-module(nvim_host_beam).

-export([handle_call/1]).

-spec handle_call(Arguments) -> Result when
    Arguments :: [
        ModuleValue ::
            {string, binary()} | FunctionValue :: {string, binary()} | ArgsValue :: [term()]
    ],
    Result :: {ok, term()} | {error, term()}.
handle_call([{string, ModuleName}, {string, FunctionName}, Args]) when is_list(Args) ->
    try
        %% Only resolve atoms that already exist in the VM.
        Module = binary_to_existing_atom(ModuleName, utf8),
        Function = binary_to_existing_atom(FunctionName, utf8),
        case code:ensure_loaded(Module) of
            {module, Module} ->
                invoke_exported(Module, Function, Args);
            {error, _Reason} ->
                {error, {string, <<"module_not_found">>}}
        end
    catch
        error:badarg ->
            {error, {string, <<"unknown_module_or_function">>}};
        Class:Reason:Stack ->
            logger:error("BEAM call resolution failed: ~p:~p~n~p", [
                Class, Reason, Stack
            ]),
            {error, {string, <<"beam_call_failed">>}}
    end;
handle_call(_Params) ->
    {error, {string, <<"invalid_arguments">>}}.

invoke_exported(Module, Function, Args) ->
    Arity = length(Args),
    case erlang:function_exported(Module, Function, Arity) of
        true ->
            try
                ErlangArgs = [nvim_rpc:rpc_to_erlang(Arg) || Arg <- Args],
                Result = apply(Module, Function, ErlangArgs),
                {ok, nvim_rpc:erlang_to_rpc(Result)}
            catch
                Class:Reason:Stack ->
                    logger:error("BEAM function call failed: ~p:~p/~p: ~p:~p~n~p", [
                        Module, Function, Arity, Class, Reason, Stack
                    ]),
                    {error, {string, <<"beam_call_failed">>}}
            end;
        false ->
            {error, {string, <<"function_not_exported">>}}
    end.
