#!/usr/bin/env python3
"""
merge_lora.py — Merge LoRA adapter weights into base model for deployment.

Reads adapter from ADAPTER_PATH, merges into BASE_MODEL, saves full model to MERGED_PATH.
The merged model directory is the input to Lab 03 (OCI image build).

Environment:
  BASE_MODEL    — HuggingFace model ID (default: HuggingFaceTB/SmolLM2-135M-Instruct)
  ADAPTER_PATH  — Path to LoRA checkpoint dir (default: /mnt/project/training/runs/latest/checkpoint-50)
  MERGED_PATH   — Where to save merged model (default: /mnt/project/training/merged-model)
"""
import os
from pathlib import Path

import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
from peft import PeftModel

# --- Configuration ---
BASE_MODEL   = os.environ.get("BASE_MODEL",   "HuggingFaceTB/SmolLM2-135M-Instruct")
ADAPTER_PATH = os.environ.get("ADAPTER_PATH", "/mnt/project/training/runs/latest/checkpoint-50")
MERGED_PATH  = os.environ.get("MERGED_PATH",  "/mnt/project/training/merged-model")


def main():
    # Guard: adapter must exist before we attempt to merge
    adapter_path = Path(ADAPTER_PATH)
    if not adapter_path.exists():
        print(f"ERROR: ADAPTER_PATH does not exist: {ADAPTER_PATH}")
        print("Run train_lora.py first, then set ADAPTER_PATH to the checkpoint directory.")
        raise SystemExit(1)

    merged_path = Path(MERGED_PATH)
    merged_path.mkdir(parents=True, exist_ok=True)

    print(f"Base model:   {BASE_MODEL}")
    print(f"Adapter path: {ADAPTER_PATH}")
    print(f"Merged path:  {MERGED_PATH}")

    # ---- Load base model ----
    print("Loading base model...")
    base_model = AutoModelForCausalLM.from_pretrained(
        BASE_MODEL,
        torch_dtype=torch.float32,
    )

    # ---- Wrap with PEFT adapter ----
    print("Loading LoRA adapter...")
    peft_model = PeftModel.from_pretrained(base_model, ADAPTER_PATH)

    # ---- Merge adapter weights into base model ----
    print("Merging LoRA weights into base model...")
    merged_model = peft_model.merge_and_unload()

    # ---- Save merged model ----
    print(f"Saving merged model to {MERGED_PATH}...")
    merged_model.save_pretrained(MERGED_PATH)

    # ---- Save tokenizer alongside model ----
    print("Saving tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL)
    tokenizer.save_pretrained(MERGED_PATH)

    print(f"Merged model saved to: {MERGED_PATH}")
    print("Files in merged directory:")
    for f in sorted(merged_path.iterdir()):
        size_mb = f.stat().st_size / 1_048_576 if f.is_file() else 0
        print(f"  {f.name:<40} {size_mb:>8.2f} MB" if f.is_file() else f"  {f.name}/")


if __name__ == "__main__":
    main()
