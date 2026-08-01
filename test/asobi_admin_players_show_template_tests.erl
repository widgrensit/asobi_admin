-module(asobi_admin_players_show_template_tests).
-moduledoc """
Regression test for the atom-truthiness trap: `asobi_presence:get_status/1`
returns the atom `online` or `offline`, and erlydtl's falsy set does not
include arbitrary atoms, so binding the atom straight into a template
`{% if %}` renders `offline` as truthy. The controller must reduce it to a
real boolean before it reaches the template - this test renders the compiled
template directly so a regression there fails even if the controller-level
test only checks the boolean value, not what the page actually shows.
""".

-include_lib("eunit/include/eunit.hrl").

bindings(Online) ->
    #{
        player => #{id => ~"p1", username => ~"alice", banned_at => undefined},
        online => Online,
        wallets => [],
        csrf_token => ~""
    }.

online_true_renders_online_test() ->
    {ok, Html} = asobi_admin_players_show_dtl:render(bindings(true)),
    Bin = iolist_to_binary(Html),
    ?assert(binary:match(Bin, ~"online") =/= nomatch),
    ?assertEqual(nomatch, binary:match(Bin, ~"offline")).

online_false_renders_offline_test() ->
    {ok, Html} = asobi_admin_players_show_dtl:render(bindings(false)),
    Bin = iolist_to_binary(Html),
    ?assert(binary:match(Bin, ~"offline") =/= nomatch).
