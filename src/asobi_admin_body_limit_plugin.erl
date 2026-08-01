-module(asobi_admin_body_limit_plugin).
-behaviour(nova_plugin).
-moduledoc ~"""
Rejects any console UI request whose body is missing a length (chunked, so
unbounded) or declares a length over the cap, before `nova_request_plugin`
ever reads it into memory.

Must run before `nova_request_plugin` in the plugin list: that plugin's
`read_body/2` loops `cowboy_req:read_body/1` accumulating the whole body into
one binary with no cap of its own, and it runs on `/admin/ui/login` before
any auth or rate-limit check - unbounded, that is an unauthenticated memory
exhaustion route on a node the README documents running co-located with the
game backend.
""".

-include_lib("kernel/include/logger.hrl").

-export([pre_request/4, post_request/4, plugin_info/0]).

-define(MAX_BODY_BYTES, 65_536).

-spec pre_request(cowboy_req:req(), any(), map(), any()) ->
    {ok, cowboy_req:req(), any()} | {stop, nova_plugin:reply(), cowboy_req:req(), any()}.
pre_request(Req, _Env, Options, State) ->
    Max = maps:get(max_bytes, Options, ?MAX_BODY_BYTES),
    case cowboy_req:body_length(Req) of
        0 ->
            {ok, Req, State};
        Len when is_integer(Len), Len =< Max ->
            {ok, Req, State};
        _ ->
            ?LOG_WARNING(#{msg => ~"admin_body_too_large", peer => peer(Req)}),
            {stop, {reply, 413, [{~"content-type", ~"text/plain"}], ~"Payload too large"}, Req,
                State}
    end.

-spec post_request(cowboy_req:req(), any(), map(), any()) -> {ok, cowboy_req:req(), any()}.
post_request(Req, _Env, _Options, State) ->
    {ok, Req, State}.

-spec plugin_info() -> map().
plugin_info() ->
    #{
        title => ~"Asobi Admin Body Limit Plugin",
        version => ~"1.0.0",
        url => ~"https://github.com/widgrensit/asobi_admin",
        authors => [~"Asobi"],
        description => ~"Caps request body size before it is read into memory.",
        options => [{max_bytes, ~"Maximum accepted body size in bytes (default 65536)"}]
    }.

-spec peer(cowboy_req:req()) -> binary().
peer(Req) ->
    try
        {IP, _Port} = cowboy_req:peer(Req),
        list_to_binary(inet:ntoa(IP))
    catch
        _:_ -> ~"unknown"
    end.
