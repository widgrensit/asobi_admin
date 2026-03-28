-module(asobi_admin_leaderboards).

-export([show/1]).

-spec show(cowboy_req:req()) -> {json, map()}.
show(#{bindings := #{~"id" := BoardId}, qs := Qs} = _Req) ->
    Params = cow_qs:parse_qs(Qs),
    Limit = binary_to_integer(proplists:get_value(~"limit", Params, ~"100")),
    Entries = asobi_leaderboard_server:top(BoardId, Limit),
    {json, #{
        leaderboard_id => BoardId,
        entries => [#{player_id => P, score => S, rank => R} || {P, S, R} <- Entries],
        total => length(Entries)
    }}.
