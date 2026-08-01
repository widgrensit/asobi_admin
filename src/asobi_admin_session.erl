-module(asobi_admin_session).
-moduledoc ~"""
ETS-based session management for the admin console UI.

The console has a single operator identity (there is no user table), so a
session maps a random token to a fixed principal rather than a user id.

Two deliberate hardening choices beyond a plain token->principal map:

- The table is keyed on `sha256(Token)`, not the token itself, and the raw
  token is never stored. The console is documented to run co-located with
  the game backend (for authoritative live-plane data), so this ETS table
  lives on a node shared with game code; keying on the hash means a `public`
  table dump (any local process, or a debug shell) yields nothing directly
  replayable as a session.
- Each session is stamped with a hash of `ASOBI_ADMIN_TOKEN` at creation
  time and re-checked on every lookup, so rotating the admin token (the
  documented incident response for a leaked token) immediately invalidates
  every live browser session too, not just future logins.
""".

-export([init/0, create/1, get/1, destroy/1, sweep_expired/0]).

-define(TABLE, asobi_admin_sessions).

-spec init() -> ok.
init() ->
    case ets:whereis(?TABLE) of
        undefined ->
            _ = ets:new(?TABLE, [named_table, public, set, {read_concurrency, true}]),
            ok;
        _ ->
            ok
    end.

-spec create(binary()) -> binary().
create(Principal) ->
    Token = binary:encode_hex(crypto:strong_rand_bytes(32), lowercase),
    ExpiresAt = erlang:system_time(millisecond) + session_ttl(),
    ets:insert(?TABLE, {key(Token), Principal, ExpiresAt, cred_generation()}),
    Token.

-spec get(binary()) -> {ok, binary()} | expired | stale_credential | not_found.
get(Token) ->
    Key = key(Token),
    case ets:lookup(?TABLE, Key) of
        [{_, Principal, ExpiresAt, Gen}] ->
            Now = erlang:system_time(millisecond),
            case {Now < ExpiresAt, Gen =:= cred_generation()} of
                {true, true} ->
                    {ok, Principal};
                {true, false} ->
                    ets:delete(?TABLE, Key),
                    stale_credential;
                {false, _} ->
                    ets:delete(?TABLE, Key),
                    expired
            end;
        [] ->
            not_found
    end.

-spec destroy(binary()) -> ok.
destroy(Token) ->
    ets:delete(?TABLE, key(Token)),
    ok.

-doc """
Purges expired rows. Expiry is otherwise only reaped lazily on get/1, so a
console left running with no sweep would grow the table by one row per
login forever. A single unbatched pass is fine at this table's scale (one
operator, one row per login).
""".
-spec sweep_expired() -> non_neg_integer().
sweep_expired() ->
    Now = erlang:system_time(millisecond),
    %% Field order matches the record shape {Key, Principal, ExpiresAt, Gen}:
    %% '$1' binds ExpiresAt, and the guard reads left-to-right as "ExpiresAt
    %% < Now" (the login rate-limit table's sweep expresses the same check
    %% the other way around - keep both field-first for the same reading).
    MatchSpec = [{{'_', '_', '$1', '_'}, [{'<', '$1', Now}], [true]}],
    ets:select_delete(?TABLE, MatchSpec).

-spec key(binary()) -> binary().
key(Token) ->
    crypto:hash(sha256, Token).

-spec cred_generation() -> binary().
cred_generation() ->
    case application:get_env(asobi_admin, admin_token) of
        {ok, T} when is_binary(T) -> crypto:hash(sha256, T);
        _ -> <<>>
    end.

-spec session_ttl() -> non_neg_integer().
session_ttl() ->
    case application:get_env(asobi_admin, session_ttl_ms) of
        {ok, V} when is_integer(V) -> V;
        _ -> 43_200_000
    end.
