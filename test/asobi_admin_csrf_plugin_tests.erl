-module(asobi_admin_csrf_plugin_tests).

-include_lib("eunit/include/eunit.hrl").

-define(SECRET, ~"test_session_secret_min_32_chars!!").

setup() ->
    application:set_env(asobi_admin, session_secret, ?SECRET),
    asobi_admin_session:init().

req(Method, Path, Headers, Params) ->
    #{method => Method, path => Path, headers => Headers, params => Params}.

cookie(Value) ->
    #{~"cookie" => <<"admin_session=", Value/binary>>}.

pre(Req) ->
    asobi_admin_csrf_plugin:pre_request(Req, undefined, #{}, state).

safe_get_injects_token_for_an_active_session_test() ->
    setup(),
    Token = asobi_admin_session:create(~"operator"),
    Req = req(~"GET", ~"/admin/ui/dashboard", cookie(Token), #{}),
    {ok, #{csrf_token := Csrf}, state} = pre(Req),
    ?assertEqual(asobi_admin_csrf:token(Token), Csrf).

safe_get_without_session_passes_through_test() ->
    setup(),
    Req = req(~"GET", ~"/admin/ui/dashboard", #{}, #{}),
    {ok, Out, state} = pre(Req),
    ?assertNot(maps:is_key(csrf_token, Out)).

safe_get_with_never_issued_cookie_gets_no_token_test() ->
    setup(),
    Req = req(~"GET", ~"/admin/ui/dashboard", cookie(~"attacker-picked-value"), #{}),
    {ok, Out, state} = pre(Req),
    ?assertNot(maps:is_key(csrf_token, Out)).

unsafe_post_with_valid_header_token_passes_test() ->
    setup(),
    Session = asobi_admin_session:create(~"operator"),
    Token = asobi_admin_csrf:token(Session),
    Headers = maps:put(~"x-csrf-token", Token, cookie(Session)),
    Req = req(~"POST", ~"/admin/ui/players/p1/ban", Headers, #{}),
    ?assertMatch({ok, _, state}, pre(Req)).

unsafe_post_with_valid_form_field_token_passes_test() ->
    setup(),
    Session = asobi_admin_session:create(~"operator"),
    Token = asobi_admin_csrf:token(Session),
    Req = req(~"POST", ~"/admin/ui/players/p1/ban", cookie(Session), #{~"_csrf_token" => Token}),
    ?assertMatch({ok, _, state}, pre(Req)).

unsafe_post_with_missing_token_is_rejected_test() ->
    setup(),
    Session = asobi_admin_session:create(~"operator"),
    Req = req(~"POST", ~"/admin/ui/players/p1/ban", cookie(Session), #{}),
    ?assertMatch({stop, {reply, 403, _, _}, _, state}, pre(Req)).

unsafe_post_with_wrong_token_is_rejected_test() ->
    setup(),
    Session = asobi_admin_session:create(~"operator"),
    Other = asobi_admin_session:create(~"operator"),
    Wrong = asobi_admin_csrf:token(Other),
    Headers = maps:put(~"x-csrf-token", Wrong, cookie(Session)),
    Req = req(~"POST", ~"/admin/ui/players/p1/ban", Headers, #{}),
    ?assertMatch({stop, {reply, 403, _, _}, _, state}, pre(Req)).

unsafe_post_without_session_is_rejected_test() ->
    setup(),
    Req = req(~"POST", ~"/admin/ui/players/p1/ban", #{}, #{}),
    ?assertMatch({stop, {reply, 403, _, _}, _, state}, pre(Req)).

unsafe_post_with_never_issued_cookie_is_rejected_test() ->
    setup(),
    %% Even a token correctly derived from an attacker-chosen cookie value
    %% must fail: the value was never issued by the login controller.
    Forged = ~"attacker-picked-value",
    Token = asobi_admin_csrf:token(Forged),
    Headers = maps:put(~"x-csrf-token", Token, cookie(Forged)),
    Req = req(~"POST", ~"/admin/ui/players/p1/ban", Headers, #{}),
    ?assertMatch({stop, {reply, 403, _, _}, _, state}, pre(Req)).

duplicate_session_cookie_is_treated_as_no_session_test() ->
    setup(),
    %% cowboy_req:match_cookies/2 returns a list, not a binary, when the
    %% header repeats a cookie name; this must not crash the plugin.
    Req = req(~"POST", ~"/admin/ui/players/p1/ban", #{~"cookie" => ~"admin_session=a; admin_session=b"}, #{}),
    ?assertMatch({stop, {reply, 403, _, _}, _, state}, pre(Req)).

logout_requires_token_test() ->
    setup(),
    Session = asobi_admin_session:create(~"operator"),
    Missing = req(~"POST", ~"/admin/ui/logout", cookie(Session), #{}),
    ?assertMatch({stop, {reply, 403, _, _}, _, state}, pre(Missing)),
    Token = asobi_admin_csrf:token(Session),
    Ok = req(~"POST", ~"/admin/ui/logout", cookie(Session), #{~"_csrf_token" => Token}),
    ?assertMatch({ok, _, state}, pre(Ok)).
