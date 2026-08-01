-module(asobi_admin_csrf_tests).

-include_lib("eunit/include/eunit.hrl").

-define(SECRET, ~"test-session-secret-not-real").

csrf_test_() ->
    {foreach, fun setup/0, fun cleanup/1, [
        fun token_is_deterministic_for_same_session/0,
        fun token_differs_for_different_sessions/0,
        fun valid_accepts_matching_token/0,
        fun valid_rejects_wrong_token/0,
        fun valid_rejects_token_for_different_session/0,
        fun valid_rejects_undefined_submitted/0,
        fun unconfigured_secret_fails_closed/0,
        fun unexpanded_placeholder_secret_fails_closed/0
    ]}.

setup() ->
    application:set_env(asobi_admin, session_secret, ?SECRET).

cleanup(_) ->
    application:unset_env(asobi_admin, session_secret).

token_is_deterministic_for_same_session() ->
    ?assertEqual(asobi_admin_csrf:token(~"session-a"), asobi_admin_csrf:token(~"session-a")).

token_differs_for_different_sessions() ->
    ?assertNotEqual(asobi_admin_csrf:token(~"session-a"), asobi_admin_csrf:token(~"session-b")).

valid_accepts_matching_token() ->
    Token = asobi_admin_csrf:token(~"session-a"),
    ?assert(asobi_admin_csrf:valid(~"session-a", Token)).

valid_rejects_wrong_token() ->
    ?assertNot(asobi_admin_csrf:valid(~"session-a", ~"not-the-token")).

valid_rejects_token_for_different_session() ->
    Token = asobi_admin_csrf:token(~"session-a"),
    ?assertNot(asobi_admin_csrf:valid(~"session-b", Token)).

valid_rejects_undefined_submitted() ->
    ?assertNot(asobi_admin_csrf:valid(~"session-a", undefined)).

unconfigured_secret_fails_closed() ->
    application:unset_env(asobi_admin, session_secret),
    ?assertEqual(error, asobi_admin_csrf:token(~"session-a")),
    ?assertNot(asobi_admin_csrf:valid(~"session-a", ~"anything")).

unexpanded_placeholder_secret_fails_closed() ->
    application:set_env(asobi_admin, session_secret, ~"${ASOBI_ADMIN_SESSION_SECRET}"),
    ?assertEqual(error, asobi_admin_csrf:token(~"session-a")).
