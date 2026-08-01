-module(asobi_admin_players_controller).
-moduledoc "Console UI: player search, detail, ban/unban, and currency grants.".

-export([index/1, show/1, ban/1, unban/1, grant/1]).

-spec index(cowboy_req:req()) -> {ok, map()} | {redirect, binary()}.
index(#{qs := Qs} = Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        Params = cow_qs:parse_qs(Qs),
        Limit = asobi_admin_ui_params:int_param(Params, ~"limit", 50, 200),
        Offset = asobi_admin_ui_params:int_param(Params, ~"offset", 0, 1_000_000),
        Q = kura_query:limit(
            kura_query:offset(
                kura_query:order_by(kura_query:from(asobi_player), [{inserted_at, desc}]),
                Offset
            ),
            Limit
        ),
        {ok, Players} = asobi_repo:all(Q),
        {ok, #{
            active_page => ~"players",
            csrf_token => maps:get(csrf_token, Req, ~""),
            players => Players,
            limit => Limit,
            offset => Offset,
            next_offset => Offset + Limit,
            prev_offset => max(0, Offset - Limit)
        }}
    end).

-spec show(cowboy_req:req()) -> {ok, map()} | {redirect, binary()} | {status, integer()}.
show(#{bindings := #{~"id" := PlayerId}} = Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        case asobi_repo:get(asobi_player, PlayerId) of
            {ok, Player} ->
                {ok, Wallets} = asobi_economy:get_wallets(PlayerId),
                {ok, #{
                    active_page => ~"players",
                    csrf_token => maps:get(csrf_token, Req, ~""),
                    player => Player,
                    wallets => Wallets,
                    %% asobi_presence:get_status/1 returns the atom `online`
                    %% or `offline` - erlydtl's falsy set doesn't include
                    %% arbitrary atoms, so `offline` is truthy in a template
                    %% `{% if %}` unless it's reduced to a real boolean here.
                    online => asobi_presence:get_status(PlayerId) =:= online
                }};
            {error, not_found} ->
                {status, 404}
        end
    end).

-spec ban(cowboy_req:req()) ->
    {status, integer(), map(), binary(), cowboy_req:req()} | {redirect, binary()}.
ban(#{bindings := #{~"id" := PlayerId}} = Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        asobi_admin_ui_audit:log_action(
            ~"ban", #{player_id => PlayerId}, asobi_admin_players:do_ban(PlayerId)
        ),
        redirect_to_player(PlayerId, Req)
    end).

-spec unban(cowboy_req:req()) ->
    {status, integer(), map(), binary(), cowboy_req:req()} | {redirect, binary()}.
unban(#{bindings := #{~"id" := PlayerId}} = Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        asobi_admin_ui_audit:log_action(
            ~"unban", #{player_id => PlayerId}, asobi_admin_players:do_unban(PlayerId)
        ),
        redirect_to_player(PlayerId, Req)
    end).

-spec grant(cowboy_req:req()) ->
    {status, integer(), map(), binary(), cowboy_req:req()} | {redirect, binary()}.
grant(#{bindings := #{~"id" := PlayerId}} = Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        Params = maps:get(params, Req, #{}),
        Currency = maps:get(~"currency", Params, ~"gold"),
        Fields = #{player_id => PlayerId, currency => Currency},
        case asobi_admin_ui_params:int(maps:get(~"amount", Params, ~"")) of
            {ok, Amount} ->
                Result = asobi_admin_players:do_grant(PlayerId, Currency, Amount),
                asobi_admin_ui_audit:log_action(~"grant", Fields#{amount => Amount}, Result);
            error ->
                asobi_admin_ui_audit:log_action(~"grant", Fields, {error, invalid_amount})
        end,
        redirect_to_player(PlayerId, Req)
    end).

%% Internal

-spec redirect_to_player(binary(), cowboy_req:req()) ->
    {status, integer(), map(), binary(), cowboy_req:req()}.
redirect_to_player(PlayerId, Req) ->
    {status, 302, #{~"location" => <<"/admin/ui/players/", PlayerId/binary>>}, <<>>, Req}.
