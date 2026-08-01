-module(asobi_admin_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-spec start_link() -> {ok, pid()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    %% The session and rate-limit ETS tables are created here, in the
    %% supervisor, rather than owned by asobi_admin_sweeper: the sweeper only
    %% purges rows from them periodically and correctness never depends on it
    %% running, so the tables must outlive it if it ever restarts.
    ok = asobi_admin_session:init(),
    ok = asobi_admin_login_rate_limit:init(),
    Children = [
        #{
            id => asobi_admin_sweeper,
            start => {asobi_admin_sweeper, start_link, []}
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 5, period => 60}, Children}}.
