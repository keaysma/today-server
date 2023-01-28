import times, strutils

type EKeyboardInterrupt = object of CatchableError

import std/asynchttpserver
import std/asyncdispatch
import std/db_postgres

import router, database

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

try:
    waitFor main()
except:
    echo getCurrentExceptionMsg()
    db.close()
    echo "Goodbye"