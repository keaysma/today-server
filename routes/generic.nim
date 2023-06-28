import ../router, ../auth
import json, std/asynchttpserver

r HttpGet, "/api",
    proc (req: Request, ctx: Session): Response =
        return (Http200, $ %* { "message": "hello!!!" })