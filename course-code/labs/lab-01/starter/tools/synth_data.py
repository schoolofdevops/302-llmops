#!/usr/bin/env python3
"""
synth_data.py — Generate Smile Dental JSONL fine-tuning dataset.

TODO: Implement this script following the lab guide.

Reads: datasets/clinic/treatments.json, policies.json, faqs.json
Writes: datasets/train/dental_chat.jsonl

Each output line format:
{"messages": [{"role": "system", ...}, {"role": "user", ...}, {"role": "assistant", ...}]}
"""
import json, os
from pathlib import Path

DATA_DIR = Path(os.environ.get("DATA_DIR", "datasets/clinic"))
OUTPUT_DIR = Path(os.environ.get("OUTPUT_DIR", "datasets/train"))
SYSTEM_PROMPT = (
    "You are a helpful assistant for Smile Dental Clinic, Pune. "
    "Answer questions about dental treatments, pricing (in INR), appointment policies, "
    "and general dental health. Be concise, accurate, and friendly."
)


def build_example(user: str, assistant: str) -> dict:
    """Return a single chat training example as a messages dict."""
    # TODO: Implement this function
    pass


def main():
    """Load clinic data and generate JSONL training examples."""
    # TODO: Load treatments.json, policies.json, faqs.json from DATA_DIR
    # TODO: Generate Q&A examples for each data source
    # TODO: Write examples to OUTPUT_DIR/dental_chat.jsonl
    # TODO: Print summary
    pass


if __name__ == "__main__":
    main()
