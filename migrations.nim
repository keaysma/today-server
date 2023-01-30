import std/db_postgres

proc create_items_and_entries (db: DbConn) =
    db.exec(sql("""
        CREATE TABLE IF NOT EXISTS items (
            seq SERIAL,
            key varchar(50) not null,
            itype varchar(50) not null,
            tags text[] not null,
            config jsonb
        );
    """));
    db.exec(sql("""
        CREATE TABLE IF NOT EXISTS entries (
            key varchar(50) not null,
            value varchar(250) not null,
            tags text[] not null
        );
    """));

let migration_path * = @[
    create_items_and_entries
]