import ../router, ../auth, ../database
import json, std/asynchttpserver

r HttpPost, "/api/users",
    proc (req: Request, ctx: Session): Response =
        let data = parseJson(req.body)
        if false:
            create_user(data["username"].str, data["password"].str)
        return (
            Http201, 
            $data
        )