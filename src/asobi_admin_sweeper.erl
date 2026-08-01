-module(asobi_admin_sweeper).
-behaviour(gen_server).
-moduledoc ~"""
Periodically purges expired rows from the session table and stale windows
from the login rate-limit table.

Both tables reap lazily otherwise (a session only on the lookup that finds it
expired; a rate-limit window only when its owner's next attempt happens to
land after it expires), so without this each grows by one row per login, or
per distinct login-attempt source address, for as long as the node runs.
Purely a size bound - correctness never depends on the sweep running.
""".

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SWEEP_INTERVAL_MS, 300_000).

-spec start_link() -> {ok, pid()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec init([]) -> {ok, undefined}.
init([]) ->
    schedule_sweep(),
    {ok, undefined}.

-spec handle_call(term(), gen_server:from(), undefined) -> {reply, ok, undefined}.
handle_call(_Request, _From, State) ->
    {reply, ok, State}.

-spec handle_cast(term(), undefined) -> {noreply, undefined}.
handle_cast(_Request, State) ->
    {noreply, State}.

-spec handle_info(term(), undefined) -> {noreply, undefined}.
handle_info(sweep, State) ->
    _ = asobi_admin_session:sweep_expired(),
    _ = asobi_admin_login_rate_limit:sweep_expired(),
    schedule_sweep(),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

-spec schedule_sweep() -> reference().
schedule_sweep() ->
    erlang:send_after(?SWEEP_INTERVAL_MS, self(), sweep).
