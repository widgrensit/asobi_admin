-module(asobi_admin_system_controller).
-moduledoc "Console UI: BEAM/system stats for the console's own node.".

-export([index/1]).

-spec index(cowboy_req:req()) -> {ok, map()} | {redirect, binary()}.
index(Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        {ok, #{
            active_page => ~"system",
            csrf_token => maps:get(csrf_token, Req, ~""),
            stats => asobi_admin_system:stats()
        }}
    end).
