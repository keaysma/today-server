import ../router, ../auth, ../utils, ../database
import json, std/[asynchttpserver, strutils]

a HttpGet, "/api/items",
    proc (req: Request, ctx: Session): Response =
        let tags = parse_from_query(req.url.query, "tags", "").split(",")
        let items = get_items_by_tags(tags, ctx.group_ids)

        return(
            Http200,
            $ %* {
                "items": items
                }
        )

a HttpPost, "/api/items",
    proc (req: Request, ctx: Session): Response =
        let data = parseJson(req.body)
        let tags_raw = parse_json_array(data["tags"])
        let group = get_valid_group(data["group"].getInt, ctx.group_ids)
        insert_item(data["key"].str, data["itype"].str, $data["config"], group, tags_raw)
        return (
            Http201,
            $data
        )

a HttpPatch, "/api/items",
    proc (req: Request, ctx: Session): Response =
        let data = parseJson(req.body)

        var updates: seq[tuple[select: Item, update: Item]] = @[]
        for raw_update in data["updates"].getElems:
                let item_data = raw_update["item"]
                let select_item = Item(
                    key: item_data["key"].getStr,
                    itype: item_data["itype"].getStr,
                    config: item_data["config"],
                    tags: parse_json_array(item_data["tags"]),
                    group: get_valid_group(
                        item_data["group"].getInt,
                        ctx.group_ids
                        ),
                )

                let update_data = raw_update["changes"]
                let update_item = Item(
                    key: update_data{"key"}.getStr(select_item.key),
                    itype: update_data{"itype"}.getStr(select_item.itype),
                    config: (
                        if update_data{"config"} != nil: update_data{"config"}
                        else: select_item.config
                ),
                    tags: (
                        if update_data{"tags"} != nil: parse_json_array(
                                        update_data["tags"])
                        else: select_item.tags
                ),
                    group: get_valid_group(
                        update_data{"group"}.getInt(select_item.group),
                        ctx.group_ids
                        )
                )

                updates.add((
                        select: select_item,
                        update: update_item,
                ))

        var res: seq[Item] = @[]
        for update in updates:
                let success = update_item(update[0], update[1])
                if success:
                    res.add(update[1])
                # else:
                #     res.add(update[0])

        return (
            Http200,
            $ %* {
                "items": res
                }
        )

a HttpDelete, "/api/items",
    proc (req: Request, ctx: Session): Response =
        let data = parseJson(req.body)
        let group = get_valid_group(data["group"].getInt, ctx.group_ids)
        delete_item_by_key(data["key"].str, group)
        return (
            Http204,
            $ %* {}
        )
