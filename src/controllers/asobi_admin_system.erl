-module(asobi_admin_system).

-export([index/1, nodes/1]).

-spec index(cowboy_req:req()) -> {json, map()}.
index(_Req) ->
    Memory = erlang:memory(),
    {json, #{
        node => atom_to_binary(node()),
        otp_release => list_to_binary(erlang:system_info(otp_release)),
        erts_version => list_to_binary(erlang:system_info(version)),
        schedulers => erlang:system_info(schedulers),
        schedulers_online => erlang:system_info(schedulers_online),
        process_count => erlang:system_info(process_count),
        process_limit => erlang:system_info(process_limit),
        port_count => erlang:system_info(port_count),
        port_limit => erlang:system_info(port_limit),
        atom_count => erlang:system_info(atom_count),
        atom_limit => erlang:system_info(atom_limit),
        ets_count => length(ets:all()),
        memory => #{
            total => proplists:get_value(total, Memory),
            processes => proplists:get_value(processes, Memory),
            ets => proplists:get_value(ets, Memory),
            binary => proplists:get_value(binary, Memory),
            code => proplists:get_value(code, Memory),
            atom => proplists:get_value(atom, Memory),
            system => proplists:get_value(system, Memory)
        },
        uptime_ms => element(1, erlang:statistics(wall_clock)),
        run_queue => erlang:statistics(run_queue),
        applications => [atom_to_binary(App) || {App, _, _} <- application:which_applications()]
    }}.

-spec nodes(cowboy_req:req()) -> {json, map()}.
nodes(_Req) ->
    Connected = [atom_to_binary(N) || N <- nodes()],
    {json, #{
        self => atom_to_binary(node()),
        connected_nodes => Connected,
        node_count => length(Connected) + 1
    }}.
