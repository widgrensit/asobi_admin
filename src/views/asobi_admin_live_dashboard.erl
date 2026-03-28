-module(asobi_admin_live_dashboard).
-behaviour(nova_websocket).

-export([init/1, websocket_init/1, websocket_handle/2, websocket_info/2, terminate/3]).

-define(REFRESH_INTERVAL, 2000).

-spec init(map()) -> {ok, map()}.
init(State) ->
    {ok, State}.

-spec websocket_init(map()) -> {reply, {text, binary()}, map()}.
websocket_init(State) ->
    erlang:send_after(?REFRESH_INTERVAL, self(), refresh),
    Reply = json:encode(#{~"type" => ~"dashboard.init", ~"payload" => collect_stats()}),
    {reply, {text, Reply}, State}.

-spec websocket_handle({text | binary, binary()}, map()) -> {ok, map()}.
websocket_handle({text, _Raw}, State) ->
    {ok, State};
websocket_handle(_Frame, State) ->
    {ok, State}.

-spec websocket_info(term(), map()) -> {reply, {text, binary()}, map()}.
websocket_info(refresh, State) ->
    erlang:send_after(?REFRESH_INTERVAL, self(), refresh),
    Reply = json:encode(#{~"type" => ~"dashboard.update", ~"payload" => collect_stats()}),
    {reply, {text, Reply}, State};
websocket_info(_Info, State) ->
    {ok, State}.

-spec terminate(term(), term(), map()) -> ok.
terminate(_Reason, _Req, _State) ->
    ok.

%% --- Internal ---

-spec collect_stats() -> map().
collect_stats() ->
    Memory = erlang:memory(),
    #{
        online_players => asobi_presence:online_count(),
        process_count => erlang:system_info(process_count),
        memory_total => proplists:get_value(total, Memory),
        memory_processes => proplists:get_value(processes, Memory),
        memory_ets => proplists:get_value(ets, Memory),
        run_queue => erlang:statistics(run_queue),
        scheduler_count => erlang:system_info(schedulers_online),
        node => atom_to_binary(node()),
        uptime_ms => element(1, erlang:statistics(wall_clock))
    }.
