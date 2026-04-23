#!/usr/bin/env python3
"""
merge_lora.py — Merge LoRA adapter into base model for deployment.

TODO: Implement following the lab guide.

Environment:
  BASE_MODEL    — HuggingFace model ID
  ADAPTER_PATH  — Path to LoRA checkpoint
  MERGED_PATH   — Where to save the merged model
"""
import os

BASE_MODEL   = os.environ.get("BASE_MODEL",   "HuggingFaceTB/SmolLM2-135M-Instruct")
ADAPTER_PATH = os.environ.get("ADAPTER_PATH", "/mnt/project/training/runs/latest/checkpoint-50")
MERGED_PATH  = os.environ.get("MERGED_PATH",  "/mnt/project/training/merged-model")


def main():
    # TODO: Load base model from BASE_MODEL
    # TODO: Load PeftModel from ADAPTER_PATH
    # TODO: Call merge_and_unload() to merge LoRA weights
    # TODO: Save merged model and tokenizer to MERGED_PATH
    pass


if __name__ == "__main__":
    main()
