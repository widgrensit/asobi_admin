-module(asobi_admin_csrf).
-moduledoc ~"""
CSRF synchroniser token bound to the console session.

The token is `HMAC-SHA256(session_secret, session_cookie_value)`, base64-encoded.
It is derived, never stored: any request carrying the (HttpOnly) `admin_session`
cookie can be handed its matching token on a safe request, and a state-changing
request must echo it back. An attacker who cannot read the session cookie
cannot compute the token, so cannot forge a cross-site state-changing request.
""".

-include_lib("kernel/include/logger.hrl").

-export([token/1, valid/2]).

-spec token(binary()) -> binary() | error.
token(SessionValue) when is_binary(SessionValue) ->
    case secret() of
        {ok, Secret} ->
            base64:encode(crypto:mac(hmac, sha256, Secret, <<"csrf:", SessionValue/binary>>));
        error ->
            error
    end.

-spec valid(binary(), binary() | undefined) -> boolean().
valid(SessionValue, Submitted) when is_binary(SessionValue), is_binary(Submitted) ->
    case token(SessionValue) of
        error ->
            false;
        Expected ->
            byte_size(Expected) =:= byte_size(Submitted) andalso
                crypto:hash_equals(Expected, Submitted)
    end;
valid(_, _) ->
    false.

-spec secret() -> {ok, binary()} | error.
secret() ->
    case application:get_env(asobi_admin, session_secret) of
        {ok, S} when is_binary(S), S =/= <<>> ->
            %% Same unexpanded-placeholder guard as asobi_admin_auth: a literal
            %% "${...}" would otherwise become a publicly-known HMAC key.
            case binary:match(S, ~"${") of
                nomatch ->
                    {ok, S};
                _ ->
                    ?LOG_ERROR(#{msg => ~"admin_session_secret_unsubstituted_placeholder"}),
                    error
            end;
        _ ->
            ?LOG_ERROR(#{msg => ~"admin_session_secret_not_configured"}),
            error
    end.
