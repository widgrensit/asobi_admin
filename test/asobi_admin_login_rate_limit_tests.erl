-module(asobi_admin_login_rate_limit_tests).

-include_lib("eunit/include/eunit.hrl").

rate_limit_test_() ->
    {foreach, fun setup/0, fun cleanup/1, [
        fun first_attempts_are_allowed/0,
        fun exceeding_the_budget_is_rate_limited/0,
        fun different_peers_have_independent_budgets/0,
        fun client_id_defaults_to_peer/0,
        fun client_id_trusts_xff_single_hop_when_configured/0,
        fun client_id_takes_nth_hop_from_right_when_configured/0,
        fun client_id_falls_back_to_peer_when_xff_missing/0,
        fun client_id_falls_back_to_peer_on_short_hop_chain/0,
        fun client_id_falls_back_to_peer_on_empty_hop/0,
        fun sweep_removes_only_expired_windows/0
    ]}.

setup() ->
    application:unset_env(asobi_admin, trusted_proxy),
    asobi_admin_login_rate_limit:init().

cleanup(_) ->
    application:unset_env(asobi_admin, trusted_proxy).

req(Headers) ->
    #{headers => Headers, peer => {{203, 0, 113, 9}, 12345}}.

first_attempts_are_allowed() ->
    Peer = unique_peer(),
    lists:foreach(fun(_) -> ?assertEqual(ok, asobi_admin_login_rate_limit:check(Peer)) end, [1, 2, 3, 4, 5]).

exceeding_the_budget_is_rate_limited() ->
    Peer = unique_peer(),
    lists:foreach(fun(_) -> asobi_admin_login_rate_limit:check(Peer) end, [1, 2, 3, 4, 5]),
    ?assertEqual(rate_limited, asobi_admin_login_rate_limit:check(Peer)).

different_peers_have_independent_budgets() ->
    PeerA = unique_peer(),
    PeerB = unique_peer(),
    lists:foreach(fun(_) -> asobi_admin_login_rate_limit:check(PeerA) end, [1, 2, 3, 4, 5]),
    ?assertEqual(ok, asobi_admin_login_rate_limit:check(PeerB)).

unique_peer() ->
    binary:encode_hex(crypto:strong_rand_bytes(8)).

client_id_defaults_to_peer() ->
    Req = req(#{~"x-forwarded-for" => ~"203.0.113.9, 1.2.3.4"}),
    ?assertEqual(~"203.0.113.9", asobi_admin_login_rate_limit:client_id(Req)).

client_id_trusts_xff_single_hop_when_configured() ->
    application:set_env(asobi_admin, trusted_proxy, true),
    Req = req(#{~"x-forwarded-for" => ~"198.51.100.7, 10.0.0.1"}),
    ?assertEqual(~"10.0.0.1", asobi_admin_login_rate_limit:client_id(Req)).

client_id_takes_nth_hop_from_right_when_configured() ->
    application:set_env(asobi_admin, trusted_proxy, 2),
    Req = req(#{~"x-forwarded-for" => ~"198.51.100.7, 10.0.0.1, 10.0.0.2"}),
    ?assertEqual(~"10.0.0.1", asobi_admin_login_rate_limit:client_id(Req)).

client_id_falls_back_to_peer_when_xff_missing() ->
    application:set_env(asobi_admin, trusted_proxy, true),
    ?assertEqual(~"203.0.113.9", asobi_admin_login_rate_limit:client_id(req(#{}))).

client_id_falls_back_to_peer_on_short_hop_chain() ->
    application:set_env(asobi_admin, trusted_proxy, 5),
    Req = req(#{~"x-forwarded-for" => ~"10.0.0.1, 10.0.0.2"}),
    ?assertEqual(~"203.0.113.9", asobi_admin_login_rate_limit:client_id(Req)).

client_id_falls_back_to_peer_on_empty_hop() ->
    application:set_env(asobi_admin, trusted_proxy, true),
    Req = req(#{~"x-forwarded-for" => ~"10.0.0.1,"}),
    ?assertEqual(~"203.0.113.9", asobi_admin_login_rate_limit:client_id(Req)).

sweep_removes_only_expired_windows() ->
    Fresh = unique_peer(),
    asobi_admin_login_rate_limit:check(Fresh),
    Stale = unique_peer(),
    ets:insert(asobi_admin_login_attempts, {Stale, 1, 0}),
    Deleted = asobi_admin_login_rate_limit:sweep_expired(),
    ?assert(Deleted >= 1),
    ?assertEqual(ok, asobi_admin_login_rate_limit:check(Fresh)).
