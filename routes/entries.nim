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

a HttpPatch, "/api/entries",
    proc (req: Request, ctx: Session): Response =
        let data = parseJson(req.body)

        var updates: seq[tuple[select: Entry, update: Entry]] = @[]
        var deletes: seq[Entry] = @[]
        for raw_update in data["updates"].getElems:
                let entry_data = raw_update["entry"]
                let entry = Entry(
                    key: entry_data["key"].getStr,
                    value: entry_data["value"].getStr,
                    group: get_valid_group(entry_data["group"].getInt,
                                    ctx.group_ids),
                    tags: parse_json_array(entry_data["tags"]),
                )

                let operation = raw_update["operation"].getStr
                if operation == "delete":
                    deletes.add(entry)
                elif operation == "change":
                    let changes_data = raw_update["changes"]
                    let update = Entry(
                        key: changes_data{"key"}.getStr(entry.key),
                        value: changes_data{"value"}.getStr(entry.value),
                        group: get_valid_group(
                            changes_data{"group"}.getInt(entry.group),
                            ctx.group_ids
                            ),
                        tags: (
                            if changes_data{"tags"} != nil:
                                parse_json_array(changes_data["tags"])
                            else: entry.tags
                        ),
                    )
                    updates.add((
                        select: entry,
                        update: update,
                    ))

        var deleted: seq[Entry] = @[]
        for delete in deletes:
            try:
                delete_entry_by_key_tags(delete.key, delete.tags, delete.group)
                deleted.add(delete)
            except Exception as e:
                echo e.msg

        var updated: seq[Entry] = @[]
        for update in updates:
            try:
                let success = update_entry(update.select, update.update)
                if success:
                    updated.add(update.update)
            except Exception as e:
                echo e.msg

        return (
            Http200,
            $ %* {
                "updated": updated,
                "deleted": deleted,
            }
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
