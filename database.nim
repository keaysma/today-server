import dotenv, json, sugar, std/[
    os,
    strutils,
    strformat,
    db_postgres
]

import utils, migrations

load()
var db_conn * = open(getEnv("db_host"), getEnv("db_user"), getEnv("db_password"), getEnv("db"))
proc db * (): DbConn =
    try:
        discard db_conn.getRow(sql"""SELECT;""")
        #echo("connection is alive")
    except:
        echo("restore db")
        db_conn = open(getEnv("db_host"), getEnv("db_user"), getEnv("db_password"), getEnv("db"))
    return db_conn

type Tags = seq[string]

type
    Entry * = object
        key, value: string
        group: int
        tags: Tags
type
    Item * = object
        key: string
        itype: string
        group: int
        tags: Tags
        config: JsonNode # allegedly (it's actually jsonb)

type
    Publication * = object
        id: string
        title: string
        group_id: int
        tags: seq[string]

proc bootstrap * () =
    echo("Database Bootstrap")
    db().exec(sql"""
        CREATE TABLE IF NOT EXISTS migrations (
            id INT PRIMARY KEY,
            datetime TIMESTAMP NOT NULL
        );
    """);

    echo("Running migrations")
    for idx, mig in migration_path:
        let raw = db().getAllRows(sql"""
            SELECT id
            FROM migrations
            WHERE id = ?;
        """, idx)

        if raw.len > 0:
            echo(fmt"skipping migration #{idx}")
        else:
            echo(fmt"running migration #{idx}")
            mig(db())
            db().exec(sql"""
                INSERT INTO migrations (id, datetime)
                VALUES (?, now());
            """, idx)

proc get_items_by_tags * (tags: Tags, groups: seq[int]): seq[Item] =
    let group_filter = make_database_tuple(groups)
    let vals = collect(newSeq):
        for tag in tags: "\"" & tag & "\""
    let inp = make_database_tags(vals)
    let raw = db().getAllRows(sql(fmt"""
        SELECT key, itype, group_id, config, tags
        FROM items
        WHERE tags <@ ?
        AND group_id IN {group_filter}
        ORDER BY seq;
    """), inp)
    for r in raw:
        result.add(
            Item(
                key: r[0], 
                itype: r[1], 
                group: parseInt(r[2]), 
                config: parseJson(r[3]), 
                tags: parse_pg_array(r[4])
            )
        )

proc get_items_by_tags_public * (tags: Tags, group: int): seq[Item] =
    let secure_tags = tags & @["blog"]
    let vals = collect(newSeq):
        for tag in secure_tags: "\"" & tag & "\""
    let inp = make_database_tags(vals)
    let raw = db().getAllRows(sql"""
        SELECT key, itype, config, tags
        FROM items
        WHERE tags <@ ?
        AND group_id = ?
        ORDER BY seq;
    """, inp, group)
    for r in raw:
        result.add(
            Item(
                key: r[0], 
                itype: r[1], 
                config: parseJson(r[2]), 
                tags: parse_pg_array(r[3])
            )
        )

proc get_all_tag_sets_from_items * (groups: seq[int]): seq[seq[string]] =
    let group_filter = make_database_tuple(groups)
    let raw = db().getAllRows(sql(fmt"""
        SELECT DISTINCT ON (tags) tags 
        FROM items 
        WHERE CAST(tags as TEXT) NOT ILIKE '%:%' 
        AND group_id IN {group_filter};
    """))
    for row in raw:
        result.add(parse_pg_array(row[0]))

proc get_all_tags_from_items * (groups: seq[int]): seq[string] =
    let group_filter = make_database_tuple(groups)
    let raw = db().getAllRows(sql(fmt"""
        SELECT DISTINCT ON (tag) unnest(tags) AS tag 
        FROM items
        WHERE group_id IN {group_filter};
    """))
    for tag in raw:
        result.add(tag)

proc get_all_tags_from_entries * (groups: seq[int]): seq[string] =
    let group_filter = make_database_tuple(groups)
    let raw = db().getAllRows(sql(fmt"""
        SELECT DISTINCT ON (tag) unnest(tags) AS tag
        FROM entries
        WHERE group_id IN {group_filter};
    """))
    for tag in raw:
        result.add(tag)

proc get_publication_by_id * (id: string): (seq[string], int, string) =
    let row = db().getRow(sql"""
        SELECT id, title, group_id, tags
        FROM publications
        WHERE id = ?;
    """, id)

    echo(fmt"SELECT ... FROM publications: {row}")

    let p = Publication(
        id: row[0],
        title: row[1],
        group_id: parseInt(row[2]),
        tags: parse_pg_array(row[3])
    )

    return (p.tags, p.group_id, p.title)

proc get_entries_by_tag * (tags: Tags, groups: seq[int]): seq[Entry] =
    let group_filter = make_database_tuple(groups)
    let vals = collect(newSeq):
        for tag in tags: "\"" & tag & "\""
    let inp = make_database_tags(vals)
    let raw = db().getAllRows(sql(fmt"""
        SELECT key, value, group_id, tags
        FROM entries
        WHERE tags <@ ?
        AND group_id IN {group_filter};
    """), inp)
    for r in raw:
        result.add(Entry(
            key: r[0],
            value: r[1],
            group: parseInt(r[2]),
            tags: parse_pg_array(r[3])
        ))

proc get_entries_by_tag_public * (tags: Tags, group: int): seq[Entry] =
    let secure_tags = tags & @["blog"]
    let vals = collect(newSeq):
        for tag in secure_tags: "\"" & tag & "\""
    let inp = make_database_tags(vals)
    let raw = db().getAllRows(sql(fmt"""
        SELECT key, value, group_id, tags
        FROM entries
        WHERE tags <@ ?
        AND group_id = ?;
    """), inp, group)
    for r in raw:
        result.add(Entry(
            key: r[0],
            value: r[1],
            group: parseInt(r[2]),
            tags: parse_pg_array(r[3])
        ))

proc insert_item * (key: string, itype: string, config_json: string, group: int, tags: seq[string]): void =
    let tags_str: string = make_database_tags(tags)
    db().exec(sql"""
        INSERT INTO items (key, itype, config, tags, group_id)
        VALUES (?, ?, ?, ?, ?);
    """, key, itype, config_json, tags_str, group)

proc upsert_entry * (key: string, value: string, tags: seq[string], group: int): void =
    let tags_str: string = make_database_tags(tags)

    let res = db().getRow(sql"""
        SELECT COUNT(*)
        FROM entries
        WHERE key = ?
        AND tags = ?
        AND group_id = ?;
    """, key, tags_str, group)

    if parseInt(res[0]) > 0:
        db().exec(sql"""
            UPDATE entries
            SET value = ?
            WHERE key = ?
            AND tags = ?
            AND group_id = ?;
        """, value, key, tags_str, group)
    else:
        db().exec(sql"""
            INSERT INTO entries (key, value, tags, group_id)
            VALUES (?, ?, ?, ?);
        """, key, value, tags_str, group)

proc delete_item_by_key * (key: string, group: int): void =
    db().exec(sql"""
        DELETE FROM items
        WHERE key = ?
        AND group_id = ?;
    """, key, group)

proc delete_entry_by_key_tags * (key: string, tags: seq[string], group: int): void =
    let tags_str: string = make_database_tags(tags)
    echo(tags_str)
    db().exec(sql"""
        DELETE FROM entries
        WHERE key = ?
        AND tags = ?
        AND group_id = ?;
    """, key, tags_str, group)

proc create_user * (username: string, raw_password: string): void =
    let password_hash = make_password_hash(raw_password)
    db().exec(sql"""
        INSERT INTO users (username, password, created)
        VALUES (?, ?, now());
    """, username, password_hash)
    db().exec(sql"""
        INSERT INTO groups (name, created)
        VALUES (?, now());
    """, username)

    let user_row = db().getRow(sql"""SELECT id FROM users WHERE username = ?;""", username)
    let group_row = db().getRow(sql"""SELECT id FROM groups WHERE name = ?;""", username)

    let user_id = user_row[0]
    let group_id = group_row[0]

    db().exec(sql"""
        INSERT INTO user_group_assoc (user_id, group_id)
        VALUES (?, ?);
    """, user_id, group_id)

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