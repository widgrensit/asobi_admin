-module(asobi_admin_body_limit_plugin_tests).

-include_lib("eunit/include/eunit.hrl").

pre(Req, Options) ->
    asobi_admin_body_limit_plugin:pre_request(Req, undefined, Options, state).

no_body_passes_test() ->
    Req = #{body_length => 0},
    ?assertMatch({ok, _, state}, pre(Req, #{})).

body_under_cap_passes_test() ->
    Req = #{body_length => 100},
    ?assertMatch({ok, _, state}, pre(Req, #{max_bytes => 1000})).

body_over_cap_is_rejected_test() ->
    Req = #{body_length => 2000},
    ?assertMatch({stop, {reply, 413, _, _}, _, state}, pre(Req, #{max_bytes => 1000})).

%% cowboy sets body_length to `undefined` for a chunked request (no declared
%% length) - this is the shape that let an unauthenticated request buffer an
%% arbitrarily large body before this plugin existed.
chunked_body_with_no_length_is_rejected_test() ->
    Req = #{body_length => undefined},
    ?assertMatch({stop, {reply, 413, _, _}, _, state}, pre(Req, #{max_bytes => 1000})).

default_cap_applies_without_options_test() ->
    Req = #{body_length => 999_999_999},
    ?assertMatch({stop, {reply, 413, _, _}, _, state}, pre(Req, #{})).
