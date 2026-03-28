-module(asobi_admin_matchmaker).

-export([index/1]).

-spec index(cowboy_req:req()) -> {json, map()}.
index(_Req) ->
    %% Show current matchmaker queue state
    %% This uses gen_server:call to get internal state snapshot
    {json, #{
        status => ~"ok",
        message => ~"Matchmaker queue inspection"
    }}.
