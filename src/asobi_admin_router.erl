-module(asobi_admin_router).
-behaviour(nova_router).

-export([routes/1]).

-spec routes(atom()) -> [map()].
routes(_Environment) ->
    [
        admin_api_routes(),
        admin_ws_routes(),
        admin_ui_login_routes(),
        admin_ui_routes(),
        admin_static_routes()
    ].

admin_api_routes() ->
    #{
        prefix => ~"/admin/api",
        security => fun asobi_admin_auth:verify/1,
        %% Nova's pre_request plugins run before the `security` fun above, so
        %% nova_request_plugin would otherwise buffer an unauthenticated
        %% request body in full before the bearer token is ever checked -
        %% same class of bug the console UI's body-limit plugin exists for.
        plugins => [
            {pre_request, asobi_admin_body_limit_plugin, #{}},
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

%% Route security is not applied to ws upgrades; the dashboard socket
%% authenticates in-protocol (first frame) instead - see its moduledoc.
admin_ws_routes() ->
    #{
        prefix => ~"/admin",
        security => false,
        routes => [
            {~"/live/dashboard", asobi_admin_live_dashboard, #{protocol => ws}}
        ]
    }.

%% The pre-session login form. Deliberately its own route group, separate
%% from the CSRF-protected `admin_ui_routes/0`: excluding it from CSRF via a
%% path-string match is not structurally safe (a route can be reached via a
%% path Nova normalises but the CSRF plugin sees pre-normalisation - see
%% asobi_admin_csrf_plugin's moduledoc), whereas a route simply never wired
%% to the plugin cannot be bypassed that way. `/login` has no session cookie
%% yet, so it needs no CSRF protection: logging in as an attacker-chosen
%% session is not a privilege the attacker doesn't already have.
admin_ui_login_routes() ->
    #{
        prefix => ~"/admin/ui",
        security => false,
        %% Order matters: headers first so even a later {stop, ...} reply
        %% carries the security headers; body-limit before nova_request_plugin
        %% so an oversized/chunked body is rejected before anything reads it
        %% into memory (see asobi_admin_body_limit_plugin's moduledoc).
        plugins => [
            {pre_request, asobi_admin_headers_plugin, #{}},
            {pre_request, asobi_admin_body_limit_plugin, #{}},
            {pre_request, nova_request_plugin, #{
                read_urlencoded_body => true,
                parse_qs => true
            }},
            {pre_request, nova_correlation_plugin, #{}}
        ],
        routes => [
            {~"/login", fun asobi_admin_login_controller:new/1, #{methods => [get]}},
            {~"/login", fun asobi_admin_login_controller:create/1, #{methods => [post]}}
        ]
    }.

%% The session-authenticated console UI. Security is not applied via the
%% router's `security` fun (that gates the bearer-token JSON API); each
%% controller instead calls asobi_admin_ui_auth:require_session/1 and
%% redirects anonymous visitors to the login page.
admin_ui_routes() ->
    #{
        prefix => ~"/admin/ui",
        security => false,
        %% Order matters: headers first so even a CSRF-reject 403 carries the
        %% security headers; body-limit before nova_request_plugin for the
        %% same reason as the login group.
        plugins => [
            {pre_request, asobi_admin_headers_plugin, #{}},
            {pre_request, asobi_admin_body_limit_plugin, #{}},
            {pre_request, nova_request_plugin, #{
                read_urlencoded_body => true,
                parse_qs => true
            }},
            {pre_request, asobi_admin_csrf_plugin, #{}},
            {pre_request, nova_correlation_plugin, #{}}
        ],
        routes => [
            {~"/logout", fun asobi_admin_login_controller:delete/1, #{methods => [post]}},

            {~"/dashboard", fun asobi_admin_dashboard_controller:index/1, #{methods => [get]}},

            {~"/players", fun asobi_admin_players_controller:index/1, #{methods => [get]}},
            {~"/players/:id", fun asobi_admin_players_controller:show/1, #{methods => [get]}},
            {~"/players/:id/ban", fun asobi_admin_players_controller:ban/1, #{methods => [post]}},
            {~"/players/:id/unban", fun asobi_admin_players_controller:unban/1, #{
                methods => [post]
            }},
            {~"/players/:id/grant", fun asobi_admin_players_controller:grant/1, #{
                methods => [post]
            }},

            {~"/matches", fun asobi_admin_matches_controller:index/1, #{methods => [get]}},
            {~"/matches/:id", fun asobi_admin_matches_controller:show/1, #{methods => [get]}},

            {~"/matchmaker", fun asobi_admin_matchmaker_controller:index/1, #{methods => [get]}},

            {~"/leaderboards", fun asobi_admin_leaderboards_controller:index/1, #{methods => [get]}},

            {~"/economy", fun asobi_admin_economy_controller:index/1, #{methods => [get]}},
            {~"/economy/items", fun asobi_admin_economy_controller:create_item/1, #{
                methods => [post]
            }},
            {~"/economy/listings", fun asobi_admin_economy_controller:create_listing/1, #{
                methods => [post]
            }},

            {~"/tournaments", fun asobi_admin_tournaments_controller:index/1, #{methods => [get]}},
            {~"/tournaments", fun asobi_admin_tournaments_controller:create/1, #{
                methods => [post]
            }},
            {~"/tournaments/:id", fun asobi_admin_tournaments_controller:show/1, #{
                methods => [get]
            }},

            {~"/chat", fun asobi_admin_chat_controller:index/1, #{methods => [get]}},
            {~"/chat/:channel_id", fun asobi_admin_chat_controller:show/1, #{methods => [get]}},

            {~"/notifications", fun asobi_admin_notifications_controller:index/1, #{
                methods => [get]
            }},
            {~"/notifications/broadcast", fun asobi_admin_notifications_controller:broadcast/1, #{
                methods => [post]
            }},

            {~"/system", fun asobi_admin_system_controller:index/1, #{methods => [get]}}
        ]
    }.

admin_static_routes() ->
    #{
        prefix => ~"/admin/ui/assets",
        security => false,
        routes => [
            {~"/css/:file", fun asobi_admin_static_controller:serve_css/1, #{methods => [get]}}
        ]
    }.
