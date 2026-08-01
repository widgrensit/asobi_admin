-module(asobi_admin_economy).

-include_lib("kura/include/kura.hrl").

-export([index/1, items/1, create_item/1, listings/1, create_listing/1]).
-export([do_create_item/1, do_create_listing/1]).

-spec index(cowboy_req:req()) -> {json, map()}.
index(_Req) ->
    {ok, ItemDefs} = asobi_repo:all(kura_query:from(asobi_item_def)),
    {ok, Listings} = asobi_repo:all(
        kura_query:where(kura_query:from(asobi_store_listing), {active, true})
    ),
    {json, #{
        item_count => length(ItemDefs),
        active_listings => length(Listings)
    }}.

-spec items(cowboy_req:req()) -> {json, map()}.
items(#{qs := Qs} = _Req) ->
    Params = cow_qs:parse_qs(Qs),
    Limit = binary_to_integer(proplists:get_value(~"limit", Params, ~"50")),
    Q = kura_query:limit(
        kura_query:order_by(kura_query:from(asobi_item_def), [{inserted_at, desc}]),
        Limit
    ),
    {ok, Items} = asobi_repo:all(Q),
    {json, #{items => Items}}.

-spec create_item(cowboy_req:req()) -> {json, map()} | {json, integer(), map(), map()}.
create_item(#{json := Params} = _Req) ->
    case do_create_item(Params) of
        {ok, Item} ->
            {json, Item};
        {error, CS1} ->
            {json, 422, #{}, #{errors => kura_changeset:traverse_errors(CS1, fun(_F, M) -> M end)}}
    end.

-spec do_create_item(map()) -> {ok, map()} | {error, #kura_changeset{}}.
do_create_item(Params) ->
    CS = asobi_item_def:changeset(#{}, #{
        slug => maps:get(~"slug", Params),
        name => maps:get(~"name", Params),
        category => maps:get(~"category", Params),
        rarity => maps:get(~"rarity", Params, ~"common"),
        stackable => maps:get(~"stackable", Params, true),
        metadata => maps:get(~"metadata", Params, #{})
    }),
    asobi_repo:insert(CS).

-spec listings(cowboy_req:req()) -> {json, map()}.
listings(#{qs := Qs} = _Req) ->
    Params = cow_qs:parse_qs(Qs),
    Limit = binary_to_integer(proplists:get_value(~"limit", Params, ~"50")),
    Q = kura_query:limit(kura_query:from(asobi_store_listing), Limit),
    {ok, Listings} = asobi_repo:all(Q),
    {json, #{listings => Listings}}.

-spec create_listing(cowboy_req:req()) -> {json, map()} | {json, integer(), map(), map()}.
create_listing(#{json := Params} = _Req) ->
    case do_create_listing(Params) of
        {ok, Listing} ->
            {json, Listing};
        {error, CS1} ->
            {json, 422, #{}, #{errors => kura_changeset:traverse_errors(CS1, fun(_F, M) -> M end)}}
    end.

-spec do_create_listing(map()) -> {ok, map()} | {error, #kura_changeset{}}.
do_create_listing(Params) ->
    CS = asobi_store_listing:changeset(#{}, #{
        item_def_id => maps:get(~"item_def_id", Params),
        currency => maps:get(~"currency", Params),
        price => maps:get(~"price", Params),
        active => maps:get(~"active", Params, true),
        valid_from => maps:get(~"valid_from", Params, undefined),
        valid_until => maps:get(~"valid_until", Params, undefined)
    }),
    asobi_repo:insert(CS).
