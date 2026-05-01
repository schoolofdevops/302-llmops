#!/usr/bin/env python3
"""
build_index.py — Build FAISS index from Smile Dental clinic data.

Loads treatments, policies, and FAQs from DATA_DIR.
Encodes with fastembed (all-MiniLM-L6-v2, ONNX runtime — lightweight, no PyTorch).
Saves faiss.index and metadata.json to INDEX_DIR.

Usage:
    python build_index.py
    INDEX_DIR=/data INDEX_DIR=datasets/index python build_index.py
"""
import json, os
import faiss
import numpy as np
from pathlib import Path
from fastembed import TextEmbedding

# --- Configuration ---
DATA_DIR = Path(os.environ.get("DATA_DIR", "datasets/clinic"))
INDEX_DIR = Path(os.environ.get("INDEX_DIR", "datasets/index"))
EMBED_MODEL = os.environ.get("EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
EMBED_DIM = 384  # all-MiniLM-L6-v2 output dimension


def load_chunks(data_dir: Path) -> list[dict]:
    """Load clinic data files and return a flat list of text chunks.

    Each chunk: {"doc_id": str, "section": str, "text": str}
    Treatments, policies, and FAQs are each mapped to one chunk per record.
    """
    chunks = []

    # ---- Treatments ----
    treatments_file = data_dir / "treatments.json"
    with open(treatments_file, encoding="utf-8") as f:
        treatments = json.load(f)
    for t in treatments:
        indications = "; ".join(t.get("indications", []))
        aftercare = ". ".join(t.get("aftercare", []))
        price_low, price_high = t["price_band_inr"]
        text = (
            f"Treatment: {t['name']} (Code: {t['code']}). "
            f"Category: {t['category']}. Specialist: {t['specialist']}. "
            f"Indications: {indications}. "
            f"Duration: {t['duration_minutes']} minutes, {t['visits']} visit(s). "
            f"Cost at Smile Dental Clinic, Pune: ₹{price_low:,} to ₹{price_high:,}. "
            f"Aftercare: {aftercare}."
        )
        chunks.append({"doc_id": t["code"], "section": "treatments", "text": text})

    # ---- Policies ----
    policies_file = data_dir / "policies.json"
    with open(policies_file, encoding="utf-8") as f:
        policies = json.load(f)
    for p in policies:
        text = f"{p['title']}: {p['details']}"
        chunks.append({"doc_id": p["id"], "section": "policies", "text": text})

    # ---- FAQs ----
    faqs_file = data_dir / "faqs.json"
    with open(faqs_file, encoding="utf-8") as f:
        faqs = json.load(f)
    for faq in faqs:
        text = f"Q: {faq['question']} A: {faq['answer']}"
        chunks.append({"doc_id": faq["id"], "section": "faqs", "text": text})

    return chunks


def build_and_save(chunks: list[dict], index_dir: Path, embed_model: str):
    """Encode chunks, build FAISS IndexFlatIP, and persist to disk."""
    print(f"Loading embedding model: {embed_model}")
    model = TextEmbedding(embed_model)

    texts = [c["text"] for c in chunks]
    print(f"Encoding {len(texts)} chunks...")
    embeddings = np.array(list(model.embed(texts)), dtype=np.float32)

    # fastembed returns normalized vectors by default — inner product = cosine
    index = faiss.IndexFlatIP(EMBED_DIM)
    index.add(embeddings)

    # Persist index and metadata
    index_dir.mkdir(parents=True, exist_ok=True)
    faiss.write_index(index, str(index_dir / "faiss.index"))
    with open(index_dir / "metadata.json", "w", encoding="utf-8") as f:
        json.dump(chunks, f, ensure_ascii=False, indent=2)

    print(f"Built index: {len(chunks)} chunks → {index_dir}/faiss.index")


if __name__ == "__main__":
    chunks = load_chunks(DATA_DIR)
    print(f"Loaded {len(chunks)} chunks from {DATA_DIR}")
    build_and_save(chunks, INDEX_DIR, EMBED_MODEL)
