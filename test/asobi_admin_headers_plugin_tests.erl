-module(asobi_admin_headers_plugin_tests).

-include_lib("eunit/include/eunit.hrl").

sets_csp_frame_ancestors_none_test() ->
    {ok, Req, state} = asobi_admin_headers_plugin:pre_request(#{}, undefined, #{}, state),
    Headers = maps:get(resp_headers, Req),
    ?assertMatch(#{~"content-security-policy" := CSP} when is_binary(CSP), Headers),
    #{~"content-security-policy" := CSP} = Headers,
    ?assert(binary:match(CSP, ~"frame-ancestors 'none'") =/= nomatch).

sets_x_frame_options_deny_test() ->
    {ok, Req, state} = asobi_admin_headers_plugin:pre_request(#{}, undefined, #{}, state),
    ?assertEqual(~"DENY", maps:get(~"x-frame-options", maps:get(resp_headers, Req))).

sets_no_sniff_test() ->
    {ok, Req, state} = asobi_admin_headers_plugin:pre_request(#{}, undefined, #{}, state),
    ?assertEqual(~"nosniff", maps:get(~"x-content-type-options", maps:get(resp_headers, Req))).

sets_no_store_cache_control_test() ->
    {ok, Req, state} = asobi_admin_headers_plugin:pre_request(#{}, undefined, #{}, state),
    ?assertEqual(~"no-store", maps:get(~"cache-control", maps:get(resp_headers, Req))).

post_request_is_a_passthrough_test() ->
    ?assertEqual(
        {ok, #{some => req}, state},
        asobi_admin_headers_plugin:post_request(#{some => req}, undefined, #{}, state)
    ).
