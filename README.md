# asobi_admin

A game-operations console for a self-hosted [asobi](https://github.com/widgrensit/asobi)
backend: search and moderate players, inspect matches and the matchmaker,
manage the economy and tournaments, read chat, broadcast notifications, and
watch live system stats.

It is a [Nova](https://github.com/novaframework/nova) app that depends on the
`asobi` library, talks to the same Postgres database as your game backend, and
exposes a JSON API under `/admin/api/*` plus a live-stats websocket at
`/admin/live/dashboard`.

## Deployment model (read this first)

asobi_admin has two kinds of endpoint, and where you run it decides which
work:

- **Data-plane** (players, economy, tournaments, match history, chat history):
  reads Postgres directly, so it works from any node that shares your game
  backend's database.
- **Live-plane** (online presence, matchmaker queue, and `/admin/api/system`
  BEAM stats): reads *in-memory* runtime state of the node it runs on.

Because the live-plane reads local node state, **run asobi_admin in the same
release as your asobi backend** so those calls see the real game runtime.
Running it as a separate container that only shares the database gives you a
correct data-plane but the live-plane will report the console's own (idle)
node - online counts of zero, an empty matchmaker, and the console's own VM
stats. Prefer same-release unless you only need data-plane administration.

> A managed, per-environment console that runs out-of-process is on the
> roadmap; it depends on asobi first exposing presence and matchmaker
> snapshots on its public API so the live-plane can be read remotely without
> clustering. Until then, same-release is the supported way to get the full
> console.

### Run it in your asobi release (recommended)

Add the dependency:

```erlang
%% rebar.config
{deps, [
    {asobi, {git, "https://github.com/widgrensit/asobi.git", {branch, "main"}}},
    {asobi_admin, {git, "https://github.com/widgrensit/asobi_admin.git", {branch, "main"}}}
]}.
```

Add it to your release's application list so it boots on the same node:

```erlang
{relx, [{release, {my_backend, "1.0.0"}, [asobi, asobi_admin, sasl]}]}.
```

asobi_admin serves on its own Nova listener; point it at the same
`asobi_repo` database your backend uses.

## Configuration

| Setting | Env var | Purpose |
|---|---|---|
| `asobi_admin.admin_token` | `ASOBI_ADMIN_TOKEN` | Bearer token required on every request. **No default - unset means every request is denied.** |
| distribution cookie | `RELEASE_COOKIE` | Erlang distribution cookie. Never commit it. |

The admin API is unauthenticated-by-nothing: it is protected by a single
bearer token, compared in constant time, and **fails closed** - if
`ASOBI_ADMIN_TOKEN` is unset (or left as an unexpanded `${...}` placeholder)
the console denies everything rather than opening up. Set a long random value:

```sh
export ASOBI_ADMIN_TOKEN="$(head -c 32 /dev/urandom | base64)"
export RELEASE_COOKIE="$(head -c 32 /dev/urandom | base64)"
```

Because the console can ban players and grant currency, treat both like
database credentials: keep them in your secret store, put the console on a
private network, and never expose `/admin` to the public internet.

## Authentication

Every `/admin/api/*` request needs a bearer token:

```sh
curl -H "Authorization: Bearer $ASOBI_ADMIN_TOKEN" \
     http://localhost:8083/admin/api/players
```

The live-stats websocket authenticates in-protocol (browsers cannot set
`Authorization` on a websocket): connect, then send the first frame

```json
{"type": "auth", "token": "<ASOBI_ADMIN_TOKEN>"}
```

within 5 seconds. Stats stream only after the token is accepted; an
unauthenticated socket is closed with code 1008.

## API

All paths are prefixed with `/admin/api`.

| Area | Endpoints |
|---|---|
| Dashboard / system | `GET /dashboard`, `GET /system`, `GET /system/nodes` |
| Players | `GET /players`, `GET /players/search`, `GET /players/:id`, `POST /players/:id/ban`, `POST /players/:id/unban`, `POST /players/:id/grant` |
| Matches | `GET /matches`, `GET /matches/:id` |
| Matchmaker | `GET /matchmaker` |
| Leaderboards | `GET /leaderboards/:id` |
| Economy | `GET /economy`, `GET /economy/items`, `POST /economy/items`, `GET /economy/listings`, `POST /economy/listings` |
| Tournaments | `GET /tournaments`, `POST /tournaments`, `GET /tournaments/:id` |
| Chat | `GET /chat/channels`, `GET /chat/:channel_id/messages` |
| Notifications | `POST /notifications/broadcast` |

Live stats: websocket `GET /admin/live/dashboard`.

## Development

```sh
rebar3 compile
rebar3 eunit
rebar3 shell   # uses config/dev_sys.config.src; set ASOBI_ADMIN_TOKEN first
```

There is no web UI yet - asobi_admin is an API today, consumed by the asobi
control plane and by your own tooling. A bundled UI is a possible follow-up.

## License

Apache-2.0.
