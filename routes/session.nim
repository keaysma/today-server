import ../router, ../auth, ../database
import std/[asynchttpserver, strformat, times]
import sugar, json

a HttpGet, "/api/me",
    proc (req: Request, ctx: Session): Response =
        let all_tag_sets = get_all_tag_sets_from_items(ctx.group_ids)
        let all_item_tags = get_all_tags_from_items(ctx.group_ids)
        let all_entry_tags = get_all_tags_from_entries(ctx.group_ids)
        let data = %* {
            "tagSets": all_tag_sets,
            "items": all_item_tags,
            "entries": all_entry_tags,
            "groups": ctx.groups
        }
        return (Http200, $data)

