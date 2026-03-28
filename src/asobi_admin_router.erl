-module(asobi_admin_router).
-behaviour(nova_router).

-export([routes/1]).

-spec routes(atom()) -> [map()].
routes(_Environment) ->
    [
        admin_api_routes(),
        admin_ws_routes()
    ].

admin_api_routes() ->
    #{
        prefix => ~"/admin/api",
        security => false,
        plugins => [
            {pre_request, nova_request_plugin, #{
                decode_json_body => true,
                parse_qs => true
            }},
            {pre_request, nova_correlation_plugin, #{}}
        ],
        routes => [
            %% Dashboard
            {~"/dashboard", fun asobi_admin_dashboard:index/1, #{methods => [get]}},

            %% Players
            {~"/players", fun asobi_admin_players:index/1, #{methods => [get]}},
            {~"/players/search", fun asobi_admin_players:search/1, #{methods => [get]}},
            {~"/players/:id", fun asobi_admin_players:show/1, #{methods => [get]}},
            {~"/players/:id/ban", fun asobi_admin_players:ban/1, #{methods => [post]}},
            {~"/players/:id/unban", fun asobi_admin_players:unban/1, #{methods => [post]}},
            {~"/players/:id/grant", fun asobi_admin_players:grant_currency/1, #{methods => [post]}},

            %% Matches
            {~"/matches", fun asobi_admin_matches:index/1, #{methods => [get]}},
            {~"/matches/:id", fun asobi_admin_matches:show/1, #{methods => [get]}},

            %% Matchmaker
            {~"/matchmaker", fun asobi_admin_matchmaker:index/1, #{methods => [get]}},

            %% Leaderboards
            {~"/leaderboards/:id", fun asobi_admin_leaderboards:show/1, #{methods => [get]}},

            %% Economy
            {~"/economy", fun asobi_admin_economy:index/1, #{methods => [get]}},
            {~"/economy/items", fun asobi_admin_economy:items/1, #{methods => [get]}},
            {~"/economy/items", fun asobi_admin_economy:create_item/1, #{methods => [post]}},
            {~"/economy/listings", fun asobi_admin_economy:listings/1, #{methods => [get]}},
            {~"/economy/listings", fun asobi_admin_economy:create_listing/1, #{methods => [post]}},

            %% Tournaments
            {~"/tournaments", fun asobi_admin_tournaments:index/1, #{methods => [get]}},
            {~"/tournaments", fun asobi_admin_tournaments:create/1, #{methods => [post]}},
            {~"/tournaments/:id", fun asobi_admin_tournaments:show/1, #{methods => [get]}},

            %% Chat
            {~"/chat/channels", fun asobi_admin_chat:channels/1, #{methods => [get]}},
            {~"/chat/:channel_id/messages", fun asobi_admin_chat:messages/1, #{methods => [get]}},

            %% Notifications
            {~"/notifications/broadcast", fun asobi_admin_notifications:broadcast/1, #{
                methods => [post]
            }},

            %% System
            {~"/system", fun asobi_admin_system:index/1, #{methods => [get]}},
            {~"/system/nodes", fun asobi_admin_system:nodes/1, #{methods => [get]}}
        ]
    }.

admin_ws_routes() ->
    #{
        prefix => ~"/admin",
        security => false,
        routes => [
            {~"/live/dashboard", asobi_admin_live_dashboard, #{protocol => ws}}
        ]
    }.
