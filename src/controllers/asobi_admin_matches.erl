-module(asobi_admin_matches).

-export([index/1, show/1]).

-spec index(cowboy_req:req()) -> {json, map()}.
index(#{qs := Qs} = _Req) ->
    Params = cow_qs:parse_qs(Qs),
    Limit = binary_to_integer(proplists:get_value(~"limit", Params, ~"50")),
    Q0 = kura_query:from(asobi_match_record),
    Q1 =
        case proplists:get_value(~"status", Params) of
            undefined -> Q0;
            Status -> kura_query:where(Q0, {status, Status})
        end,
    Q2 =
        case proplists:get_value(~"mode", Params) of
            undefined -> Q1;
            Mode -> kura_query:where(Q1, {mode, Mode})
        end,
    Q3 = kura_query:limit(kura_query:order_by(Q2, [{inserted_at, desc}]), Limit),
    {ok, Matches} = asobi_repo:all(Q3),
    {json, #{matches => Matches}}.

-spec show(cowboy_req:req()) -> {json, map()} | {status, integer()}.
show(#{bindings := #{~"id" := MatchId}} = _Req) ->
    case asobi_repo:get(asobi_match_record, MatchId) of
        {ok, Record} -> {json, Record};
        {error, not_found} -> {status, 404}
    end.
