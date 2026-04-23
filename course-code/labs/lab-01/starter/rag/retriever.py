#!/usr/bin/env python3
"""
retriever.py — FastAPI FAISS retriever service.

TODO: Implement following the lab guide.

Endpoints:
  GET  /health   → {"ok": True}
  POST /search   → {"hits": [...], "latency_seconds": float}
  GET  /metrics  → Prometheus text format
"""
import json, os, time
import numpy as np
from pathlib import Path
from fastapi import FastAPI
from pydantic import BaseModel

INDEX_PATH = os.environ.get("INDEX_PATH", "/data/faiss.index")
META_PATH  = os.environ.get("META_PATH",  "/data/metadata.json")
EMBED_MODEL = os.environ.get("EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2")

app = FastAPI(title="Smile Dental RAG Retriever")


class SearchRequest(BaseModel):
    query: str
    k: int = 3


# TODO: Load FAISS index and metadata on startup (module level)
# TODO: Load SentenceTransformer model on startup


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/search")
def search(req: SearchRequest):
    # TODO: Encode req.query with SentenceTransformer (normalize_embeddings=True)
    # TODO: Run FAISS search
    # TODO: Return {"hits": [...], "latency_seconds": float}
    pass


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
