-module(asobi_admin_login_controller).
-moduledoc "Login form, session issuance, and logout for the console UI.".

-include_lib("kernel/include/logger.hrl").

-export([new/1, create/1, delete/1]).
-export([sanitize_redirect/1]).

-define(SESSION_PRINCIPAL, ~"operator").

-spec new(cowboy_req:req()) -> {ok, map()}.
new(#{qs := Qs} = Req) ->
    Params = cow_qs:parse_qs(Qs),
    {ok, #{
        error => proplists:get_value(~"error", Params) =:= ~"invalid_token",
        return_to => proplists:get_value(~"return_to", Params, ~""),
        csrf_token => maps:get(csrf_token, Req, ~"")
    }}.

%% `#{params := ...}` is not matched in the head: nova_request_plugin only
%% populates `params` for a urlencoded body, and this route carries no CSRF
%% protection (see asobi_admin_router:admin_ui_login_routes/0 moduledoc), so
%% an unauthenticated request with a different content-type must not crash.
-spec create(cowboy_req:req()) -> {status, integer(), map(), binary(), cowboy_req:req()}.
create(Req) ->
    Params = maps:get(params, Req, #{}),
    ClientId = asobi_admin_login_rate_limit:client_id(Req),
    case asobi_admin_login_rate_limit:check(ClientId) of
        rate_limited ->
            ?LOG_WARNING(#{msg => ~"admin_login_rate_limited", peer => ClientId}),
            {status, 429, #{~"retry-after" => ~"60"}, <<>>, Req};
        ok ->
            attempt_login(Params, ClientId, Req)
    end.

-spec attempt_login(map(), binary(), cowboy_req:req()) ->
    {status, integer(), map(), binary(), cowboy_req:req()}.
attempt_login(Params, ClientId, Req) ->
    Token = maps:get(~"admin_token", Params, ~""),
    ReturnTo = maps:get(~"return_to", Params, ~""),
    case asobi_admin_auth:check_token(Token) of
        true ->
            ?LOG_NOTICE(#{msg => ~"admin_login_success", peer => ClientId}),
            SessionToken = asobi_admin_session:create(?SESSION_PRINCIPAL),
            redirect_with_cookie(SessionToken, sanitize_redirect(ReturnTo), Req);
        false ->
            ?LOG_WARNING(#{msg => ~"admin_login_failed", peer => ClientId}),
            LoginUrl =
                <<"/admin/ui/login?error=invalid_token&return_to=",
                    (cow_qs:urlencode(ReturnTo))/binary>>,
            {status, 302, #{~"location" => LoginUrl}, <<>>, Req}
    end.

-spec delete(cowboy_req:req()) -> {status, integer(), map(), binary(), cowboy_req:req()}.
delete(Req) ->
    case asobi_admin_ui_auth:session_cookie(Req) of
        undefined -> ok;
        SessionToken -> asobi_admin_session:destroy(SessionToken)
    end,
    Req1 = cowboy_req:set_resp_cookie(~"admin_session", ~"", Req, cookie_opts(Req, 0)),
    {status, 302, #{~"location" => ~"/admin/ui/login"}, <<>>, Req1}.

%% Internal

-spec redirect_with_cookie(binary(), binary(), cowboy_req:req()) ->
    {status, integer(), map(), binary(), cowboy_req:req()}.
redirect_with_cookie(SessionToken, Destination, Req) ->
    TTL = session_ttl_seconds(),
    Req1 = cowboy_req:set_resp_cookie(~"admin_session", SessionToken, Req, cookie_opts(Req, TTL)),
    {status, 302, #{~"location" => Destination}, <<>>, Req1}.

-spec cookie_opts(cowboy_req:req(), non_neg_integer()) -> map().
cookie_opts(Req, MaxAge) ->
    %% Scoped to /admin/ui, not /: the README recommends running asobi_admin
    %% co-located with the game backend release, which shares the hostname -
    %% a Path=/ cookie would be sent to the game's own routes on every
    %% browser request the operator makes there.
    Base = #{path => ~"/admin/ui", max_age => MaxAge, http_only => true, same_site => lax},
    case secure_cookie(Req) of
        true -> Base#{secure => true};
        false -> Base
    end.

%% Default-deny: the cookie is Secure unless a deployment explicitly opts out
%% via `{session_cookie_secure, false}` (for local plain-http dev) or the
%% request genuinely arrived over plain HTTP with no TLS-terminating proxy in
%% front of it. Deriving from the live request (scheme, then
%% x-forwarded-proto) rather than a separately-configured base_url means a
%% deployment that forgets to set base_url still gets a Secure cookie behind
%% a TLS-terminating proxy, instead of silently downgrading.
-spec secure_cookie(cowboy_req:req()) -> boolean().
secure_cookie(Req) ->
    case application:get_env(asobi_admin, session_cookie_secure) of
        {ok, false} -> false;
        {ok, true} -> true;
        _ -> request_is_https_or_warn(Req)
    end.

%% The insecure fallback is the silent-failure shape: it works, so nothing
%% forces an operator to notice their proxy uses a signal this module
%% doesn't recognise (x-forwarded-ssl, the Forwarded header). Log once per
%% occurrence rather than add more header parsing for every proxy convention.
-spec request_is_https_or_warn(cowboy_req:req()) -> boolean().
request_is_https_or_warn(Req) ->
    case request_is_https(Req) of
        true ->
            true;
        false ->
            ?LOG_WARNING(#{
                msg => ~"admin_session_cookie_not_secure",
                hint =>
                    ~"no https scheme and no recognised x-forwarded-proto; set session_cookie_secure if behind a proxy using a different signal"
            }),
            false
    end.

-spec request_is_https(cowboy_req:req()) -> boolean().
request_is_https(Req) ->
    cowboy_req:scheme(Req) =:= ~"https" orelse forwarded_proto(Req) =:= ~"https".

%% Proxies vary in casing (`HTTPS`), whitespace (`https `), and multi-hop
%% chaining (`https, http`, appended left-to-right) - take the first hop,
%% trimmed and lowercased, rather than an exact-match compare that silently
%% treats every one of those shapes as "not https".
-spec forwarded_proto(cowboy_req:req()) -> binary() | undefined.
forwarded_proto(Req) ->
    case cowboy_req:header(~"x-forwarded-proto", Req) of
        undefined ->
            undefined;
        Raw ->
            [First | _] = binary:split(Raw, ~","),
            string:lowercase(string:trim(First))
    end.

-spec session_ttl_seconds() -> non_neg_integer().
session_ttl_seconds() ->
    case application:get_env(asobi_admin, session_ttl_ms) of
        {ok, V} when is_integer(V) -> V div 1000;
        _ -> 43_200
    end.

-doc """
Same-origin path under /admin/ui only, restricted to an allowlist of safe
characters (rather than only blocklisting known-bad ones): this rejects
protocol-relative (`//host`), the backslash variant browsers normalise to
`//`, `..` traversal, CR/LF header injection, NUL, and other control or
line-separator bytes in one pass instead of enumerating each attack shape.
Anything that doesn't pass falls back to the dashboard.
""".
-spec sanitize_redirect(binary() | undefined) -> binary().
sanitize_redirect(<<"/admin/ui/", _/binary>> = Path) ->
    case is_safe_path(Path) of
        true -> Path;
        false -> ~"/admin/ui/dashboard"
    end;
sanitize_redirect(_) ->
    ~"/admin/ui/dashboard".

%% `..` is checked against the *percent-decoded* path: a browser resolves a
%% percent-encoded `%2e%2e` segment as a literal `..` before it ever issues
%% the follow-up request, so a literal-only check on the raw bytes misses it.
%% `cow_uri:urldecode/1` is not used here - its contract is a single decoded
%% *component* (it raises on any byte, including a raw `/` or `?`, outside a
%% narrow whitelist), not a whole path-plus-query string.
-spec is_safe_path(binary()) -> boolean().
is_safe_path(Path) ->
    lists:all(fun is_safe_byte/1, binary_to_list(Path)) andalso
        binary:match(percent_decode(Path), ~"..") =:= nomatch.

-spec percent_decode(binary()) -> binary().
percent_decode(<<$%, H, L, Rest/binary>>) ->
    case unhex(H, L) of
        {ok, Byte} -> <<Byte, (percent_decode(Rest))/binary>>;
        error -> <<$%, H, (percent_decode(<<L, Rest/binary>>))/binary>>
    end;
percent_decode(<<C, Rest/binary>>) ->
    <<C, (percent_decode(Rest))/binary>>;
percent_decode(<<>>) ->
    <<>>.

-spec unhex(byte(), byte()) -> {ok, byte()} | error.
unhex(H, L) ->
    case {hex_digit(H), hex_digit(L)} of
        {{ok, HV}, {ok, LV}} -> {ok, (HV bsl 4) bor LV};
        _ -> error
    end.

-spec hex_digit(byte()) -> {ok, 0..15} | error.
hex_digit(C) when C >= $0, C =< $9 -> {ok, C - $0};
hex_digit(C) when C >= $a, C =< $f -> {ok, C - $a + 10};
hex_digit(C) when C >= $A, C =< $F -> {ok, C - $A + 10};
hex_digit(_) -> error.

-spec is_safe_byte(byte()) -> boolean().
is_safe_byte(C) when C >= $a, C =< $z -> true;
is_safe_byte(C) when C >= $A, C =< $Z -> true;
is_safe_byte(C) when C >= $0, C =< $9 -> true;
is_safe_byte(C) -> lists:member(C, "/-_.?&=%").
