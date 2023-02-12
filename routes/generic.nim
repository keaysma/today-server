import ../router, ../auth
import std/asynchttpserver

r HttpGet, "/api",
    proc (req: Request, ctx: Session): Response =
        return (Http200, "{\"message\": \"hello!!!\"}")