-module(asobi_admin_matches_controller).
-moduledoc "Console UI: match history list and detail.".

-export([index/1, show/1]).

-spec index(cowboy_req:req()) -> {ok, map()} | {redirect, binary()}.
index(#{qs := Qs} = Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        Params = cow_qs:parse_qs(Qs),
        Limit = asobi_admin_ui_params:int_param(Params, ~"limit", 50, 200),
        Q0 = kura_query:from(asobi_match_record),
        Q1 =
            case proplists:get_value(~"status", Params) of
                undefined -> Q0;
                Status -> kura_query:where(Q0, {status, Status})
            end,
        Q2 = kura_query:limit(kura_query:order_by(Q1, [{inserted_at, desc}]), Limit),
        {ok, Matches} = asobi_repo:all(Q2),
        {ok, #{
            active_page => ~"matches",
            csrf_token => maps:get(csrf_token, Req, ~""),
            matches => Matches,
            status_filter => proplists:get_value(~"status", Params, ~"")
        }}
    end).

-spec show(cowboy_req:req()) -> {ok, map()} | {redirect, binary()} | {status, integer()}.
show(#{bindings := #{~"id" := MatchId}} = Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        case asobi_repo:get(asobi_match_record, MatchId) of
            {ok, Record} ->
                {ok, #{
                    active_page => ~"matches",
                    csrf_token => maps:get(csrf_token, Req, ~""),
                    match => Record
                }};
            {error, not_found} ->
                {status, 404}
        end
    end).
