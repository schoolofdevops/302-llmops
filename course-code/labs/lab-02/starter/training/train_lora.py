#!/usr/bin/env python3
"""
train_lora.py — CPU LoRA fine-tuning of SmolLM2-135M-Instruct.

TODO: Implement following the lab guide.

Environment:
  BASE_MODEL    — HuggingFace model ID (default: HuggingFaceTB/SmolLM2-135M-Instruct)
  DATA_PATH     — JSONL training data path
  OUTPUT_ROOT   — Where to save checkpoints
  MAX_STEPS     — Training steps (default: 50)
"""
import os
from pathlib import Path

BASE_MODEL   = os.environ.get("BASE_MODEL",   "HuggingFaceTB/SmolLM2-135M-Instruct")
DATA_PATH    = os.environ.get("DATA_PATH",    "/mnt/project/datasets/train/dental_chat.jsonl")
OUTPUT_ROOT  = os.environ.get("OUTPUT_ROOT",  "/mnt/project/training/runs")
MAX_STEPS    = int(os.environ.get("MAX_STEPS", "50"))
BATCH_SIZE   = int(os.environ.get("BATCH_SIZE", "1"))
GRAD_ACCUM   = int(os.environ.get("GRAD_ACCUM", "4"))


def main():
    # TODO: Load tokenizer from BASE_MODEL
    # TODO: Load dataset from DATA_PATH (JSONL with messages format)
    # TODO: Configure LoraConfig (r=8, lora_alpha=16, target_modules=["q_proj", "v_proj"])
    # TODO: Apply LoRA to model with get_peft_model()
    # TODO: Configure TrainingArguments (max_steps=MAX_STEPS, use_cpu=True)
    # TODO: Train with Trainer and save
    pass


if __name__ == "__main__":
    main()
