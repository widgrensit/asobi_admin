-module(asobi_admin_static_controller_tests).

-include_lib("eunit/include/eunit.hrl").

req(File) ->
    #{bindings => #{~"file" => File}}.

known_file_is_served_test() ->
    ?assertMatch({status, 200, _, _}, asobi_admin_static_controller:serve_css(req(~"console.css"))).

unknown_file_is_404_test() ->
    ?assertEqual({status, 404}, asobi_admin_static_controller:serve_css(req(~"nonexistent.css"))).

%% This is an exact-filename allowlist, not a general path-based file server,
%% so a traversal payload can never match a listed key - there is no path to
%% sanitize. Covers the %2F-decoded-into-a-binding shape a route pattern like
%% `:file` cannot otherwise prevent.
traversal_payload_is_404_test() ->
    ?assertEqual(
        {status, 404}, asobi_admin_static_controller:serve_css(req(~"../../../etc/passwd"))
    ),
    ?assertEqual(
        {status, 404},
        asobi_admin_static_controller:serve_css(req(~"../../../vm.args"))
    ).

missing_binding_is_404_test() ->
    ?assertEqual({status, 404}, asobi_admin_static_controller:serve_css(#{})).
