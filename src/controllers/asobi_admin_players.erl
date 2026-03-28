-module(asobi_admin_players).

-export([index/1, show/1, search/1, ban/1, unban/1, grant_currency/1]).

-spec index(cowboy_req:req()) -> {json, map()}.
index(#{qs := Qs} = _Req) ->
    Params = cow_qs:parse_qs(Qs),
    Limit = binary_to_integer(proplists:get_value(~"limit", Params, ~"50")),
    Offset = binary_to_integer(proplists:get_value(~"offset", Params, ~"0")),
    Q = kura_query:limit(
        kura_query:offset(
            kura_query:order_by(kura_query:from(asobi_player), [{inserted_at, desc}]),
            Offset
        ),
        Limit
    ),
    {ok, Players} = asobi_repo:all(Q),
    {json, #{players => Players, limit => Limit, offset => Offset}}.

-spec show(cowboy_req:req()) -> {json, map()} | {status, integer()}.
show(#{bindings := #{~"id" := PlayerId}} = _Req) ->
    case asobi_repo:get(asobi_player, PlayerId) of
        {ok, Player} ->
            Stats =
                case asobi_repo:get(asobi_player_stats, PlayerId) of
                    {ok, S} -> S;
                    _ -> #{}
                end,
            {ok, Wallets} = asobi_economy:get_wallets(PlayerId),
            FriendQ = kura_query:where(kura_query:from(asobi_friendship), {player_id, PlayerId}),
            {ok, Friends} = asobi_repo:all(FriendQ),
            {json, #{
                player => Player,
                stats => Stats,
                wallets => Wallets,
                friends => Friends,
                online => asobi_presence:get_status(PlayerId)
            }};
        {error, not_found} ->
            {status, 404}
    end.

-spec search(cowboy_req:req()) -> {json, map()}.
search(#{qs := Qs} = _Req) ->
    Params = cow_qs:parse_qs(Qs),
    Q0 = kura_query:from(asobi_player),
    Q1 =
        case proplists:get_value(~"username", Params) of
            undefined -> Q0;
            Username -> kura_query:where(Q0, {username, Username})
        end,
    Limit = binary_to_integer(proplists:get_value(~"limit", Params, ~"20")),
    Q2 = kura_query:limit(Q1, Limit),
    {ok, Players} = asobi_repo:all(Q2),
    {json, #{players => Players}}.

-spec ban(cowboy_req:req()) -> {json, map()} | {status, integer()}.
ban(#{bindings := #{~"id" := PlayerId}} = _Req) ->
    case asobi_repo:get(asobi_player, PlayerId) of
        {ok, Player} ->
            CS = kura_changeset:cast(
                asobi_player, Player, #{banned_at => calendar:universal_time()}, [banned_at]
            ),
            {ok, Updated} = asobi_repo:update(CS),
            {json, #{player => Updated, action => ~"banned"}};
        {error, not_found} ->
            {status, 404}
    end.

-spec unban(cowboy_req:req()) -> {json, map()} | {status, integer()}.
unban(#{bindings := #{~"id" := PlayerId}} = _Req) ->
    case asobi_repo:get(asobi_player, PlayerId) of
        {ok, Player} ->
            CS = kura_changeset:cast(asobi_player, Player, #{banned_at => undefined}, [banned_at]),
            {ok, Updated} = asobi_repo:update(CS),
            {json, #{player => Updated, action => ~"unbanned"}};
        {error, not_found} ->
            {status, 404}
    end.

-spec grant_currency(cowboy_req:req()) -> {json, map()} | {status, integer()}.
grant_currency(#{bindings := #{~"id" := PlayerId}, json := Params} = _Req) ->
    Currency = maps:get(~"currency", Params, ~"gold"),
    Amount = maps:get(~"amount", Params),
    case asobi_economy:grant(PlayerId, Currency, Amount, #{reason => ~"admin_grant"}) of
        {ok, Wallet} ->
            {json, #{success => true, wallet => Wallet}};
        {error, Reason} ->
            {json, 400, #{}, #{error => Reason}}
    end.
