#!/usr/bin/env python3
"""
retriever.py — FastAPI FAISS retriever for Smile Dental RAG pipeline.

Serves:
  GET  /health   → {"ok": True}
  POST /search   → {"hits": [...], "latency_seconds": float}
  GET  /metrics  → Prometheus text format

Environment:
  INDEX_PATH      — path to faiss.index file (default: /data/faiss.index)
  META_PATH       — path to metadata.json file (default: /data/metadata.json)
  EMBEDDING_MODEL — fastembed model name
"""
import json, os, time
import faiss
import numpy as np
from pathlib import Path
from fastapi import FastAPI
from pydantic import BaseModel
from fastembed import TextEmbedding
from prometheus_client import Counter, Histogram, make_asgi_app

# --- Configuration ---
INDEX_PATH = os.environ.get("INDEX_PATH", "/data/faiss.index")
META_PATH  = os.environ.get("META_PATH",  "/data/metadata.json")
EMBED_MODEL = os.environ.get("EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2")

# ---- Load FAISS index and metadata on startup (not inside route handlers) ----
print(f"Loading FAISS index from {INDEX_PATH}")
index = faiss.read_index(INDEX_PATH)

print(f"Loading metadata from {META_PATH}")
with open(META_PATH, encoding="utf-8") as f:
    metadata: list[dict] = json.load(f)

print(f"Loading embedding model: {EMBED_MODEL}")
embed_model = TextEmbedding(EMBED_MODEL)

# ---- Prometheus metrics ----
search_requests_total = Counter(
    "retriever_search_requests_total",
    "Total number of /search requests",
    ["status"],
)
search_latency_seconds = Histogram(
    "retriever_search_latency_seconds",
    "End-to-end latency for /search requests",
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5],
)

# ---- FastAPI app ----
app = FastAPI(title="Smile Dental RAG Retriever", version="1.0.0")

# Mount Prometheus metrics endpoint at /metrics
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)


class SearchRequest(BaseModel):
    query: str
    k: int = 3


@app.get("/health")
def health():
    """Liveness probe — returns ok=True when the service is running."""
    return {"ok": True}


@app.post("/search")
def search(req: SearchRequest):
    """Encode query, search FAISS index, return top-k chunks with scores."""
    t0 = time.perf_counter()
    try:
        # Encode with same model used at index build time
        query_vec = np.array(
            list(embed_model.embed([req.query])), dtype=np.float32
        )

        scores, indices = index.search(query_vec, req.k)

        hits = []
        for score, idx in zip(scores[0], indices[0]):
            if idx < 0 or idx >= len(metadata):
                continue
            chunk = metadata[idx]
            hits.append({
                "doc_id": chunk["doc_id"],
                "section": chunk["section"],
                "text": chunk["text"],
                "score": float(score),
            })

        latency = time.perf_counter() - t0
        search_requests_total.labels(status="ok").inc()
        search_latency_seconds.observe(latency)

        return {"hits": hits, "latency_seconds": round(latency, 4)}

    except Exception as exc:  # noqa: BLE001
        search_requests_total.labels(status="error").inc()
        raise exc


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
