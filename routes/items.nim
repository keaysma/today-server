import ../router, ../auth, ../utils, ../database
import std/[asynchttpserver, strutils]
import json

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

a HttpDelete, "/api/items",
    proc (req: Request, ctx: Session): Response =
        let data = parseJson(req.body)
        let group = get_valid_group(data["group"].getInt, ctx.group_ids)
        delete_item_by_key(data["key"].str, group)
        return (
            Http204, 
            $ %* {}
        )