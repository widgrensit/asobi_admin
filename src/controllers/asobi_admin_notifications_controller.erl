-module(asobi_admin_notifications_controller).
-moduledoc "Console UI: broadcast a notification to one or more players.".

-export([index/1, broadcast/1]).

-define(MAX_RECIPIENTS, 500).

-spec index(cowboy_req:req()) -> {ok, map()} | {redirect, binary()}.
index(#{qs := Qs} = Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        Params = cow_qs:parse_qs(Qs),
        Sent = asobi_admin_ui_params:int_param(Params, ~"sent", 0, ?MAX_RECIPIENTS),
        {ok, #{
            active_page => ~"notifications",
            csrf_token => maps:get(csrf_token, Req, ~""),
            sent_count => Sent
        }}
    end).

%% Redirects after broadcasting (post/redirect/get), unlike the other
%% action handlers which redirect back to a fixed page: without it, every
%% other handler leaves the browser on a GET-able page, but this one would
%% leave it on the POST URL, so a refresh re-broadcasts to up to
%% ?MAX_RECIPIENTS players again.
-spec broadcast(cowboy_req:req()) ->
    {status, integer(), map(), binary(), cowboy_req:req()} | {redirect, binary()}.
broadcast(Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        Params = maps:get(params, Req, #{}),
        Type = maps:get(~"type", Params, ~"system"),
        Subject = maps:get(~"subject", Params, ~""),
        PlayerIds = parse_player_ids(maps:get(~"player_ids", Params, ~"")),
        SentTo = asobi_admin_notifications:do_broadcast(Type, Subject, #{}, PlayerIds),
        asobi_admin_ui_audit:log_action(
            ~"broadcast", #{recipient_count => length(SentTo)}, {ok, SentTo}
        ),
        Location = <<"/admin/ui/notifications?sent=", (integer_to_binary(length(SentTo)))/binary>>,
        {status, 302, #{~"location" => Location}, <<>>, Req}
    end).

-spec parse_player_ids(binary()) -> [binary()].
parse_player_ids(Raw) ->
    Trimmed = [string:trim(Id) || Id <- binary:split(Raw, [~",", ~"\n"], [global])],
    Deduped = lists:usort([Id || Id <- Trimmed, Id =/= <<>>]),
    lists:sublist(Deduped, ?MAX_RECIPIENTS).
