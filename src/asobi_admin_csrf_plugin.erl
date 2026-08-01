-module(asobi_admin_csrf_plugin).
-behaviour(nova_plugin).
-moduledoc ~"""
CSRF protection for the browser-facing console UI, using the synchroniser-token
pattern bound to the `admin_session` cookie (see `asobi_admin_csrf`).

Scoped to the session-authenticated `/admin/ui` route group as a `pre_request`
plugin, after `nova_request_plugin` so that urlencoded form fields are parsed.
On safe methods it injects the current token under `csrf_token` for templates
to render; on state-changing methods it requires a matching token (in the
`x-csrf-token` header for fetch requests, or the `_csrf_token` form field for
plain HTML forms).

The token is only issued/accepted for a cookie value that resolves to a real,
unexpired session (`asobi_admin_session:get/1`) - an attacker-chosen cookie
value that was never issued by `asobi_admin_login_controller` gets no token,
so this plugin is a second, independent layer rather than only as strong as
the session cookie's own confidentiality.

The pre-session login endpoint is not wired to this plugin at all (see
`asobi_admin_router:admin_ui_login_routes/0`) rather than being excluded by
path: a path-string exclusion is not a structurally safe boundary, since a
CSRF-scoped plugin only sees `cowboy_req`'s raw, pre-routing-normalisation
path, while Nova's router matches on a decoded and dot-segment-normalised
path - the two can disagree on what a given request "is".
""".

-export([pre_request/4, post_request/4, plugin_info/0]).

-spec pre_request(cowboy_req:req(), any(), map(), any()) ->
    {ok, cowboy_req:req(), any()} | {stop, nova_plugin:reply(), cowboy_req:req(), any()}.
pre_request(Req = #{method := Method}, _Env, _Options, State) ->
    case is_safe(Method) of
        true -> {ok, inject(Req), State};
        false -> validate(Req, State)
    end.

-spec post_request(cowboy_req:req(), any(), map(), any()) -> {ok, cowboy_req:req(), any()}.
post_request(Req, _Env, _Options, State) ->
    {ok, Req, State}.

-spec plugin_info() -> map().
plugin_info() ->
    #{
        title => ~"Asobi Admin CSRF Plugin",
        version => ~"2.0.0",
        url => ~"https://github.com/widgrensit/asobi_admin",
        authors => [~"Asobi"],
        description => ~"Session-bound CSRF protection for the console UI.",
        options => []
    }.

-spec inject(cowboy_req:req()) -> cowboy_req:req().
inject(Req) ->
    case active_session_value(Req) of
        undefined ->
            Req;
        Value ->
            case asobi_admin_csrf:token(Value) of
                error -> Req;
                Token -> Req#{csrf_token => Token}
            end
    end.

-spec validate(cowboy_req:req(), any()) ->
    {ok, cowboy_req:req(), any()} | {stop, nova_plugin:reply(), cowboy_req:req(), any()}.
validate(Req, State) ->
    case active_session_value(Req) of
        undefined ->
            reject(Req, State);
        Value ->
            case asobi_admin_csrf:valid(Value, submitted(Req)) of
                true -> {ok, Req#{csrf_token => asobi_admin_csrf:token(Value)}, State};
                false -> reject(Req, State)
            end
    end.

%% Only a cookie value that resolves to a real, unexpired session counts:
%% this is what makes the token a second independent layer rather than a
%% derivative of the cookie's own confidentiality (see moduledoc).
-spec active_session_value(cowboy_req:req()) -> binary() | undefined.
active_session_value(Req) ->
    case asobi_admin_ui_auth:session_cookie(Req) of
        undefined ->
            undefined;
        Value ->
            case asobi_admin_session:get(Value) of
                {ok, _Principal} -> Value;
                _ -> undefined
            end
    end.

-spec submitted(cowboy_req:req()) -> binary() | undefined.
submitted(Req) ->
    case cowboy_req:header(~"x-csrf-token", Req) of
        undefined -> maps:get(~"_csrf_token", maps:get(params, Req, #{}), undefined);
        Value -> Value
    end.

-spec is_safe(binary()) -> boolean().
is_safe(~"GET") -> true;
is_safe(~"HEAD") -> true;
is_safe(~"OPTIONS") -> true;
is_safe(_) -> false.

-spec reject(cowboy_req:req(), any()) -> {stop, nova_plugin:reply(), cowboy_req:req(), any()}.
reject(Req, State) ->
    {stop, {reply, 403, [{~"content-type", ~"text/plain"}], ~"Forbidden - CSRF token invalid"}, Req,
        State}.
