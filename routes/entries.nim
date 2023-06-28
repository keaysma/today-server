import ../router, ../auth, ../utils, ../database
import json, std/[asynchttpserver, strutils]

a HttpGet, "/api/entries",
    proc (req: Request, ctx: Session): Response =
        let tags = parse_from_query(req.url.query, "tags", "").split(",")

        let items = get_items_by_tags(tags, ctx.group_ids)
        let entries = get_entries_by_tag(tags, ctx.group_ids)

        return(
            Http200,
            $ %* {
                "items": items,
                "entries": entries
            }
        )

a HttpPost, "/api/entries",
    proc (req: Request, ctx: Session): Response =
        let data = parseJson(req.body)
        let tags_raw = parse_json_array(data["tags"])
        let group = get_valid_group(data["group"].getInt, ctx.group_ids)
        upsert_entry(data["key"].str, data["value"].str, tags_raw, group)
        return (
            Http201, 
            $data
        )

a HttpDelete, "/api/entries",
    proc (req: Request, ctx: Session): Response =
        let data = parseJson(req.body)
        let tags_raw = parse_json_array(data["tags"])
        let group = get_valid_group(data["group"].getInt, ctx.group_ids)
        delete_entry_by_key_tags(data["key"].str, tags_raw, group)
        return (
            Http204,
            $ %* {}
        )