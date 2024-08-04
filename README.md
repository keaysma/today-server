# toodo-server

## Build & RUnning
Use `nim` to build

TLDR: `nim c -r main.nim`

```bash
nim c main.nim
```

Then you can run the `main` executable
```bash
./main
```

You can tell nim to run immediately on a successful build too
```bash
nim c -r main.nim
```

## Setup
1. Run postgres - locally, or otherwise, doesn't matter, you just need access
2. Create a database in postgres, `toodo` in this example
3. Setup you `.env`
```
origin=http://today.keays.test
domain=.keays.test
extra_cookie=
salt=salt
db_host=localhost
db_user=admin
db_password=admin
db=toodo
```
4. Run the application to setup all tables
5. Add a new user, password of NIL is intentional and allows you to set a password on login
```sql
INSERT INTO users (username, password, created) VALUES ('testuser', null, now());
```

## Local testing
Assuming user `testuser` with no password is present, this will register the user, otherwise login behaves as normal.

```bash
# Login
curl -c .cookie today-api.keays.test/api/auth -X POST -H "Content-Type: application-json" -d \
    '{ "username": "testuser", "password": "testpass" }'

# Request
curl -b .cookie today-api.keays.test/api/me
```
