-module(asobi_admin_runtime).

-moduledoc """
Deployment-mode awareness for the console.

The live-plane endpoints (presence, matchmaker, system) read in-memory state
of the node the console runs on. They are only authoritative when the console
runs in the same release as the asobi backend (`embedded`); as a standalone
container sharing only the database (`standalone`), those readings reflect the
console's own idle node, not the game runtime. This module surfaces the mode
so responses can flag whether their live figures can be trusted, rather than
reporting zeros as if they were real.

Set via `asobi_admin.deployment_mode` (env `ASOBI_ADMIN_DEPLOYMENT_MODE`),
`embedded` | `standalone`; defaults to `standalone` (the safe, honest default
- it never claims live data is authoritative unless told so).
""".

-export([mode/0, live_plane_authoritative/0]).

-spec mode() -> embedded | standalone.
mode() ->
    case application:get_env(asobi_admin, deployment_mode) of
        {ok, embedded} -> embedded;
        {ok, ~"embedded"} -> embedded;
        {ok, "embedded"} -> embedded;
        _ -> standalone
    end.

-spec live_plane_authoritative() -> boolean().
live_plane_authoritative() ->
    mode() =:= embedded.
