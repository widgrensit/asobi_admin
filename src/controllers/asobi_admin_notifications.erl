-module(asobi_admin_notifications).

-export([broadcast/1]).

-spec broadcast(cowboy_req:req()) -> {json, map()}.
broadcast(#{json := Params} = _Req) ->
    Type = maps:get(~"type", Params, ~"system"),
    Subject = maps:get(~"subject", Params),
    Content = maps:get(~"content", Params, #{}),
    PlayerIds = maps:get(~"player_ids", Params, []),
    Sent = lists:map(
        fun(PlayerId) ->
            CS = kura_changeset:cast(
                asobi_notification,
                #{},
                #{
                    player_id => PlayerId,
                    type => Type,
                    subject => Subject,
                    content => Content,
                    sent_at => calendar:universal_time()
                },
                [player_id, type, subject, content, sent_at]
            ),
            case asobi_repo:insert(CS) of
                {ok, Notif} ->
                    asobi_presence:send(PlayerId, {notification, Notif}),
                    PlayerId;
                {error, _} ->
                    undefined
            end
        end,
        PlayerIds
    ),
    {json, #{sent_to => lists:filter(fun(X) -> X =/= undefined end, Sent)}}.
