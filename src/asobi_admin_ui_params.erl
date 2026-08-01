-module(asobi_admin_ui_params).
-moduledoc "Defensive integer parsing shared by the console UI's controllers.".

-export([int_param/4, int/1]).

-doc """
Parses Key out of a proplists-shaped Params list as an integer, clamped to
[0, Max]. Falls back to Default on a missing or unparseable value instead
of crashing the controller (a bare binary_to_integer/1 turns a request
like `?limit=abc` into an unhandled 500), and Max bounds an
otherwise-unbounded query like `?limit=100000000`.
""".
-spec int_param([{binary(), binary()}], binary(), non_neg_integer(), pos_integer()) ->
    non_neg_integer().
int_param(Params, Key, Default, Max) ->
    case proplists:get_value(Key, Params) of
        undefined ->
            Default;
        Raw ->
            case int(Raw) of
                {ok, V} -> min(max(V, 0), Max);
                error -> Default
            end
    end.

-doc "Parses a binary as an integer without crashing on a malformed value.".
-spec int(binary()) -> {ok, integer()} | error.
int(Bin) ->
    try
        {ok, binary_to_integer(Bin)}
    catch
        error:badarg -> error
    end.
