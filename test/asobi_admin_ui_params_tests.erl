-module(asobi_admin_ui_params_tests).

-include_lib("eunit/include/eunit.hrl").

int_param_test_() ->
    [
        ?_assertEqual(50, asobi_admin_ui_params:int_param([], ~"limit", 50, 200)),
        ?_assertEqual(
            50, asobi_admin_ui_params:int_param([{~"limit", ~"abc"}], ~"limit", 50, 200)
        ),
        ?_assertEqual(
            50, asobi_admin_ui_params:int_param([{~"limit", ~"5.5"}], ~"limit", 50, 200)
        ),
        ?_assertEqual(
            0, asobi_admin_ui_params:int_param([{~"offset", ~"-5"}], ~"offset", 0, 1_000_000)
        ),
        ?_assertEqual(
            200, asobi_admin_ui_params:int_param([{~"limit", ~"100000000"}], ~"limit", 50, 200)
        ),
        ?_assertEqual(
            30, asobi_admin_ui_params:int_param([{~"limit", ~"30"}], ~"limit", 50, 200)
        )
    ].

int_test_() ->
    [
        ?_assertEqual({ok, 42}, asobi_admin_ui_params:int(~"42")),
        ?_assertEqual({ok, -1}, asobi_admin_ui_params:int(~"-1")),
        ?_assertEqual(error, asobi_admin_ui_params:int(~"")),
        ?_assertEqual(error, asobi_admin_ui_params:int(~"abc")),
        ?_assertEqual(error, asobi_admin_ui_params:int(~"1.5"))
    ].
