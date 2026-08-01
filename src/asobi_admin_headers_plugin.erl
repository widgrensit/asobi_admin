-module(asobi_admin_headers_plugin).
-behaviour(nova_plugin).
-moduledoc ~"""
Security response headers for the browser-facing console UI: deny framing
(clickjacking - the console can ban players and grant currency, so a framed
page overlaying bait onto those buttons is a real risk that CSRF tokens do
not stop), block MIME sniffing, and disable caching of authenticated pages.

Must run as `pre_request`, not `post_request`: Nova replies to the client
before the post_request pass runs, so headers set there are a silent no-op.
""".

-export([pre_request/4, post_request/4, plugin_info/0]).

-define(HEADERS, #{
    ~"content-security-policy" =>
        ~"default-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'",
    ~"x-frame-options" => ~"DENY",
    ~"x-content-type-options" => ~"nosniff",
    ~"referrer-policy" => ~"same-origin",
    ~"cache-control" => ~"no-store"
}).

-spec pre_request(cowboy_req:req(), any(), map(), any()) -> {ok, cowboy_req:req(), any()}.
pre_request(Req, _Env, _Options, State) ->
    {ok, cowboy_req:set_resp_headers(?HEADERS, Req), State}.

-spec post_request(cowboy_req:req(), any(), map(), any()) -> {ok, cowboy_req:req(), any()}.
post_request(Req, _Env, _Options, State) ->
    {ok, Req, State}.

-spec plugin_info() -> map().
plugin_info() ->
    #{
        title => ~"Asobi Admin Security Headers Plugin",
        version => ~"1.0.0",
        url => ~"https://github.com/widgrensit/asobi_admin",
        authors => [~"Asobi"],
        description => ~"Clickjacking, sniffing, and caching defence for the console UI.",
        options => []
    }.
