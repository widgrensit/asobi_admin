-module(asobi_admin_login_rate_limit).
-moduledoc ~"""
Fixed-window per-client rate limit for the login form.

The admin token is a single shared secret with a browser form now in front of
it (previously only the bearer API could try it), so unlimited attempts turn
a short or guessed token into a network-speed credential-stuffing target.
This is deliberately a small self-contained ETS counter rather than a new
dependency - Nova has no rate-limit primitive (`nova_resilience` is a
circuit-breaker/health-check library, not a rate limiter).
""".

-include_lib("kernel/include/logger.hrl").

-export([init/0, check/1, client_id/1, sweep_expired/0]).

-define(TABLE, asobi_admin_login_attempts).
-define(MAX_ATTEMPTS, 5).
-define(WINDOW_MS, 60_000).

-spec init() -> ok.
init() ->
    case ets:whereis(?TABLE) of
        undefined ->
            _ = ets:new(?TABLE, [named_table, public, set, {write_concurrency, true}]),
            ok;
        _ ->
            ok
    end.

-doc """
Records an attempt for ClientId and reports whether it is within the
window's budget. Call once per login POST, regardless of outcome, so both
wrong guesses and successful logins count toward the window. The counter
increment is atomic (ets:update_counter/4): a naive lookup-then-insert
here let concurrent requests race past the budget under load.
""".
-spec check(binary()) -> ok | rate_limited.
check(ClientId) ->
    Now = erlang:system_time(millisecond),
    case ets:lookup(?TABLE, ClientId) of
        [{ClientId, _Count, WindowStart}] when Now - WindowStart >= ?WINDOW_MS ->
            %% Window expired - start a fresh one. A concurrent reset here
            %% races benignly (worst case, the count undercounts once at the
            %% window boundary); the sustained-attack path below is atomic.
            ets:insert(?TABLE, {ClientId, 1, Now}),
            ok;
        _ ->
            Count = ets:update_counter(?TABLE, ClientId, {2, 1}, {ClientId, 0, Now}),
            case Count > ?MAX_ATTEMPTS of
                true -> rate_limited;
                false -> ok
            end
    end.

-doc """
The rate-limit key. Defaults to the TCP peer, which cannot be spoofed but
collapses to the proxy's own address for every client when asobi_admin
sits behind a TLS-terminating proxy (the deployment the Secure-cookie
default assumes) - one shared budget would let any unauthenticated
attacker lock out every real operator. Only trust `x-forwarded-for` when a
deployment has explicitly confirmed a proxy chain, via
`{trusted_proxy, N}` where N is the number of trusted hops appending to
the header (or `true`, meaning 1, for a single proxy) - the Nth entry from
the right is the one appended by the trusted hop closest to asobi_admin's
own listener, the only one a client cannot forge. Getting N wrong (fewer
hops than actually present) reopens the shared-bucket problem this exists
to close, silently, so it is deliberately not a bare boolean.
""".
-spec client_id(cowboy_req:req()) -> binary().
client_id(Req) ->
    case application:get_env(asobi_admin, trusted_proxy) of
        {ok, true} -> forwarded_for(Req, 1);
        {ok, N} when is_integer(N), N >= 1 -> forwarded_for(Req, N);
        _ -> peer(Req)
    end.

-spec forwarded_for(cowboy_req:req(), pos_integer()) -> binary().
forwarded_for(Req, HopsFromRight) ->
    case cowboy_req:header(~"x-forwarded-for", Req) of
        undefined ->
            ?LOG_WARNING(#{msg => ~"admin_trusted_proxy_missing_xff"}),
            peer(Req);
        Raw ->
            Hops = [string:trim(P) || P <- binary:split(Raw, ~",", [global])],
            case nth_from_right(HopsFromRight, Hops) of
                <<>> -> peer(Req);
                undefined -> peer(Req);
                Hop -> Hop
            end
    end.

-spec nth_from_right(pos_integer(), [binary()]) -> binary() | undefined.
nth_from_right(N, Hops) when N =< length(Hops) ->
    lists:nth(N, lists:reverse(Hops));
nth_from_right(_N, _Hops) ->
    undefined.

-spec peer(cowboy_req:req()) -> binary().
peer(Req) ->
    try
        {IP, _Port} = cowboy_req:peer(Req),
        list_to_binary(inet:ntoa(IP))
    catch
        _:_ -> ~"unknown"
    end.

-doc "Purges expired windows. Without this the table grows by one row per distinct source address forever.".
-spec sweep_expired() -> non_neg_integer().
sweep_expired() ->
    Cutoff = erlang:system_time(millisecond) - ?WINDOW_MS,
    %% Field-first, matching asobi_admin_session:sweep_expired/0: '$1' binds
    %% WindowStart, guard reads as "WindowStart < Cutoff".
    MatchSpec = [{{'_', '_', '$1'}, [{'<', '$1', Cutoff}], [true]}],
    ets:select_delete(?TABLE, MatchSpec).
