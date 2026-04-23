#!/usr/bin/env python3
"""
build_index.py — Build FAISS index from Smile Dental clinic data.

TODO: Implement following the lab guide.

Loads: datasets/clinic/treatments.json, policies.json, faqs.json
Saves: INDEX_DIR/faiss.index and INDEX_DIR/metadata.json
"""
import json, os
import numpy as np
from pathlib import Path

DATA_DIR = Path(os.environ.get("DATA_DIR", "datasets/clinic"))
INDEX_DIR = Path(os.environ.get("INDEX_DIR", "datasets/index"))
EMBED_MODEL = os.environ.get("EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
EMBED_DIM = 384  # all-MiniLM-L6-v2 output dimension


def load_chunks(data_dir: Path) -> list[dict]:
    """Load clinic data files and return list of text chunks."""
    # TODO: Load and parse treatments.json, policies.json, faqs.json
    # TODO: Return list of {"doc_id": str, "section": str, "text": str}
    pass


def build_and_save(chunks: list[dict], index_dir: Path, embed_model: str):
    """Encode chunks, build FAISS IndexFlatIP, save index and metadata."""
    # TODO: Load SentenceTransformer model
    # TODO: Encode chunks with normalize_embeddings=True
    # TODO: Create faiss.IndexFlatIP(EMBED_DIM) and add embeddings
    # TODO: Write faiss.index and metadata.json to index_dir
    pass


if __name__ == "__main__":
    chunks = load_chunks(DATA_DIR)
    print(f"Loaded {len(chunks)} chunks from {DATA_DIR}")
    build_and_save(chunks, INDEX_DIR, EMBED_MODEL)
