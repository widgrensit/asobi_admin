-module(asobi_admin_live_dashboard).
-behaviour(nova_websocket).

-moduledoc """
Live system-stats stream for the admin dashboard.

Nova's ws upgrade has no clean pre-upgrade rejection path (any non-ok init
renders a 500) and browsers cannot set headers on websocket requests, so the
socket authenticates in-protocol instead: the first frame must be
`{"type": "auth", "token": "..."}`. Nothing is streamed before that, and a
client that fails to authenticate within the idle window is closed with 1008.
This mirrors the asobi library's own ws auth model.
""".

-export([init/1, websocket_init/1, websocket_handle/2, websocket_info/2, terminate/3]).

-define(REFRESH_INTERVAL, 2000).
-define(IDLE_AUTH_TIMEOUT, 5000).

-spec init(map()) -> {ok, map()}.
init(State) ->
    {ok, State}.

-spec websocket_init(map()) -> {ok, map()}.
websocket_init(State) ->
    erlang:send_after(?IDLE_AUTH_TIMEOUT, self(), idle_auth_timeout),
    {ok, State#{authed => false}}.

-spec websocket_handle({text | binary, binary()}, map()) ->
    {ok, map()} | {reply, {text, iodata()} | {close, 1008, binary()}, map()}.
websocket_handle({text, Raw}, #{authed := false} = State) ->
    case auth_frame(Raw) of
        {ok, Token} ->
            case asobi_admin_auth:check_token(Token) of
                true ->
                    erlang:send_after(?REFRESH_INTERVAL, self(), refresh),
                    Reply = json:encode(#{
                        ~"type" => ~"dashboard.init", ~"payload" => collect_stats()
                    }),
                    {reply, {text, Reply}, State#{authed => true}};
                false ->
                    {reply, {close, 1008, ~"unauthorized"}, State}
            end;
        error ->
            {reply, {close, 1008, ~"unauthorized"}, State}
    end;
websocket_handle({text, _Raw}, State) ->
    {ok, State};
websocket_handle(_Frame, State) ->
    {ok, State}.

-spec websocket_info(term(), map()) ->
    {ok, map()} | {reply, {text, iodata()} | {close, 1008, binary()}, map()}.
websocket_info(refresh, #{authed := true} = State) ->
    erlang:send_after(?REFRESH_INTERVAL, self(), refresh),
    Reply = json:encode(#{~"type" => ~"dashboard.update", ~"payload" => collect_stats()}),
    {reply, {text, Reply}, State};
websocket_info(idle_auth_timeout, #{authed := false} = State) ->
    {reply, {close, 1008, ~"auth_timeout"}, State};
websocket_info(_Info, State) ->
    {ok, State}.

-spec terminate(term(), term(), map()) -> ok.
terminate(_Reason, _Req, _State) ->
    ok.

%% --- Internal ---

-spec auth_frame(binary()) -> {ok, binary()} | error.
auth_frame(Raw) ->
    try json:decode(Raw) of
        #{~"type" := ~"auth", ~"token" := Token} when is_binary(Token) ->
            {ok, Token};
        _ ->
            error
    catch
        _:_ ->
            error
    end.

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
