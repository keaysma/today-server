import times, strutils, dotenv, std/[os, asyncdispatch, asynchttpserver, db_postgres]
import router, database, routes/[generic, items, entries, session, users, publications]

type EKeyboardInterrupt = object of CatchableError


proc handler() {.noconv.} =
  raise newException(EKeyboardInterrupt, "Keyboard Interrupt")
setControlCHook(handler)

proc main () {.async.} =
  database.bootstrap()
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
