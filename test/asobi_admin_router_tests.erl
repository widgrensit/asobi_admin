-module(asobi_admin_router_tests).
-moduledoc ~"""
The pre-session login route's CSRF exemption is structural now (it is simply
never wired to asobi_admin_csrf_plugin), not a path-string exclusion - see
asobi_admin_csrf_plugin's moduledoc for why. That invariant lives in router
configuration, not in code either plugin runs, so nothing else would catch a
regression if a future change re-merged the two route groups or added a new
unprotected POST route. This test reads the router's own route table and
enforces the shape directly.
""".

-include_lib("eunit/include/eunit.hrl").

login_group_has_no_csrf_plugin_test() ->
    Group = login_group(),
    Plugins = maps:get(plugins, Group),
    ?assertNot(lists:any(fun is_csrf_plugin/1, Plugins)).

ui_group_has_csrf_plugin_test() ->
    Group = ui_group(),
    Plugins = maps:get(plugins, Group),
    ?assert(lists:any(fun is_csrf_plugin/1, Plugins)).

every_post_route_outside_login_is_csrf_protected_test() ->
    LoginPaths = [Path || {Path, _Fun, Opts} <- maps:get(routes, login_group()), is_post(Opts)],
    ?assertEqual([~"/login"], LoginPaths).

both_ui_groups_share_the_admin_ui_prefix_test() ->
    ?assertEqual(~"/admin/ui", maps:get(prefix, login_group())),
    ?assertEqual(~"/admin/ui", maps:get(prefix, ui_group())).

%% Every unauthenticated route group must cap the request body before
%% nova_request_plugin reads it - Nova's pre_request plugins run before the
%% `security` fun, so the bearer-token check on /admin/api and the session
%% check inside each /admin/ui controller both happen too late to stop an
%% unbounded read on their own.
every_unauthenticated_group_has_body_limit_before_request_plugin_test() ->
    lists:foreach(
        fun(Group) ->
            Plugins = maps:get(plugins, Group, []),
            Names = [Mod || {pre_request, Mod, _} <- Plugins],
            BodyLimitIdx = index_of(asobi_admin_body_limit_plugin, Names),
            RequestPluginIdx = index_of(nova_request_plugin, Names),
            ?assert(BodyLimitIdx =/= not_found),
            ?assert(RequestPluginIdx =/= not_found),
            ?assert(BodyLimitIdx < RequestPluginIdx)
        end,
        [api_group(), login_group(), ui_group()]
    ).

%% Internal

api_group() ->
    find_group(fun(#{prefix := Prefix}) -> Prefix =:= ~"/admin/api" end).

login_group() ->
    find_group(fun(#{routes := Routes}) ->
        lists:any(fun({Path, _, _}) -> Path =:= ~"/login" end, Routes)
    end).

ui_group() ->
    find_group(fun(#{routes := Routes}) ->
        lists:any(fun({Path, _, _}) -> Path =:= ~"/logout" end, Routes)
    end).

index_of(Item, List) ->
    index_of(Item, List, 1).

index_of(_Item, [], _N) -> not_found;
index_of(Item, [Item | _], N) -> N;
index_of(Item, [_ | Rest], N) -> index_of(Item, Rest, N + 1).

find_group(Pred) ->
    Groups = [G || G <- asobi_admin_router:routes(dev), maps:is_key(routes, G)],
    [Group] = [G || G <- Groups, Pred(G)],
    Group.

is_post(#{methods := Methods}) -> lists:member(post, Methods);
is_post(_) -> false.

is_csrf_plugin({pre_request, asobi_admin_csrf_plugin, _}) -> true;
is_csrf_plugin(_) -> false.
