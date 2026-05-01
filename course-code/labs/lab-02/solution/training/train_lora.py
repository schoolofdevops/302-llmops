#!/usr/bin/env python3
"""
train_lora.py — CPU LoRA fine-tuning of SmolLM2-135M-Instruct on Smile Dental data.

Environment:
  BASE_MODEL      — HuggingFace model ID (default: HuggingFaceTB/SmolLM2-135M-Instruct)
  DATA_PATH       — JSONL training data path (default: /mnt/project/datasets/train/dental_chat.jsonl)
  OUTPUT_ROOT     — Where to save checkpoints (default: /mnt/project/training/runs)
  MAX_STEPS       — Training steps (default: 50 — ~15 min on CPU)
  BATCH_SIZE      — Per-device batch size (default: 1 — CPU constraint)
  GRAD_ACCUM      — Gradient accumulation steps (default: 4 — effective batch 4)
  LORA_R          — LoRA rank (default: 8)
  LORA_ALPHA      — LoRA alpha (default: 16)
"""
import os, json, time
from pathlib import Path
from datetime import datetime

import torch
from datasets import Dataset
from transformers import (
    AutoTokenizer,
    AutoModelForCausalLM,
    TrainingArguments,
    Trainer,
    DataCollatorForSeq2Seq,
)
from peft import LoraConfig, get_peft_model, TaskType

# --- Configuration ---
BASE_MODEL   = os.environ.get("BASE_MODEL",   "HuggingFaceTB/SmolLM2-135M-Instruct")
DATA_PATH    = os.environ.get("DATA_PATH",    "/mnt/project/datasets/train/dental_chat.jsonl")
OUTPUT_ROOT  = os.environ.get("OUTPUT_ROOT",  "/mnt/project/training/runs")
MAX_STEPS    = int(os.environ.get("MAX_STEPS",    "50"))   # ↓ conservative for CPU workshop
BATCH_SIZE   = int(os.environ.get("BATCH_SIZE",   "1"))    # CPU cannot do larger batches
GRAD_ACCUM   = int(os.environ.get("GRAD_ACCUM",   "4"))    # effective batch = 4
LORA_R       = int(os.environ.get("LORA_R",       "8"))    # small rank for 135M model
LORA_ALPHA   = int(os.environ.get("LORA_ALPHA",   "16"))

MAX_SEQ_LEN  = 512   # Truncate to keep memory bounded on CPU


# --- Dataset loading ---

def load_and_tokenize(path: str, tokenizer) -> list[dict]:
    """Read JSONL where each line has {"messages": [...]}, apply chat template,
    return list of dicts with 'input_ids' and 'labels' for causal LM training."""
    samples = []
    with open(path, encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            record = json.loads(line)
            messages = record.get("messages", [])
            if not messages:
                continue
            # Apply the model's built-in chat template to produce a single string
            text = tokenizer.apply_chat_template(
                messages,
                tokenize=False,
                add_generation_prompt=False,
            )
            enc = tokenizer(
                text,
                truncation=True,
                max_length=MAX_SEQ_LEN,
                padding=False,
                return_tensors=None,
            )
            input_ids = enc["input_ids"]
            # For causal LM, labels == input_ids (shift handled inside model)
            samples.append({"input_ids": input_ids, "labels": input_ids.copy()})
    return samples


# --- Main training routine ---

def main():
    # Timestamped run directory so multiple runs don't collide
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    run_dir = Path(OUTPUT_ROOT) / f"run-{timestamp}"
    run_dir.mkdir(parents=True, exist_ok=True)

    print(f"Base model: {BASE_MODEL}")
    print(f"Data path:  {DATA_PATH}")
    print(f"Run dir:    {run_dir}")
    print(f"Max steps:  {MAX_STEPS}")

    # ---- Tokenizer ----
    tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    # ---- Dataset ----
    raw_samples = load_and_tokenize(DATA_PATH, tokenizer)
    print(f"Loaded {len(raw_samples)} training samples")
    hf_dataset = Dataset.from_list(raw_samples)

    # ---- Model ----
    # float32 for CPU stability (bfloat16 can cause issues on some CPU builds)
    model = AutoModelForCausalLM.from_pretrained(
        BASE_MODEL,
        dtype=torch.float32,
    )

    # ---- LoRA configuration (PEFT 0.19.0 stable params) ----
    lora_config = LoraConfig(
        r=LORA_R,
        lora_alpha=LORA_ALPHA,
        target_modules=["q_proj", "v_proj"],   # SmolLM2-135M attention projections
        lora_dropout=0.05,
        bias="none",
        task_type=TaskType.CAUSAL_LM,
    )
    model = get_peft_model(model, lora_config)
    model.print_trainable_parameters()

    # ---- Training arguments ----
    training_args = TrainingArguments(
        output_dir=str(run_dir),
        max_steps=MAX_STEPS,
        per_device_train_batch_size=BATCH_SIZE,
        gradient_accumulation_steps=GRAD_ACCUM,
        learning_rate=2e-4,
        lr_scheduler_type="cosine",
        warmup_steps=5,
        logging_steps=10,
        save_steps=MAX_STEPS,      # Save once at the end
        use_cpu=True,              # Force CPU — KIND cluster nodes have no GPU
        report_to="none",          # No wandb/tensorboard in workshop environment
    )

    # ---- Data collator ----
    data_collator = DataCollatorForSeq2Seq(
        tokenizer,
        pad_to_multiple_of=8,
        return_tensors="pt",
    )

    # ---- Train ----
    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=hf_dataset,
        data_collator=data_collator,
    )

    t0 = time.time()
    trainer.train()
    elapsed = time.time() - t0
    print(f"Training complete in {elapsed:.0f}s ({elapsed/60:.1f} min)")

    # Trainer saves adapter to {run_dir}/checkpoint-{MAX_STEPS}/
    print(f"Training complete. Adapter saved to: {run_dir}/checkpoint-{MAX_STEPS}")

    # ---- Persist run metadata ----
    run_info = {
        "base_model":    BASE_MODEL,
        "data_path":     DATA_PATH,
        "max_steps":     MAX_STEPS,
        "lora_r":        LORA_R,
        "run_dir":       str(run_dir),
        "completed_at":  datetime.now().isoformat(),
    }
    with open(run_dir / "run_info.json", "w") as fh:
        json.dump(run_info, fh, indent=2)
    print("Run metadata saved to run_info.json")


if __name__ == "__main__":
    main()
