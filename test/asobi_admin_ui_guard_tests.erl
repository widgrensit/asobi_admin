-module(asobi_admin_ui_guard_tests).
-moduledoc """
The session guard lives in each controller (via asobi_admin_ui_auth:guarded/2)
rather than in the router's `security` fun, so nothing structurally prevents
a new controller action from omitting it. Drive the router's own route table
and assert the invariant holds for every GET route in the session-protected
group.
""".

-include_lib("eunit/include/eunit.hrl").

every_ui_get_route_redirects_when_unauthenticated_test() ->
    asobi_admin_session:init(),
    Routes = get_routes(ui_group()),
    ?assert(length(Routes) > 5),
    Results = [{Path, probe(Fun)} || {Path, Fun, _} <- Routes],
    Failures = [{Path, Result} || {Path, Result} <- Results, Result =/= redirect],
    ?assertEqual([], Failures).

%% Internal

probe(Fun) ->
    Req = #{
        method => ~"GET",
        scheme => ~"http",
        path => ~"/admin/ui/probe",
        qs => <<>>,
        headers => #{},
        params => #{},
        bindings => #{~"id" => ~"probe-id", ~"channel_id" => ~"probe-channel"}
    },
    try Fun(Req) of
        {redirect, _} -> redirect;
        Other -> Other
    catch
        Class:Reason -> {crashed, Class, Reason}
    end.

ui_group() ->
    Groups = [G || G <- asobi_admin_router:routes(dev), maps:is_key(routes, G)],
    [Group] = [
        G
     || #{routes := Rs} = G <- Groups,
        lists:any(fun({P, _, _}) -> P =:= ~"/logout" end, Rs)
    ],
    Group.

get_routes(#{routes := Routes}) ->
    [R || {_Path, _Fun, Opts} = R <- Routes, lists:member(get, maps:get(methods, Opts, []))].
