import json, sugar
import std/asynchttpserver
import std/asyncdispatch
import std/strformat
import std/strutils
import std/tables
import std/times
import std/os

import auth, database, utils

const allowed_headers = "Content-Type"

type Response * = tuple[code: HttpCode, content: string]
type Responder = proc (req: Request, ctx: Session): Response

var route_table = initTable[string, Table[HttpMethod, tuple[cb: Responder, auth: bool]]]()

proc register_route * (http_method: HttpMethod, route: string, callback: Responder, auth: bool) =
    if not route_table.hasKey(route):
        route_table[route] = initTable[HttpMethod, tuple[cb: Responder, auth: bool]]()
    route_table[route][http_method] = (callback, auth)
    echo(fmt"REGISTERED [{http_method}] {route} (athentication: {auth})")

proc r * (http_method: HttpMethod, route: string, callback: Responder) =
    register_route(http_method, route, callback, false)

proc a * (http_method: HttpMethod, route: string, callback: Responder) =
    register_route(http_method, route, callback, true)
    
proc handle_route_table (req: Request) {.async gcsafe.} =
    let allowed_origin = getEnv("origin")
    let cookie_domain = getEnv("domain")
    let extra_cookie = getEnv("extra_cookie")

    let baseHeaders = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": fmt"{allowed_origin}",
        "Access-Control-Allow-Headers": fmt"{allowed_headers}",
        "Access-Control-Allow-Credentials": "true",
        "Access-Control-Allow-Methods": "OPTIONS, GET, POST, DELETE",
    }

    let rmethod = req.reqMethod
    let rpath = $req.url.path

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

    # undecided on how I want to handle custom headers, so this is going to stay here
    if rpath == "/api/auth" and rmethod == HttpPost:
        try:
            #echo(req.body)
            let data = parseJson(req.body)

            echo("make session")
            let session_data = create_session(db(), data["username"].str, data["password"].str)
            if session_data[0] == true:
                echo("make session success")
                let expire = now().utc + initDuration(hours = 120)
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
                await req.respond(Http403, "{\"error\": \"bad creds\"}", newHttpHeaders(baseHeaders))
        except:
            echo getCurrentExceptionMsg()
            let err = %* { "error": "bad payload" }
            await req.respond(Http400, $err, newHttpHeaders(baseHeaders))
        return

    if route_table.hasKey(rpath):
        if route_table[rpath].hasKey(rmethod):
            try:
                let (cb, auth) = route_table[rpath][rmethod]
                if auth:
                    let ctx = get_session_from_headers(db(), req.headers)
                    if ctx.user_id >= 0:
                        let (acode, ares) = cb(req, ctx)
                        echo(fmt"[{rmethod}] {rpath} - {acode}")
                        await req.respond(acode, ares, newHttpHeaders(baseHeaders))
                    else:
                        echo(fmt"[{rmethod}] {rpath} - 401")
                        await req.respond(Http401, "{\"message\": \"unauthorized\"}", newHttpHeaders(baseHeaders))
                else:
                    let (code, res) = cb(req, Session(user_id: -1, group_ids: @[]))
                    echo(fmt"[{rmethod}] {rpath} - {code}")
                    await req.respond(code, res, newHttpHeaders(baseHeaders))
            except:
                echo(fmt"[{rmethod}] {rpath} - 500")
                echo getCurrentExceptionMsg()
                await req.respond(Http500, $ %* {"message": "internal server error"}, newHttpHeaders(baseHeaders))
        else:
            echo(fmt"[{rmethod}] {rpath} - 405")
            await req.respond(Http405, $ %* {"message": "method not allowed"}, newHttpHeaders(baseHeaders))
    else:
        echo(fmt"[{rmethod}] {rpath} - 404")
        await req.respond(Http404, $ %* {"message": "not found"}, newHttpHeaders(baseHeaders))

proc safe_route * (req: Request) {.async.} =
    try:
        #await bare_route(req)
        await handle_route_table(req)
    except:
        echo "FAILURE"
        echo getCurrentExceptionMsg()
        let headers = {
            "Content-Type": "application/json",
        }
        await req.respond(Http500, "", headers.newHttpHeaders())