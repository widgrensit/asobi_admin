-module(asobi_admin_economy_controller).
-moduledoc "Console UI: item definitions and store listings.".

-export([index/1, create_item/1, create_listing/1]).

-spec index(cowboy_req:req()) -> {ok, map()} | {redirect, binary()}.
index(Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        {ok, Items} = asobi_repo:all(
            kura_query:limit(kura_query:from(asobi_item_def), 50)
        ),
        {ok, Listings} = asobi_repo:all(
            kura_query:limit(kura_query:from(asobi_store_listing), 50)
        ),
        {ok, #{
            active_page => ~"economy",
            csrf_token => maps:get(csrf_token, Req, ~""),
            items => Items,
            listings => Listings
        }}
    end).

-spec create_item(cowboy_req:req()) ->
    {status, integer(), map(), binary(), cowboy_req:req()} | {redirect, binary()}.
create_item(Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        Params = maps:get(params, Req, #{}),
        Slug = maps:get(~"slug", Params, ~""),
        Result = asobi_admin_economy:do_create_item(#{
            ~"slug" => Slug,
            ~"name" => maps:get(~"name", Params, ~""),
            ~"category" => maps:get(~"category", Params, ~""),
            ~"rarity" => maps:get(~"rarity", Params, ~"common")
        }),
        asobi_admin_ui_audit:log_action(~"create_item", #{slug => Slug}, Result),
        {status, 302, #{~"location" => ~"/admin/ui/economy"}, <<>>, Req}
    end).

-spec create_listing(cowboy_req:req()) ->
    {status, integer(), map(), binary(), cowboy_req:req()} | {redirect, binary()}.
create_listing(Req) ->
    asobi_admin_ui_auth:guarded(Req, fun() ->
        Params = maps:get(params, Req, #{}),
        ItemDefId = maps:get(~"item_def_id", Params, ~""),
        Fields = #{item_def_id => ItemDefId},
        case asobi_admin_ui_params:int(maps:get(~"price", Params, ~"")) of
            {ok, Price} ->
                Result = asobi_admin_economy:do_create_listing(#{
                    ~"item_def_id" => ItemDefId,
                    ~"currency" => maps:get(~"currency", Params, ~""),
                    ~"price" => Price
                }),
                asobi_admin_ui_audit:log_action(~"create_listing", Fields#{price => Price}, Result);
            error ->
                asobi_admin_ui_audit:log_action(~"create_listing", Fields, {error, invalid_price})
        end,
        {status, 302, #{~"location" => ~"/admin/ui/economy"}, <<>>, Req}
    end).
