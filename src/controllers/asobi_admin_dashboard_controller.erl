-module(asobi_admin_dashboard_controller).
-moduledoc "Console UI: overview dashboard.".

-export([index/1]).

-spec index(cowboy_req:req()) -> {ok, map()} | {redirect, binary()}.
index(Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        {ok, #{
            active_page => ~"dashboard",
            csrf_token => maps:get(csrf_token, Req, ~""),
            stats => asobi_admin_dashboard:stats()
        }}
    end).
