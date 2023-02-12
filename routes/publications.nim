import ../router, ../auth, ../utils, ../database
import std/asynchttpserver
import json

r HttpGet, "/api/publications",
    proc (req: Request, ctx: Session): Response =
        let publication_id = parse_from_query(req.url.query, "id", "")

        if publication_id == "":
            return(
                Http400,
                $ %* {"error":"bad request"},
            )
        try:
            let (tags, group_id, title) = get_publication_by_id(publication_id)
            let group_name = get_group_name_by_id(db(), group_id)

            let items = get_items_by_tags_public(tags, group_id)
            let entries = get_entries_by_tag_public(tags, group_id)

            return(
                Http200,
                $ %* {
                    "items": items,
                    "entries": entries,
                    "tags": tags,
                    "group": group_name,
                    "title": title
                }
            )
        except:
            return(
                Http404,
                $ %* {"error":"not found"}
            )
