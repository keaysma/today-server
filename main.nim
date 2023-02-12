import times, strutils, dotenv

type EKeyboardInterrupt = object of CatchableError

import std/asynchttpserver
import std/asyncdispatch
import std/db_postgres
import std/os

import router, database
import 
    routes/generic, 
    routes/items, 
    routes/entries, 
    routes/session,
    routes/users,
    routes/publications


proc handler() {.noconv.} =
  raise newException(EKeyboardInterrupt, "Keyboard Interrupt")

setControlCHook(handler)    

proc main () {.async.} =
    bootstrap()
    echo "Bootstrapped database"
    
    var server = newAsyncHttpServer()
    server.listen(Port(8080))
    let port = server.getPort()
    echo "Server is listening on port " & $port.uint16

    while true:
        if server.shouldAcceptRequest():
            await server.acceptRequest(safe_route)
        else:
            await sleepAsync(500)

load()
echo(getEnv("origin"))
try:
    waitFor main()
except:
    echo getCurrentExceptionMsg()
    db_conn.close()
    echo "Goodbye"