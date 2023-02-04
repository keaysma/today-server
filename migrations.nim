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

proc add_users (db: DbConn) =
    db.exec(sql"""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            username varchar(50) UNIQUE,
            password varchar(64),
            created TIMESTAMP NOT NULL
        );
    """)
    db.exec(sql"""
        CREATE TABLE IF NOT EXISTS groups (
            id SERIAL PRIMARY KEY,
            name varchar(50),
            created TIMESTAMP NOT NULL
        );
    """)
    db.exec(sql"""
        CREATE TABLE IF NOT EXISTS user_group_assoc (
            user_id INT,
            group_id INT,
            CONSTRAINT fk_user FOREIGN KEY(user_id) REFERENCES users(id),
            CONSTRAINT fk_group FOREIGN KEY(group_id) REFERENCES groups(id)
        );
    """)
    db.exec(sql"""
        ALTER TABLE items
        ADD COLUMN group_id INT
        CONSTRAINT fk_group REFERENCES groups(id);
    """)
    db.exec(sql"""
        ALTER TABLE entries
        ADD COLUMN group_id INT
        CONSTRAINT fk_group REFERENCES groups(id);
    """)

proc add_sessions (db: DbConn) =
    db.exec(sql"""
        CREATE TABLE IF NOT EXISTS sessions (
            token varchar(512) UNIQUE,
            user_id INT,
            expires TIMESTAMP,
            CONSTRAINT fk_session_user FOREIGN KEY(user_id) REFERENCES users(id)
        );
    """)

proc add_publications (db: DbConn) =
    db.exec(sql"""
        CREATE TABLE IF NOT EXISTS publications (
            id varchar(50) UNIQUE NOT NULL,
            title varchar(250) NOT NULL,
            group_id INT NOT NULL,
            created TIMESTAMP NOT NULL,
            tags text[] not null,
            CONSTRAINT fk_publication_group FOREIGN KEY(group_id) REFERENCES groups(id)
        );
    """)

let migration_path * = @[
    create_items_and_entries,
    add_users,
    add_sessions,
    add_publications
]