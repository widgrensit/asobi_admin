-module(asobi_admin_live_dashboard_tests).

-include_lib("eunit/include/eunit.hrl").

-define(TOKEN, ~"correct-horse-battery-staple").

ws_auth_test_() ->
    {foreach, fun setup/0, fun cleanup/1, [
        fun starts_unauthed/0,
        fun valid_auth_frame_streams/0,
        fun wrong_token_closes/0,
        fun non_auth_first_frame_closes/0,
        fun invalid_json_closes/0,
        fun idle_timeout_closes_unauthed/0,
        fun idle_timeout_ignored_when_authed/0,
        fun refresh_ignored_when_unauthed/0
    ]}.

setup() ->
    application:set_env(asobi_admin, admin_token, ?TOKEN).

cleanup(_) ->
    application:unset_env(asobi_admin, admin_token).

starts_unauthed() ->
    {ok, State} = asobi_admin_live_dashboard:websocket_init(#{}),
    ?assertEqual(false, maps:get(authed, State)).

valid_auth_frame_streams() ->
    Frame = json:encode(#{~"type" => ~"auth", ~"token" => ?TOKEN}),
    Result = asobi_admin_live_dashboard:websocket_handle(
        {text, iolist_to_binary(Frame)}, #{authed => false}
    ),
    ?assertMatch({reply, {text, _}, #{authed := true}}, Result).

wrong_token_closes() ->
    Frame = json:encode(#{~"type" => ~"auth", ~"token" => ~"nope"}),
    Result = asobi_admin_live_dashboard:websocket_handle(
        {text, iolist_to_binary(Frame)}, #{authed => false}
    ),
    ?assertMatch({reply, {close, 1008, _}, _}, Result).

non_auth_first_frame_closes() ->
    Frame = json:encode(#{~"type" => ~"other"}),
    Result = asobi_admin_live_dashboard:websocket_handle(
        {text, iolist_to_binary(Frame)}, #{authed => false}
    ),
    ?assertMatch({reply, {close, 1008, _}, _}, Result).

invalid_json_closes() ->
    Result = asobi_admin_live_dashboard:websocket_handle(
        {text, ~"{not json"}, #{authed => false}
    ),
    ?assertMatch({reply, {close, 1008, _}, _}, Result).

idle_timeout_closes_unauthed() ->
    Result = asobi_admin_live_dashboard:websocket_info(idle_auth_timeout, #{authed => false}),
    ?assertMatch({reply, {close, 1008, _}, _}, Result).

idle_timeout_ignored_when_authed() ->
    Result = asobi_admin_live_dashboard:websocket_info(idle_auth_timeout, #{authed => true}),
    ?assertMatch({ok, _}, Result).

refresh_ignored_when_unauthed() ->
    Result = asobi_admin_live_dashboard:websocket_info(refresh, #{authed => false}),
    ?assertMatch({ok, _}, Result).
