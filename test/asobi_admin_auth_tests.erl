-module(asobi_admin_auth_tests).

-include_lib("eunit/include/eunit.hrl").

-define(TOKEN, ~"correct-horse-battery-staple").

auth_test_() ->
    {foreach, fun setup/0, fun cleanup/1, [
        fun valid_token_passes/0,
        fun wrong_token_fails/0,
        fun missing_header_fails/0,
        fun malformed_header_fails/0,
        fun lowercase_bearer_fails/0,
        fun empty_token_fails/0,
        fun unconfigured_fails_closed/0,
        fun empty_configured_token_fails_closed/0,
        fun non_binary_configured_token_fails_closed/0,
        fun short_configured_token_still_works/0,
        fun unexpanded_placeholder_fails_closed/0,
        fun check_token_non_binary_fails/0
    ]}.

setup() ->
    application:set_env(asobi_admin, admin_token, ?TOKEN).

cleanup(_) ->
    application:unset_env(asobi_admin, admin_token).

valid_token_passes() ->
    ?assert(asobi_admin_auth:verify(req(<<"Bearer ", ?TOKEN/binary>>))).

wrong_token_fails() ->
    ?assertNot(asobi_admin_auth:verify(req(~"Bearer wrong-token-entirely"))).

missing_header_fails() ->
    ?assertNot(asobi_admin_auth:verify(#{headers => #{}})).

malformed_header_fails() ->
    ?assertNot(asobi_admin_auth:verify(req(?TOKEN))).

lowercase_bearer_fails() ->
    ?assertNot(asobi_admin_auth:verify(req(<<"bearer ", ?TOKEN/binary>>))).

empty_token_fails() ->
    ?assertNot(asobi_admin_auth:verify(req(~"Bearer "))).

unconfigured_fails_closed() ->
    application:unset_env(asobi_admin, admin_token),
    ?assertNot(asobi_admin_auth:verify(req(<<"Bearer ", ?TOKEN/binary>>))).

empty_configured_token_fails_closed() ->
    application:set_env(asobi_admin, admin_token, ~""),
    ?assertNot(asobi_admin_auth:verify(req(~"Bearer "))),
    ?assertNot(asobi_admin_auth:verify(req(~"Bearer x"))).

non_binary_configured_token_fails_closed() ->
    application:set_env(asobi_admin, admin_token, "list-not-binary"),
    ?assertNot(asobi_admin_auth:verify(req(~"Bearer list-not-binary"))).

short_configured_token_still_works() ->
    application:set_env(asobi_admin, admin_token, ~"short"),
    ?assert(asobi_admin_auth:verify(req(~"Bearer short"))),
    ?assertNot(asobi_admin_auth:verify(req(~"Bearer other"))).

unexpanded_placeholder_fails_closed() ->
    application:set_env(asobi_admin, admin_token, ~"${ASOBI_ADMIN_TOKEN}"),
    ?assertNot(asobi_admin_auth:verify(req(~"Bearer ${ASOBI_ADMIN_TOKEN}"))),
    application:set_env(asobi_admin, admin_token, ~"prefix-${OTHER_VAR}-suffix"),
    ?assertNot(asobi_admin_auth:verify(req(~"Bearer prefix-${OTHER_VAR}-suffix"))).

check_token_non_binary_fails() ->
    ?assertNot(asobi_admin_auth:check_token(atom)),
    ?assertNot(asobi_admin_auth:check_token(["list"])).

req(AuthValue) ->
    #{headers => #{~"authorization" => AuthValue}}.
