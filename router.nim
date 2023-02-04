import json
import std/asynchttpserver
import std/asyncdispatch
import std/strformat
import std/strutils
import std/times
import std/os

import auth, database, utils

const allowed_headers = "Content-Type"

proc bare_route * (req: Request) {.async.} =
    let allowed_origin = getEnv("origin")
    let cookie_domain = getEnv("domain")
    let extra_cookie = getEnv("extra_cookie")
    echo("[" & $req.reqMethod & "] " & $req.url.path)
    
    #if req.reqMethod == HttpPost:
    #    echo(parseJson(req.body))
    
    let headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": fmt"{allowed_origin}",
        "Access-Control-Allow-Headers": fmt"{allowed_headers}",
        "Access-Control-Allow-Credentials": "true",
        "Access-Control-Allow-Methods": "OPTIONS, GET, POST, DELETE",
    }

    #TODO: Options per endpoint, disabled for now because auth messes up options requests
    if req.reqMethod == HttpOptions:
        let optionsHeaders = {
            "Access-Control-Allow-Origin": fmt"{allowed_origin}",
            "Access-Control-Allow-Headers": fmt"{allowed_headers}",
            "Access-Control-Allow-Credentials": "true",
            "Access-Control-Allow-Methods": "OPTIONS, GET, POST, DELETE",
            "Allow": "OPTIONS, GET, POST, DELETE"
        }
        await req.respond(
            Http204,
            "",
            optionsHeaders.newHttpHeaders()
        )
        return 
    
    case req.url.path:
        of "/":
            await req.respond(Http200, "{\"message\": \"hello\"}", headers.newHttpHeaders())
        of "/api/me":
            case req.reqMethod:
                of HttpGet:
                    let user_id = get_user_id_from_headers(db(), req.headers)
                    echo("user_id is " & $user_id)
                    if user_id < 0:
                        await req.respond(Http401, "{\"message\": \"unauthorized\"}", headers.newHttpHeaders())
                        return
                    
                    let selected_group = get_user_current_group_id(db(), user_id)
                    if selected_group < 0:
                        await req.respond(Http401, "{\"message\": \"unauthorized\"}", headers.newHttpHeaders())
                        return

                    let all_item_tags = get_all_tags_from_items(selected_group)
                    let all_entry_tags = get_all_tags_from_entries(selected_group)
                    let data = %* {
                        "items": all_item_tags,
                        "entries": all_entry_tags
                    }
                    await req.respond(Http200, $data, headers.newHttpHeaders())
                else:
                    let err = %* { "error": "bad method" }
                    await req.respond(Http405, $err, headers.newHttpHeaders())
        of "/api/auth":
            case req.reqMethod:
                of HttpPost:
                    try:
                        #echo(req.body)
                        let data = parseJson(req.body)

                        echo("make session")
                        let session_data = create_session(db(), data["username"].str, data["password"].str)
                        if session_data[0] == true:
                            echo("make session success")
                            let expire = now().utc + initDuration(hours = 72)
                            let expires = format(expire, "ddd, dd MMM yyyy H:mm:ss") & " UTC"
                            let customHeaders = {
                                "Content-Type": "application/json",
                                "Access-Control-Allow-Origin": fmt"{allowed_origin}",
                                "Access-Control-Allow-Headers": fmt"{allowed_headers}",
                                "Access-Control-Allow-Credentials": "true",
                                "Set-Cookie": fmt"token={session_data[1]}; Expires={expires}; Path=/; Domain={cookie_domain}; HttpOnly{extra_cookie}"
                            }
                            await req.respond(Http204, "", customHeaders.newHttpHeaders())
                        else:
                            await req.respond(Http403, "{\"error\": \"bad creds\"}", headers.newHttpHeaders())
                    except:
                        echo getCurrentExceptionMsg()
                        let err = %* { "error": "bad payload" }
                        await req.respond(Http400, $err, headers.newHttpHeaders())
                    return
                else:
                    let err = %* { "error": "bad method" }
                    await req.respond(Http405, $err, headers.newHttpHeaders())
                    return
        of "/api/public/entries":
            case req.reqMethod:
                of HttpGet:
                    let tags = parse_from_query(req.url.query, "tags", "").split(",")

                    let items = get_items_by_tags_public(tags)
                    let entries = get_entries_by_tag_public(tags)

                    var data = %* {
                        "items": items,
                        "entries": entries
                    }
                    await req.respond(
                        Http200,
                        $data,
                        headers.newHttpHeaders()
                    )
                    return
                else:
                    let err = %* { "error": "bad method" }
                    await req.respond(Http405, $err, headers.newHttpHeaders())
                    return

    let user_id = get_user_id_from_headers(db(), req.headers)
    echo("user_id is " & $user_id)
    if user_id < 0:
        await req.respond(Http401, "{\"message\": \"unauthorized\"}", headers.newHttpHeaders())
        return
    
    let selected_group = get_user_current_group_id(db(), user_id)
    echo("group_id is " & $selected_group)
    if selected_group < 0:
        await req.respond(Http401, "{\"message\": \"unauthorized\"}", headers.newHttpHeaders())
        return


    case req.url.path:
        of "/api/items":
            case req.reqMethod:
                of HttpGet:
                    let tags = parse_from_query(req.url.query, "tags", "").split(",")
                    echo(tags)

                    let items = get_items_by_tags(tags, selected_group)

                    var data = %* {
                        "items": items
                    }
                    await req.respond(Http200, $data, headers.newHttpHeaders())
                of HttpPost:
                    try:
                        let data = parseJson(req.body)
                        let tags_raw = parse_json_array(data["tags"])
                        insert_item(data["key"].str, data["itype"].str, tags_raw, selected_group)
                        await req.respond(Http201, $data, headers.newHttpHeaders())
                    except:
                        echo getCurrentExceptionMsg()
                        let err = %* { "error": "bad payload" }
                        await req.respond(Http400, $err, headers.newHttpHeaders())
                    return
                of HttpDelete:
                    let data = parseJson(req.body)
                    delete_item_by_key(data["key"].str, selected_group)
                    await req.respond(Http204, "{}", headers.newHttpHeaders())
                else:
                    let err = %* { "error": "bad method" }
                    await req.respond(Http405, $err, headers.newHttpHeaders())
        of "/api/entries":
            case req.reqMethod:
                of HttpGet:
                    let tags = parse_from_query(req.url.query, "tags", "").split(",")

                    let items = get_items_by_tags(tags, selected_group)
                    let entries = get_entries_by_tag(tags, selected_group)

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
                        upsert_entry(data["key"].str, data["value"].str, tags_raw, selected_group)
                        await req.respond(Http201, $data, headers.newHttpHeaders())
                    except:
                        echo getCurrentExceptionMsg()
                        let err = %* { "error": "bad payload" }
                        await req.respond(Http400, $err, headers.newHttpHeaders())
                    return # this appears to be needed cause we have a try catch???
                of HttpDelete:
                    let data = parseJson(req.body)
                    let tags_raw = parse_json_array(data["tags"])
                    delete_entry_by_key_tags(data["key"].str, tags_raw, selected_group)
                    await req.respond(Http204, "{}", headers.newHttpHeaders())
                else:
                    let err = %* { "error": "bad method" }
                    await req.respond(Http405, $err, headers.newHttpHeaders())
        of "/api/users":
            case req.reqMethod:
                of HttpPost:
                    try:
                        let data = parseJson(req.body)
                        create_user(data["username"].str, data["password"].str)
                        await req.respond(Http201, $data, headers.newHttpHeaders())
                    except:
                        echo getCurrentExceptionMsg()
                        let err = %* { "error": "bad payload" }
                        await req.respond(Http400, $err, headers.newHttpHeaders())
                    return
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