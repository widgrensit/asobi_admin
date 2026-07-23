-module(asobi_admin_dashboard).

-export([index/1]).

-spec index(cowboy_req:req()) -> {json, map()}.
index(_Req) ->
    Memory = erlang:memory(),
    {json, #{
        status => ~"ok",
        online_players => asobi_presence:online_count(),
        %% online_players is in-memory node state; false here means the
        %% console is not co-located with the backend, so the count is not
        %% authoritative (see asobi_admin_runtime).
        live_plane_authoritative => asobi_admin_runtime:live_plane_authoritative(),
        deployment_mode => atom_to_binary(asobi_admin_runtime:mode()),
        node => atom_to_binary(node()),
        memory => #{
            total => proplists:get_value(total, Memory),
            processes => proplists:get_value(processes, Memory),
            ets => proplists:get_value(ets, Memory),
            binary => proplists:get_value(binary, Memory)
        },
        uptime_ms => element(1, erlang:statistics(wall_clock)),
        process_count => erlang:system_info(process_count),
        scheduler_count => erlang:system_info(schedulers_online),
        run_queue => erlang:statistics(run_queue),
        otp_release => list_to_binary(erlang:system_info(otp_release)),
        erts_version => list_to_binary(erlang:system_info(version))
    }}.
