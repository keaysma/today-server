import json, sugar
import std/asynchttpserver
import std/asyncdispatch
import std/db_postgres
import std/strutils

import database, utils

proc bare_route * (req: Request) {.async.} =
    echo("[" & $req.reqMethod & "] " & $req.url.path)
    if req.reqMethod == HttpPost:
        echo(parseJson(req.body))
    let headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "*",
        "Access-Control-Allow-Methods": "*",
    }

    case req.url.path:
        of "/":
            await req.respond(Http200, "{\"message\": \"hello\"}", headers.newHttpHeaders())
        of "/api/all-tags":
            case req.reqMethod:
                of HttpGet:
                    let all_tags = get_all_tags_from_items()
                    let data = %* {
                        "tags": all_tags
                    }
                    await req.respond(Http200, $data, headers.newHttpHeaders())
                else:
                    let err = %* { "error": "bad method" }
                    await req.respond(Http405, $err, headers.newHttpHeaders())
        of "/api/items":
            case req.reqMethod:
                of HttpOptions:
                    let optionsHeaders = {
                        "Access-Control-Allow-Origin": "*",
                        "Access-Control-Allow-Headers": "*",
                        "Access-Control-Allow-Methods": "*",
                        "Allow": "OPTIONS, GET, POST, DELETE"
                    }
                    await req.respond(
                        Http204,
                        "",
                        optionsHeaders.newHttpHeaders()
                    )
                of HttpGet:
                    let tags = parse_from_query(req.url.query, "tags", "").split(",")

                    let items = get_items_by_tags(tags)

                    var data = %* {
                        "items": items
                    }
                    await req.respond(Http200, $data, headers.newHttpHeaders())
                of HttpPost:
                    try:
                        let data = parseJson(req.body)
                        let tags_raw = parse_json_array(data["tags"])
                        insert_item(data["key"].str, data["itype"].str, tags_raw)
                        await req.respond(Http201, $data, headers.newHttpHeaders())
                    except:
                        echo getCurrentExceptionMsg()
                        let err = %* { "error": "bad payload" }
                        await req.respond(Http400, $err, headers.newHttpHeaders())
                of HttpDelete:
                    let data = parseJson(req.body)
                    delete_item_by_key(data["key"].str)
                    await req.respond(Http204, "{}", headers.newHttpHeaders())
                else:
                    let err = %* { "error": "bad method" }
                    await req.respond(Http405, $err, headers.newHttpHeaders())
        of "/api/entries":
            case req.reqMethod:
                of HttpOptions:
                    let optionsHeaders = {
                        "Access-Control-Allow-Origin": "*",
                        "Access-Control-Allow-Headers": "*",
                        "Access-Control-Allow-Methods": "*",
                        "Allow": "OPTIONS, GET, POST"
                    }
                    await req.respond(
                        Http204,
                        "",
                        optionsHeaders.newHttpHeaders()
                    )
                of HttpGet:
                    let tags = parse_from_query(req.url.query, "tags", "").split(",")

                    let items = get_items_by_tags(tags)
                    let entries = get_entries_by_tag(tags)

                    var data = %* {
                        "items": items,
                        "entries": entries
                    }
                    await req.respond(
                        Http200,
                        $data,
                        headers.newHttpHeaders()
                    )
                of HttpPost:
                    try:
                        let data = parseJson(req.body)
                        let tags_raw = parse_json_array(data["tags"])
                        upsert_entry(data["key"].str, data["value"].str, tags_raw)
                        await req.respond(Http201, $data, headers.newHttpHeaders())
                    except:
                        echo getCurrentExceptionMsg()
                        let err = %* { "error": "bad payload" }
                        await req.respond(Http400, $err, headers.newHttpHeaders())
                else:
                    let err = %* { "error": "bad method" }
                    await req.respond(Http405, $err, headers.newHttpHeaders())
        else:
            await req.respond(Http404, "{\"error\": \"not found\"}", headers.newHttpHeaders())

    await req.respond(Http500, "{\"error\": \"dropout\"}", headers.newHttpHeaders())

proc safe_route * (req: Request) {.async.} =
    try:
        await bare_route(req)
    except:
        echo getCurrentExceptionMsg()
        let headers = {
            "Content-Type": "application/json",
        }
        await req.respond(Http500, "", headers.newHttpHeaders())