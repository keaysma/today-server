import sugar
import std/strutils
import std/db_postgres

import utils

type
    User * = object
        id: int
        username: string

type
    Group * = object
        id: int
        name: string

proc create_session * (db: DbConn, username: string, password: string): (bool, string) =
    let password_hash = make_password_hash(password)
    let raw = db.getAllRows(sql"""
        SELECT id
        FROM users
        WHERE username = ?
        AND password = ?;
    """, username, password_hash)

    if raw.len == 0:
        return (false, "")

    let user_id = raw[0][0]
    let token = make_session_token(user_id)
    db.exec(sql"""
        INSERT INTO sessions (token, user_id, expires)
        VALUES (?, ?, now() + '24 hours');
    """, token, user_id)

    # clean up other sessions now
    db.exec(sql"""DELETE FROM sessions WHERE expires < now();""")

    return (true, token)

proc make_auth_cookie * (db: DbConn, token: string): string =
    return token

proc get_user_id_from_token * (db: DbConn, auth_header: string): int =
    let token = replace(auth_header, "Bearer ", "")
    let row = db.getRow(sql"""
        SELECT user_id
        FROM sessions
        WHERE token = ?;
    """, token)

    # if no user_id was found, this raises a ValueError
    return parseInt(row[0])
    
proc get_group_id_from_user_id * (db: DbConn, user_id: int): seq[int] =
    let raw = db.getAllRows(sql"""
        SELECT group_id
        FROM user_group_assoc
        WHERE user_id = ?;
    """, user_id)
    
    let ids = collect(newSeq):
        for row in raw: parseInt(row[0])

    # if no user_id was found, this raises a ValueError
    return ids

# Read the cookie, get the session token, find the user id
proc get_user_id_from_headers * (db: DbConn, headers: auto): int =
    try:
        let cookie_str = headers["cookie"]
        echo(cookie_str)
        let cookies = cookie_str.split(";")
        
        var token = ""
        for cookie in cookies:
            let key_val = cookie.split("=")
            if key_val[0] == "token":
                token = key_val[1]

        echo(token)

        return get_user_id_from_token(db, token)
    except:
        return -1

# Determine which group a user is working with
# A placeholder function that just returns the users
# first group association
proc get_user_current_group_id * (db: DbConn, user_id: int): int =
    let row = db.getRow(sql"""
        SELECT group_id
        FROM user_group_assoc
        WHERE user_id = ?
        LIMIT 1;
    """, user_id)

    return parseInt(row[0])

# Determine what level of permission user has for a group
# -1: no permission (not in group)
# 0: read only permission
# 1: write permission
proc get_user_group_permission * (db: DbConn, user_id: int, group_id: int): int =
    # user_group_assoc.permission doesn't exist, and I see no reason to make it exist yet, so everyone can write in every group they're a part of
    return 1