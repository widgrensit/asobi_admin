-module(asobi_admin_notifications).

-export([broadcast/1]).
-export([do_broadcast/4]).

-spec broadcast(cowboy_req:req()) -> {json, map()}.
broadcast(#{json := Params} = _Req) ->
    Type = maps:get(~"type", Params, ~"system"),
    Subject = maps:get(~"subject", Params),
    Content = maps:get(~"content", Params, #{}),
    PlayerIds = maps:get(~"player_ids", Params, []),
    {json, #{sent_to => do_broadcast(Type, Subject, Content, PlayerIds)}}.

-spec do_broadcast(binary(), binary(), map(), [binary()]) -> [binary()].
do_broadcast(Type, Subject, Content, PlayerIds) ->
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
    lists:filter(fun(X) -> X =/= undefined end, Sent).
