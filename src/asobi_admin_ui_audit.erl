-module(asobi_admin_ui_audit).
-moduledoc ~"""
Audit logging for the console UI's state-changing actions.

Logs after the action runs, never before (a rejected action must never be
recorded as having happened), and records the real outcome rather than
assuming success: a console whose audit log records a failed ban or a
rejected currency grant as completed is worse than one with no log.
""".

-include_lib("kernel/include/logger.hrl").

-export([log_action/3]).

-doc "Fields is merged into the log report; Result is the do_* call's own return value.".
-spec log_action(binary(), map(), {ok, term()} | {error, term()}) -> ok.
log_action(Action, Fields, {ok, _}) ->
    ?LOG_NOTICE((Fields#{msg => ~"admin_action", action => Action, outcome => ~"ok"}));
log_action(Action, Fields, {error, Reason}) ->
    ?LOG_WARNING((Fields#{msg => ~"admin_action_failed", action => Action, reason => Reason})).
