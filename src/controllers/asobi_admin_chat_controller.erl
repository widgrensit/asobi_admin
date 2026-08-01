-module(asobi_admin_chat_controller).
-moduledoc "Console UI: active chat channels and message history.".

-export([index/1, show/1]).

-spec index(cowboy_req:req()) -> {ok, map()} | {redirect, binary()}.
index(Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        Members = pg:which_groups(asobi_chat),
        Channels = lists:filtermap(
            fun
                ({chat, ChannelId}) ->
                    Count = length(pg:get_members(asobi_chat, {chat, ChannelId})),
                    {true, #{channel_id => ChannelId, member_count => Count}};
                (_) ->
                    false
            end,
            Members
        ),
        {ok, #{
            active_page => ~"chat",
            csrf_token => maps:get(csrf_token, Req, ~""),
            channels => Channels
        }}
    end).

-spec show(cowboy_req:req()) -> {ok, map()} | {redirect, binary()}.
show(#{bindings := #{~"channel_id" := ChannelId}} = Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        Q = kura_query:limit(
            kura_query:order_by(
                kura_query:where(kura_query:from(asobi_chat_message), {channel_id, ChannelId}),
                [{sent_at, desc}]
            ),
            50
        ),
        {ok, Messages} = asobi_repo:all(Q),
        {ok, #{
            active_page => ~"chat",
            csrf_token => maps:get(csrf_token, Req, ~""),
            channel_id => ChannelId,
            messages => lists:reverse(Messages)
        }}
    end).
