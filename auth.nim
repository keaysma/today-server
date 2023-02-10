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
        id * : int
        name: string

# put a pw on a newly created user and give them a session
proc register_quick (db: DbConn, username: string, password_hash: string): (bool, string) =
    let raw = db.getAllRows(sql"""
        SELECT id, registered
        FROM users
        WHERE username = ?
        AND password IS NULL;
    """, username)

    if raw.len == 0:
        return (false, "")

    let raw_user_id = raw[0][0]
    let user_id = parseInt(raw_user_id)

    let raw_is_registered = raw[0][1]
    let is_registered = raw_is_registered == "t"

    db.exec(sql"""
        UPDATE users
        SET password = ?
        WHERE username = ?;
    """, password_hash, username)

    if is_registered == false:
        db.exec(sql"""
            INSERT INTO groups (name, created)
            VALUES (?, now());
        """, username)

        let row = db.getRow(sql"""
            SELECT id
            FROM groups
            WHERE name = ?;
        """, username)

        let raw_group_id = parseInt(row[0])

        db.exec(sql"""
            INSERT INTO user_group_assoc (user_id, group_id)
            VALUES (?, ?);
        """, user_id, raw_group_id)

    let token = make_session_token(raw_user_id)
    db.exec(sql"""
        INSERT INTO sessions (token, user_id, expires)
        VALUES (?, ?, now() + '120 hours');
    """, token, raw_user_id)

    return (true, token)

proc create_session * (db: DbConn, username: string, password: string): (bool, string) =
    let password_hash = make_password_hash(password)
    let raw = db.getAllRows(sql"""
        SELECT id
        FROM users
        WHERE username = ?
        AND password = ?;
    """, username, password_hash)

    if raw.len == 0:
        return register_quick(db, username, password_hash)

    let user_id = raw[0][0]
    let token = make_session_token(user_id)
    db.exec(sql"""
        INSERT INTO sessions (token, user_id, expires)
        VALUES (?, ?, now() + '120 hours');
    """, token, user_id)

    return (true, token)

proc get_user_id_from_token * (db: DbConn, auth_header: string): int =
    # clean up other sessions now
    db.exec(sql"""DELETE FROM sessions WHERE expires < now();""")

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

proc get_group_name_by_id * (db: DbConn, group_id: int): string =
    let row = db.getRow(sql"""
        SELECt name
        FROM groups
        WHERE id = ?;
    """, group_id)

    return row[0]

# Read the cookie, get the session token, find the user id
proc get_user_id_from_headers * (db: DbConn, headers: auto): int =
    try:
        let cookie_str = headers["cookie"]
        echo(cookie_str)
        
        let cookies = cookie_str.split(";")
        echo(cookies)
        
        var token = ""
        for cookie in cookies:
            let key_val = cookie.split("=")
            if strip(key_val[0]) == "token":
                token = key_val[1]

        echo(token)

        return get_user_id_from_token(db, token)
    except:
        return -1

# Determine which group a user is working with
# A placeholder function that just returns the users
# first group association
proc get_all_user_groups * (db: DbConn, user_id: int): seq[Group] =
    result = @[]
    try:
        let raw = db.getAllRows(sql"""
            SELECT id, name 
            FROM groups g 
            JOIN user_group_assoc a 
            ON g.id = a.group_id 
            WHERE a.user_id = ?;
        """, user_id)

        for row in raw:
            result.add(
                Group(
                    id: parseInt(row[0]),
                    name: row[1]
                )
            )
    except:
        return @[]

# Determine what level of permission user has for a group
# -1: no permission (not in group)
# 0: read only permission
# 1: write permission
proc get_user_group_permission * (db: DbConn, user_id: int, group_id: int): int =
    # user_group_assoc.permission doesn't exist, and I see no reason to make it exist yet, so everyone can write in every group they're a part of
    return 1