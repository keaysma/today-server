import sugar
import std/strutils
import std/sequtils
import std/strformat
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

proc get_items_by_tags * (tags: Tags): seq[Item] =
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

proc get_all_tags_from_items * (): seq[string] =
    let raw = db.getAllRows(sql"""
        SELECT DISTINCT ON (tag) unnest(tags) AS tag 
        FROM items;
    """)
    for tag in raw:
        result.add(tag)

proc get_all_tags_from_entries * (): seq[string] =
    let raw = db.getAllRows(sql"""
        SELECT DISTINCT ON (tag) unnest(tags) AS tag
        FROM entries;
    """)
    for tag in raw:
        result.add(tag)

proc get_entries_by_tag * (tags: Tags): seq[Entry] =
    let vals = collect(newSeq):
        for tag in tags: "\"" & tag & "\""
    let inp = make_database_tags(vals)
    let raw = db.getAllRows(sql"""
        SELECT key, value, tags
        FROM entries
        WHERE tags <@ ?;
    """, inp)
    for r in raw:
        result.add(Entry(
            key: r[0],
            value: r[1],
            tags: parse_pg_array(r[2])
        ))

proc insert_item * (key: string, itype: string, tags: seq[string]): void =
    let tags_str: string = make_database_tags(tags)
    db.exec(sql"""
        INSERT INTO items (key, itype, tags)
        VALUES (?, ?, ?);
    """, key, itype, tags_str)

proc upsert_entry * (key: string, value: string, tags: seq[string]): void =
    let tags_str: string = make_database_tags(tags)

    let res = db.getRow(sql"""
        SELECT COUNT(*)
        FROM entries
        WHERE key = ?
        AND tags = ?;
    """, key, tags_str)

    if parseInt(res[0]) > 0:
        db.exec(sql"""
            UPDATE entries
            SET value = ?
            WHERE key = ?
            AND tags = ?;
        """, value, key, tags_str)
    else:
        db.exec(sql"""
            INSERT INTO entries (key, value, tags)
            VALUES (?, ?, ?);
        """, key, value, tags_str)

proc delete_item_by_key * (key: string): void =
    db.exec(sql"""
        DELETE FROM items
        WHERE key = ?;
    """, key)

proc delete_entry_by_key_tags * (key: string, tags: seq[string]): void =
    let tags_str: string = make_database_tags(tags)
    echo(tags_str)
    db.exec(sql"""
        DELETE FROM entries
        WHERE key = ?
        AND tags = ?;
    """, key, tags_str)

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