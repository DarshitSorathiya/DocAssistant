"""Tests for local query history storage."""

from __future__ import annotations

from pathlib import Path

from docfinder import query_history


def test_query_history_is_bounded_and_newest_first(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(
        query_history,
        "get_settings_path",
        lambda: tmp_path / "settings.json",
    )

    for index in range(query_history.MAX_QUERY_HISTORY + 1):
        query_history.record_query(f"query {index}", index)

    history = query_history.list_queries()
    assert len(history) == query_history.MAX_QUERY_HISTORY
    assert history[0]["query"] == f"query {query_history.MAX_QUERY_HISTORY}"
    assert history[-1]["query"] == "query 1"

    query_history.clear_queries()
    assert query_history.list_queries() == []
