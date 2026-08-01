-module(asobi_admin_session_tests).

-include_lib("eunit/include/eunit.hrl").

session_test_() ->
    {foreach, fun setup/0, fun cleanup/1, [
        fun create_then_get_returns_principal/0,
        fun unknown_token_is_not_found/0,
        fun destroyed_token_is_not_found/0,
        fun expired_token_returns_expired_and_is_removed/0,
        fun tokens_are_unique_and_long/0,
        fun rotating_admin_token_invalidates_live_sessions/0,
        fun sweep_removes_only_expired_rows/0
    ]}.

setup() ->
    application:unset_env(asobi_admin, session_ttl_ms),
    application:unset_env(asobi_admin, admin_token),
    asobi_admin_session:init().

cleanup(_) ->
    application:unset_env(asobi_admin, session_ttl_ms),
    application:unset_env(asobi_admin, admin_token).

create_then_get_returns_principal() ->
    Token = asobi_admin_session:create(~"operator"),
    ?assertEqual({ok, ~"operator"}, asobi_admin_session:get(Token)).

unknown_token_is_not_found() ->
    ?assertEqual(not_found, asobi_admin_session:get(~"does-not-exist")).

destroyed_token_is_not_found() ->
    Token = asobi_admin_session:create(~"operator"),
    ok = asobi_admin_session:destroy(Token),
    ?assertEqual(not_found, asobi_admin_session:get(Token)).

expired_token_returns_expired_and_is_removed() ->
    application:set_env(asobi_admin, session_ttl_ms, -1),
    Token = asobi_admin_session:create(~"operator"),
    ?assertEqual(expired, asobi_admin_session:get(Token)),
    ?assertEqual(not_found, asobi_admin_session:get(Token)).

tokens_are_unique_and_long() ->
    T1 = asobi_admin_session:create(~"operator"),
    T2 = asobi_admin_session:create(~"operator"),
    ?assertNotEqual(T1, T2),
    ?assert(byte_size(T1) >= 32).

rotating_admin_token_invalidates_live_sessions() ->
    application:set_env(asobi_admin, admin_token, ~"token-v1"),
    Token = asobi_admin_session:create(~"operator"),
    ?assertEqual({ok, ~"operator"}, asobi_admin_session:get(Token)),
    application:set_env(asobi_admin, admin_token, ~"token-v2-after-rotation"),
    ?assertEqual(stale_credential, asobi_admin_session:get(Token)),
    ?assertEqual(not_found, asobi_admin_session:get(Token)).

sweep_removes_only_expired_rows() ->
    application:set_env(asobi_admin, session_ttl_ms, 60_000),
    Live = asobi_admin_session:create(~"operator"),
    application:set_env(asobi_admin, session_ttl_ms, -1),
    Expired = asobi_admin_session:create(~"operator"),
    Deleted = asobi_admin_session:sweep_expired(),
    ?assert(Deleted >= 1),
    ?assertEqual(not_found, asobi_admin_session:get(Expired)),
    application:set_env(asobi_admin, session_ttl_ms, 60_000),
    ?assertEqual({ok, ~"operator"}, asobi_admin_session:get(Live)).
