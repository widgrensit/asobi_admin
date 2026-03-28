-module(asobi_admin_chat).

-export([channels/1, messages/1]).

-spec channels(cowboy_req:req()) -> {json, map()}.
channels(_Req) ->
    %% List active chat channels from pg groups
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
    {json, #{channels => Channels}}.

-spec messages(cowboy_req:req()) -> {json, map()}.
messages(#{bindings := #{~"channel_id" := ChannelId}, qs := Qs} = _Req) ->
    Params = cow_qs:parse_qs(Qs),
    Limit = binary_to_integer(proplists:get_value(~"limit", Params, ~"50")),
    Q = kura_query:limit(
        kura_query:order_by(
            kura_query:where(kura_query:from(asobi_chat_message), {channel_id, ChannelId}),
            [{sent_at, desc}]
        ),
        Limit
    ),
    {ok, Messages} = asobi_repo:all(Q),
    {json, #{channel_id => ChannelId, messages => lists:reverse(Messages)}}.
