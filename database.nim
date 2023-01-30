import sugar
import std/strutils
import std/strformat
import std/parseutils
import std/db_postgres

import utils, migrations

let db * = open("localhost", "mkeays", "", "toodo")

type Tags = seq[string]

type
    Entry * = object
        key, value: string
        tags: seq[string]
type
    Item * = object
        key: string
        itype: string
        tags: seq[string]
        # config:

proc bootstrap * () =
    db.exec(sql("""
        CREATE TABLE IF NOT EXISTS migrations (
            id INT PRIMARY KEY,
            datetime TIMESTAMP NOT NULL
        );
    """));
    for idx, mig in migration_path:
        let raw = db.getAllRows(sql"""
            SELECT id
            FROM migrations
            WHERE id = ?;
        """, idx)

        if raw.len > 0:
            echo(fmt"skipping migration #{idx}")
        else:
            echo(fmt"running migration #{idx}")
            mig(db)
            db.exec(sql"""
                INSERT INTO migrations (id, datetime)
                VALUES (?, now());
            """, idx)

proc get_items_by_tags * (tags: Tags, group: int): seq[Item] =
    let vals = collect(newSeq):
        for tag in tags: "\"" & tag & "\""
    let inp = make_database_tags(vals)
    let raw = db.getAllRows(sql"""
        SELECT key, itype, tags
        FROM items
        WHERE tags <@ ?;
    """, inp)
    for r in raw:
        result.add(Item(key: r[0], itype: r[1], tags: parse_pg_array(r[2])))

proc get_all_tags_from_items * (groups_filter: string): seq[string] =
    let raw = db.getAllRows(sql(fmt"""
        SELECT DISTINCT ON (tag) unnest(tags) AS tag 
        FROM items
        WHERE group_id IN {groups_filter};
    """))
    for tag in raw:
        result.add(tag)

proc get_all_tags_from_entries * (groups_filter: string): seq[string] =
    let raw = db.getAllRows(sql(fmt"""
        SELECT DISTINCT ON (tag) unnest(tags) AS tag
        FROM entries
        WHERE group_id IN {groups_filter};
    """))
    for tag in raw:
        result.add(tag)

proc get_entries_by_tag * (tags: Tags, group: int): seq[Entry] =
    let vals = collect(newSeq):
        for tag in tags: "\"" & tag & "\""
    let inp = make_database_tags(vals)
    let raw = db.getAllRows(sql(fmt"""
        SELECT key, value, tags
        FROM entries
        WHERE tags <@ ?
        AND group_id = ?;
    """), inp, group)
    for r in raw:
        result.add(Entry(
            key: r[0],
            value: r[1],
            tags: parse_pg_array(r[2])
        ))

proc insert_item * (key: string, itype: string, tags: seq[string], group: int): void =
    let tags_str: string = make_database_tags(tags)
    db.exec(sql"""
        INSERT INTO items (key, itype, tags, group_id)
        VALUES (?, ?, ?, ?);
    """, key, itype, tags_str, group)

proc upsert_entry * (key: string, value: string, tags: seq[string], group: int): void =
    let tags_str: string = make_database_tags(tags)

    let res = db.getRow(sql"""
        SELECT COUNT(*)
        FROM entries
        WHERE key = ?
        AND tags = ?
        AND group_id = ?;
    """, key, tags_str, group)

    if parseInt(res[0]) > 0:
        db.exec(sql"""
            UPDATE entries
            SET value = ?
            WHERE key = ?
            AND tags = ?
            AND group_id = ?;
        """, value, key, tags_str, group)
    else:
        db.exec(sql"""
            INSERT INTO entries (key, value, tags, group_id)
            VALUES (?, ?, ?, ?);
        """, key, value, tags_str, group)

proc delete_item_by_key * (key: string, group: int): void =
    db.exec(sql"""
        DELETE FROM items
        WHERE key = ?
        AND group_id = ?;
    """, key, group)

proc delete_entry_by_key_tags * (key: string, tags: seq[string], group: int): void =
    let tags_str: string = make_database_tags(tags)
    echo(tags_str)
    db.exec(sql"""
        DELETE FROM entries
        WHERE key = ?
        AND tags = ?
        AND group_id = ?;
    """, key, tags_str, group)

proc create_user * (username: string, raw_password: string): void =
    let password_hash = make_password_hash(raw_password)
    db.exec(sql"""
        INSERT INTO users (username, password, created)
        VALUES (?, ?, now());
    """, username, password_hash)
    db.exec(sql"""
        INSERT INTO groups (name, created)
        VALUES (?, now());
    """, username)

    let user_row = db.getRow(sql"""SELECT id FROM users WHERE username = ?;""", username)
    let group_row = db.getRow(sql"""SELECT id FROM groups WHERE name = ?;""", username)

    let user_id = user_row[0]
    let group_id = group_row[0]

    db.exec(sql"""
        INSERT INTO user_group_assoc (user_id, group_id)
        VALUES (?, ?);
    """, user_id, group_id)

proc create_session * (username: string, password: string): (bool, string) =
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

proc get_user_id_from_token * (auth_header: string): int =
    let token = replace(auth_header, "Bearer ", "")
    let row = db.getRow(sql"""
        SELECT user_id
        FROM sessions
        WHERE token = ?;
    """, token)

    # if no user_id was found, this raises a ValueError
    return parseInt(row[0])
    
proc get_group_id_from_user_id * (user_id: int): seq[int] =
    let raw = db.getAllRows(sql"""
        SELECT group_id
        FROM user_group_assoc
        WHERE user_id = ?;
    """, user_id)
    
    let ids = collect(newSeq):
        for row in raw: parseInt(row[0])

    # if no user_id was found, this raises a ValueError
    return ids
#[
    INSERT INTO entries (key, value, tags)
    VALUES ("test", "true", '["foo", "bar"]');
]#

#[
    SELECT * 
    FROM entries
    WHERE tags ? "foo";
]#

#[
    SELECT * 
    FROM entries
    WHERE tags @> '["foo", "bar"]';
]#

#[
    SELECT * 
    FROM entries
    WHERE tags && '["foo", "bar"]';
]#