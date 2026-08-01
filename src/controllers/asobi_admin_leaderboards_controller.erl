-module(asobi_admin_leaderboards_controller).
-moduledoc ~"""
Console UI: leaderboard lookup by ID.

There is no leaderboard-listing endpoint on the backend API (only
`asobi_admin_leaderboards:show/1`, which needs an ID), so this page is a
lookup form rather than an index.
""".

-export([index/1]).

-spec index(cowboy_req:req()) -> {ok, map()} | {redirect, binary()}.
index(#{qs := Qs} = Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        Params = cow_qs:parse_qs(Qs),
        case proplists:get_value(~"id", Params) of
            undefined ->
                {ok, base_assigns(Req)};
            BoardId ->
                Entries = asobi_leaderboard_server:top(BoardId, 100),
                {ok, (base_assigns(Req))#{
                    leaderboard_id => BoardId,
                    entries => [
                        #{player_id => P, score => S, rank => R}
                     || {P, S, R} <- Entries
                    ]
                }}
        end
    end).

-spec base_assigns(cowboy_req:req()) -> map().
base_assigns(Req) ->
    #{
        active_page => ~"leaderboards",
        csrf_token => maps:get(csrf_token, Req, ~""),
        leaderboard_id => ~"",
        entries => []
    }.
