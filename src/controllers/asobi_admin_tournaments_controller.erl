-module(asobi_admin_tournaments_controller).
-moduledoc "Console UI: tournament list, detail, and creation.".

-export([index/1, show/1, create/1]).

-spec index(cowboy_req:req()) -> {ok, map()} | {redirect, binary()}.
index(#{qs := Qs} = Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        Params = cow_qs:parse_qs(Qs),
        Q0 = kura_query:from(asobi_tournament),
        Q1 =
            case proplists:get_value(~"status", Params) of
                undefined -> Q0;
                Status -> kura_query:where(Q0, {status, Status})
            end,
        Q2 = kura_query:limit(kura_query:order_by(Q1, [{start_at, desc}]), 50),
        {ok, Tournaments} = asobi_repo:all(Q2),
        {ok, #{
            active_page => ~"tournaments",
            csrf_token => maps:get(csrf_token, Req, ~""),
            tournaments => Tournaments
        }}
    end).

-spec show(cowboy_req:req()) -> {ok, map()} | {redirect, binary()} | {status, integer()}.
show(#{bindings := #{~"id" := TournamentId}} = Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        case asobi_repo:get(asobi_tournament, TournamentId) of
            {ok, Tournament} ->
                {ok, #{
                    active_page => ~"tournaments",
                    csrf_token => maps:get(csrf_token, Req, ~""),
                    tournament => Tournament
                }};
            {error, not_found} ->
                {status, 404}
        end
    end).

-spec create(cowboy_req:req()) ->
    {status, integer(), map(), binary(), cowboy_req:req()} | {redirect, binary()}.
create(Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        Params = maps:get(params, Req, #{}),
        Name = maps:get(~"name", Params, ~""),
        Result = asobi_admin_tournaments:do_create(#{
            ~"name" => Name,
            ~"leaderboard_id" => maps:get(~"leaderboard_id", Params, ~""),
            ~"start_at" => maps:get(~"start_at", Params, ~""),
            ~"end_at" => maps:get(~"end_at", Params, ~"")
        }),
        asobi_admin_ui_audit:log_action(~"create_tournament", #{name => Name}, Result),
        {status, 302, #{~"location" => ~"/admin/ui/tournaments"}, <<>>, Req}
    end).
