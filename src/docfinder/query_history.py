"""Local, opt-in query history storage."""

from __future__ import annotations

import sqlite3
from contextlib import closing
from pathlib import Path

from docfinder.settings import get_settings_path

MAX_QUERY_HISTORY = 500


def _database_path() -> Path:
    return get_settings_path().parent / "query_history.sqlite3"


def _connect() -> sqlite3.Connection:
    database_path = _database_path()
    database_path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(database_path, timeout=5)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA busy_timeout = 5000")
    connection.execute("PRAGMA secure_delete = ON")
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS query_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query TEXT NOT NULL,
            result_count INTEGER NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    return connection


def record_query(query: str, result_count: int) -> None:
    """Store a query and trim history to the newest 500 entries."""
    with closing(_connect()) as connection, connection:
        connection.execute(
            "INSERT INTO query_history (query, result_count) VALUES (?, ?)",
            (query, result_count),
        )
        connection.execute(
            """
            DELETE FROM query_history
            WHERE id NOT IN (
                SELECT id FROM query_history ORDER BY id DESC LIMIT ?
            )
            """,
            (MAX_QUERY_HISTORY,),
        )


def list_queries() -> list[dict[str, int | str]]:
    """Return recent searches, newest first."""
    with closing(_connect()) as connection, connection:
        rows = connection.execute(
            """
            SELECT query, result_count, created_at
            FROM query_history
            ORDER BY id DESC
            LIMIT ?
            """,
            (MAX_QUERY_HISTORY,),
        ).fetchall()
    return [dict(row) for row in rows]


def clear_queries() -> None:
    """Delete all locally stored searches."""
    with closing(_connect()) as connection, connection:
        connection.execute("DELETE FROM query_history")
        connection.commit()
        connection.execute("VACUUM")
