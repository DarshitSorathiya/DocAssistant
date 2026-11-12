"""Semantic search interface."""

from __future__ import annotations

import json
import re
from _thread import LockType
from contextlib import nullcontext
from dataclasses import dataclass
from difflib import get_close_matches
from pathlib import Path
from typing import List, Sequence

from docfinder.embedding.encoder import EmbeddingModel
from docfinder.index.reranker import Reranker
from docfinder.index.storage import (
    SQLiteVectorStore,
    extract_field_identifier,
    identifier_field_intent,
    query_identifier_values,
)


@dataclass(slots=True)
class SearchResult:
    path: Path
    title: str
    chunk_index: int
    score: float
    text: str
    metadata: dict


class Searcher:
    """High-level API to query the vector store."""

    def __init__(
        self,
        embedder: EmbeddingModel,
        store: SQLiteVectorStore,
        reranker: Reranker | None = None,
        inference_lock: LockType | None = None,
    ) -> None:
        self.embedder = embedder
        self.store = store
        self.reranker = reranker
        self.inference_lock = inference_lock

    def search(
        self,
        query: str,
        *,
        top_k: int = 10,
        folders: list[str] | None = None,
        paths: list[str] | None = None,
    ) -> List[SearchResult]:
        # When reranking, fetch more candidates for the cross-encoder to evaluate
        fetch_k = max(top_k * 3, 30) if self.reranker is not None else top_k

        is_code_query = query.strip().lower().startswith("code:")
        embed_input = query.strip()[5:].strip() if is_code_query else query
        if not embed_input:
            embed_input = query

        with self.inference_lock or nullcontext():
            try:
                embedding = (
                    self.embedder.embed_query(embed_input, task="code")
                    if is_code_query
                    else self.embedder.embed_query(embed_input)
                )
            except TypeError:
                embedding = self.embedder.embed_query(embed_input)

        search_options = {}
        if paths is not None:
            search_options["paths"] = paths
        if "\n" in query or "\r" in query:
            search_options["multiline_query"] = query
        try:
            rows = self.store.search(
                embedding,
                top_k=fetch_k,
                folders=folders,
                query_text=embed_input,
                **search_options,
            )
        except TypeError:
            if search_options:
                raise
            rows = self.store.search(embedding, top_k=fetch_k, folders=folders)

        if self.reranker is not None and rows:
            field_intent = identifier_field_intent(query)
            identifier_values = query_identifier_values(query)
            # Build dicts for the reranker
            candidates = []
            for row in rows:
                candidates.append(
                    {
                        "path": row["path"],
                        "title": row["title"],
                        "chunk_index": row["chunk_index"],
                        "score": float(row["score"]),
                        "text": row["text"],
                        "metadata": row.get("metadata"),
                    }
                )
            with self.inference_lock or nullcontext():
                reranked = self.reranker.rerank(
                    query,
                    candidates,
                    top_k=fetch_k if field_intent or identifier_values else top_k,
                )
            if field_intent or identifier_values:
                reranked.sort(
                    key=lambda result: (
                        bool(extract_field_identifier(query, result["text"])),
                        any(
                            value in f"{result['title']} {result['text']}".casefold()
                            for value in identifier_values
                        ),
                        float(result["score"]),
                    ),
                    reverse=True,
                )
                reranked = reranked[:top_k]
            results: List[SearchResult] = []
            for r in reranked:
                metadata = json.loads(r["metadata"]) if r.get("metadata") else {}
                results.append(
                    SearchResult(
                        path=Path(r["path"]),
                        title=r["title"],
                        chunk_index=r["chunk_index"],
                        score=float(r["score"]),
                        text=r["text"],
                        metadata=metadata,
                    )
                )
            return results

        results = []
        for row in rows:
            metadata = json.loads(row["metadata"]) if row.get("metadata") else {}
            results.append(
                SearchResult(
                    path=Path(row["path"]),
                    title=row["title"],
                    chunk_index=row["chunk_index"],
                    score=float(row["score"]),
                    text=row["text"],
                    metadata=metadata,
                )
            )
        return results


def suggest_spelling(query: str, results: Sequence[SearchResult]) -> str | None:
    """Suggest one likely correction from terms in the best matching local results."""
    words = {
        word.casefold()
        for result in results[:10]
        for word in re.findall(r"[^\W_]{4,}", f"{result.title} {result.text}", re.UNICODE)
    }
    query_words = re.findall(r"[^\W_]{4,}", query, re.UNICODE)
    for word in query_words:
        if word.casefold() in words:
            continue
        matches = get_close_matches(word.casefold(), words, n=1, cutoff=0.78)
        if matches:
            return re.sub(
                rf"\b{re.escape(word)}\b",
                matches[0],
                query,
                count=1,
                flags=re.IGNORECASE,
            )
    return None
