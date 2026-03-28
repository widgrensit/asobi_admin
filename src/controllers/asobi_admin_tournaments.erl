-module(asobi_admin_tournaments).

-export([index/1, show/1, create/1]).

-spec index(cowboy_req:req()) -> {json, map()}.
index(#{qs := Qs} = _Req) ->
    Params = cow_qs:parse_qs(Qs),
    Limit = binary_to_integer(proplists:get_value(~"limit", Params, ~"50")),
    Q0 = kura_query:from(asobi_tournament),
    Q1 =
        case proplists:get_value(~"status", Params) of
            undefined -> Q0;
            Status -> kura_query:where(Q0, {status, Status})
        end,
    Q2 = kura_query:limit(kura_query:order_by(Q1, [{start_at, desc}]), Limit),
    {ok, Tournaments} = asobi_repo:all(Q2),
    {json, #{tournaments => Tournaments}}.

-spec show(cowboy_req:req()) -> {json, map()} | {status, integer()}.
show(#{bindings := #{~"id" := TournamentId}} = _Req) ->
    case asobi_repo:get(asobi_tournament, TournamentId) of
        {ok, Tournament} ->
            Info =
                case asobi_tournament_server:get_info(TournamentId) of
                    {ok, Live} -> #{live => Live};
                    {error, not_found} -> #{live => null}
                end,
            {json, maps:merge(Tournament, Info)};
        {error, not_found} ->
            {status, 404}
    end.

-spec create(cowboy_req:req()) -> {json, map()} | {json, integer(), map(), map()}.
create(#{json := Params} = _Req) ->
    CS = asobi_tournament:changeset(#{}, #{
        name => maps:get(~"name", Params),
        leaderboard_id => maps:get(~"leaderboard_id", Params),
        max_entries => maps:get(~"max_entries", Params, undefined),
        entry_fee => maps:get(~"entry_fee", Params, #{}),
        rewards => maps:get(~"rewards", Params, #{}),
        start_at => maps:get(~"start_at", Params),
        end_at => maps:get(~"end_at", Params)
    }),
    case asobi_repo:insert(CS) of
        {ok, Tournament} ->
            _ = asobi_tournament_sup:start_tournament(Tournament),
            {json, Tournament};
        {error, CS1} ->
            {json, 422, #{}, #{errors => kura_changeset:traverse_errors(CS1, fun(_F, M) -> M end)}}
    end.
