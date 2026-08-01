-module(asobi_admin_matchmaker_controller).
-moduledoc "Console UI: matchmaker queue inspection.".

-export([index/1]).

-spec index(cowboy_req:req()) -> {ok, map()} | {redirect, binary()}.
index(Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        {ok, #{
            active_page => ~"matchmaker",
            csrf_token => maps:get(csrf_token, Req, ~""),
            live_plane_authoritative => asobi_admin_runtime:live_plane_authoritative(),
            deployment_mode => atom_to_binary(asobi_admin_runtime:mode())
        }}
    end).
