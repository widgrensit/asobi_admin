-module(asobi_admin_runtime_tests).

-include_lib("eunit/include/eunit.hrl").

mode_test_() ->
    {foreach, fun() -> ok end, fun(_) -> application:unset_env(asobi_admin, deployment_mode) end, [
        fun defaults_to_standalone/0,
        fun atom_embedded/0,
        fun binary_embedded/0,
        fun string_embedded/0,
        fun unknown_is_standalone/0,
        fun authoritative_only_when_embedded/0
    ]}.

defaults_to_standalone() ->
    application:unset_env(asobi_admin, deployment_mode),
    ?assertEqual(standalone, asobi_admin_runtime:mode()),
    ?assertNot(asobi_admin_runtime:live_plane_authoritative()).

atom_embedded() ->
    application:set_env(asobi_admin, deployment_mode, embedded),
    ?assertEqual(embedded, asobi_admin_runtime:mode()).

binary_embedded() ->
    application:set_env(asobi_admin, deployment_mode, ~"embedded"),
    ?assertEqual(embedded, asobi_admin_runtime:mode()).

string_embedded() ->
    application:set_env(asobi_admin, deployment_mode, "embedded"),
    ?assertEqual(embedded, asobi_admin_runtime:mode()).

unknown_is_standalone() ->
    application:set_env(asobi_admin, deployment_mode, ~"whatever"),
    ?assertEqual(standalone, asobi_admin_runtime:mode()).

authoritative_only_when_embedded() ->
    application:set_env(asobi_admin, deployment_mode, embedded),
    ?assert(asobi_admin_runtime:live_plane_authoritative()),
    application:set_env(asobi_admin, deployment_mode, standalone),
    ?assertNot(asobi_admin_runtime:live_plane_authoritative()).
