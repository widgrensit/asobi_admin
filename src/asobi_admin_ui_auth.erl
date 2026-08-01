-module(asobi_admin_ui_auth).
-moduledoc ~"""
Console-UI session extraction and the authentication guard.

Reads the `admin_session` cookie and resolves it against `asobi_admin_session`.
There is a single operator identity, so a valid session just means
"authenticated", not "authenticated as a particular user".
""".

-export([authenticated/1, require_session/1, redirect_to_login/1, session_cookie/1, guarded/2]).

-spec authenticated(cowboy_req:req()) -> boolean().
authenticated(Req) ->
    case session_cookie(Req) of
        undefined ->
            false;
        Token ->
            case asobi_admin_session:get(Token) of
                {ok, _Principal} -> true;
                _ -> false
            end
    end.

-doc """
Reads the `admin_session` cookie value, or `undefined` if there isn't one.

The single home for this parse: every caller (this module, the CSRF plugin,
the login controller) needs the same guard against a repeated `Cookie:`
header, which makes `cowboy_req:match_cookies/2` return a list rather than a
binary. Three copies of a security-relevant parser is how a future hardening
pass fixes one and leaves the others behind.
""".
-spec session_cookie(cowboy_req:req()) -> binary() | undefined.
session_cookie(Req) ->
    case cowboy_req:match_cookies([{admin_session, [], undefined}], Req) of
        #{admin_session := V} when is_binary(V), V =/= <<>> -> V;
        _ -> undefined
    end.

-spec require_session(cowboy_req:req()) -> ok | {redirect, binary()}.
require_session(Req) ->
    case authenticated(Req) of
        true -> ok;
        false -> {redirect, redirect_to_login(Req)}
    end.

-doc """
Runs Fun only if Req carries a valid session, otherwise returns the
redirect-to-login tuple Nova's handler knows how to render. The single home
for the guard every session-protected controller action needs, so a new
controller can't add a route and simply forget to gate it.
""".
-spec guarded(cowboy_req:req(), fun(() -> Result)) -> Result | {redirect, binary()}.
guarded(Req, Fun) ->
    case require_session(Req) of
        {redirect, Url} -> {redirect, Url};
        ok -> Fun()
    end.

-spec redirect_to_login(cowboy_req:req()) -> binary().
redirect_to_login(Req) ->
    Path = cowboy_req:path(Req),
    ReturnTo =
        case cowboy_req:qs(Req) of
            <<>> -> Path;
            QS -> <<Path/binary, "?", QS/binary>>
        end,
    <<"/admin/ui/login?return_to=", (cow_qs:urlencode(ReturnTo))/binary>>.
