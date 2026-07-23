-module(asobi_admin_auth).

-moduledoc """
Bearer-token authentication for the admin API and live dashboard.

The token comes from the `admin_token` application env (set via
`ASOBI_ADMIN_TOKEN`). Authentication fails closed: with no token configured
every request is denied, so a deployment that forgets the secret exposes
nothing. Comparison is constant-time over fixed-length digests.
""".

-include_lib("kernel/include/logger.hrl").

-export([verify/1, check_token/1]).

-define(MIN_TOKEN_BYTES, 16).

%% The Bearer scheme is matched case-sensitively on purpose: every consumer
%% is first-party tooling, and the strict match keeps the parse total.
-spec verify(cowboy_req:req()) -> boolean().
verify(Req) ->
    case cowboy_req:header(~"authorization", Req) of
        <<"Bearer ", Token/binary>> ->
            check_token(Token);
        _ ->
            false
    end.

-spec check_token(binary()) -> boolean().
check_token(Presented) when is_binary(Presented) ->
    case configured_token() of
        {ok, Configured} ->
            crypto:hash_equals(
                crypto:hash(sha256, Presented),
                crypto:hash(sha256, Configured)
            );
        error ->
            ?LOG_ERROR(#{msg => ~"admin_token_not_configured"}),
            false
    end;
check_token(_) ->
    false.

-spec configured_token() -> {ok, binary()} | error.
configured_token() ->
    case application:get_env(asobi_admin, admin_token) of
        {ok, Token} when is_binary(Token), byte_size(Token) >= ?MIN_TOKEN_BYTES ->
            %% A token containing "${" is an unexpanded config placeholder
            %% (the config was consulted without OS-var substitution).
            %% Accepting it would turn a publicly-known literal into a valid
            %% admin token, silently.
            case binary:match(Token, ~"${") of
                nomatch ->
                    {ok, Token};
                _ ->
                    ?LOG_ERROR(#{msg => ~"admin_token_unsubstituted_placeholder"}),
                    error
            end;
        {ok, Token} when is_binary(Token), Token =/= <<>> ->
            %% A short token is accepted but flagged: refusing it outright
            %% would brick a running deployment on a config mistake.
            ?LOG_WARNING(#{msg => ~"admin_token_shorter_than_recommended"}),
            {ok, Token};
        _ ->
            error
    end.
