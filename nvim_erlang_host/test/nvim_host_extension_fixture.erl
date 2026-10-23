-module(nvim_host_extension_fixture).

-export([
    run/0
]).

run() ->
    TestPid = persistent_term:get(nvim_host_extension_test_pid),
    TestPid ! {extension_started, ?MODULE},
    ok.
