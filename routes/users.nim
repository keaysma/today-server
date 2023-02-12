import ../router, ../auth, ../utils, ../database
import std/[asynchttpserver, strutils]
import json

r HttpPost, "/api/users",
    proc (req: Request, ctx: Session): Response =
        let data = parseJson(req.body)
        # create_user(data["username"].str, data["password"].str)
        return (
            Http201, 
            $data
        )