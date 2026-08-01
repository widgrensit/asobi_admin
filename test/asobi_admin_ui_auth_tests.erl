-module(asobi_admin_ui_auth_tests).

-include_lib("eunit/include/eunit.hrl").

ui_auth_test_() ->
    {setup, fun setup/0, fun cleanup/1, [
        fun no_cookie_is_not_authenticated/0,
        fun unknown_session_is_not_authenticated/0,
        fun valid_session_is_authenticated/0,
        fun require_session_ok_when_authenticated/0,
        fun require_session_redirects_when_not/0,
        fun redirect_preserves_path_and_query/0,
        fun duplicate_session_cookie_is_not_authenticated/0
    ]}.

setup() ->
    asobi_admin_session:init().

cleanup(_) ->
    ok.

req(CookieHeaders, Path, Qs) ->
    #{headers => CookieHeaders, path => Path, qs => Qs}.

cookie(Value) ->
    #{~"cookie" => <<"admin_session=", Value/binary>>}.

no_cookie_is_not_authenticated() ->
    ?assertNot(asobi_admin_ui_auth:authenticated(req(#{}, ~"/admin/ui/dashboard", <<>>))).

unknown_session_is_not_authenticated() ->
    ?assertNot(
        asobi_admin_ui_auth:authenticated(req(cookie(~"unknown"), ~"/admin/ui/dashboard", <<>>))
    ).

valid_session_is_authenticated() ->
    Token = asobi_admin_session:create(~"operator"),
    ?assert(
        asobi_admin_ui_auth:authenticated(req(cookie(Token), ~"/admin/ui/dashboard", <<>>))
    ).

require_session_ok_when_authenticated() ->
    Token = asobi_admin_session:create(~"operator"),
    ?assertEqual(
        ok, asobi_admin_ui_auth:require_session(req(cookie(Token), ~"/admin/ui/dashboard", <<>>))
    ).

require_session_redirects_when_not() ->
    ?assertMatch(
        {redirect, _}, asobi_admin_ui_auth:require_session(req(#{}, ~"/admin/ui/dashboard", <<>>))
    ).

redirect_preserves_path_and_query() ->
    Url = asobi_admin_ui_auth:redirect_to_login(req(#{}, ~"/admin/ui/players", ~"limit=10")),
    ?assertEqual(
        ~"/admin/ui/login?return_to=%2Fadmin%2Fui%2Fplayers%3Flimit%3D10", Url
    ).

duplicate_session_cookie_is_not_authenticated() ->
    Token = asobi_admin_session:create(~"operator"),
    Headers = #{~"cookie" => <<"admin_session=", Token/binary, "; admin_session=other">>},
    ?assertNot(asobi_admin_ui_auth:authenticated(req(Headers, ~"/admin/ui/dashboard", <<>>))).
