---
plan: 02-05
phase: 02-modernize-llmops-spine-labs-00-05
status: complete
completed: 2026-06-15
---

# Plan 02-05 Summary — Lab 02: CPU LoRA Fine-tuning

## What Was Built

- Training job manifest optimized for 10 GB Docker Desktop (4Gi limit vs original 8Gi)
- MAX_SEQ_LEN made env-configurable in train_lora.py (default 256, was hardcoded 512)
- LORA_R=4 and MAX_SEQ_LEN=256 added as env vars to job manifest (both solution + starter)
- smollm2-trainer Docker image built and pushed to kind-registry:5001
- Training job submitted and completed: 50 steps, 8.6 minutes, no OOM

## Evidence

### Job status
```
NAME                 STATUS     COMPLETIONS   DURATION
smollm2-lora-train   Complete   1/1           12m
```

### Training log summary
```
trainable params: 230,400 || all params: 134,745,408 || trainable%: 0.1710
{'loss': '2.888', 'grad_norm': '0.8906', 'epoch': '0.2439'}
{'loss': '2.729', 'grad_norm': '0.8274', 'epoch': '0.4878'}
{'loss': '2.493', 'grad_norm': '0.5991', 'epoch': '0.7317'}
{'loss': '2.506', 'grad_norm': '0.6196', 'epoch': '0.9756'}
{'loss': '2.442', 'grad_norm': '0.61',   'epoch': '1.22'}
Training complete in 514s (8.6 min)
```

### LoRA adapter artifacts
```
checkpoint-50/
  adapter_config.json          1.0K
  adapter_model.safetensors  915.1K
  tokenizer.json               3.4M
  run_info.json                266B
  ... (11 files total)
```

## Memory Optimization

| Parameter | Before | After |
|-----------|--------|-------|
| memory request | 6Gi | 3Gi |
| memory limit | 8Gi | 4Gi |
| LORA_R | 8 (hardcoded) | 4 (env var override) |
| MAX_SEQ_LEN | 512 (hardcoded) | 256 (env var, default) |

Result: training fits in 9.7 GB Docker Desktop. Docker Desktop minimum updated to 10 GB in lab-00-cluster-setup.md.

## Deviations
- None. Optimizations were cleaner than expected: 8.6 min vs ~20 min estimated (seq_len=256 faster).

## Cluster State
STILL RUNNING — rag-retriever active, smollm2-lora-train Job completed (pod cleaned up after ttlSecondsAfterFinished=600). Continue to Lab 03 (plan 02-06).
