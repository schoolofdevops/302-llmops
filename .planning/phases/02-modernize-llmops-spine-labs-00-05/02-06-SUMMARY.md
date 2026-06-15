---
plan: 02-06
phase: 02-modernize-llmops-spine-labs-00-05
status: complete
completed: 2026-06-15
---

# Plan 02-06 Summary — Lab 03: OCI Model Packaging (Pattern A)

## What Was Built

- LoRA adapter merged into base model via smollm2-lora-merge Job (101s, 3Gi limit)
- Model OCI image built and pushed: kind-registry:5001/smollm2-135m-finetuned:v1.0.0 (524.9 MB)
- ImageVolume smoke-test verified: /mnt/model/model/ shows all model files
- D-18 placeholder in lab-03-model-packaging.md replaced with final Pattern-A teaser
- Lab 03 budget appended to PHASE-02-BUDGETS.md

## Evidence

### docker image ls
```
REPOSITORY                                  TAG       IMAGE ID       SIZE
kind-registry:5001/smollm2-135m-finetuned  v1.0.0    caea1738c0a8   550MB
```

### ImageVolume smoke-test output (model-image-test2)
```
total 528952
-rw-r--r--    chat_template.jinja          368 Jun 15 08:12
-rw-r--r--    config.json                  904 Jun 15 08:12
-rw-r--r--    generation_config.json       131 Jun 15 08:12
-rw-------    model.safetensors      538090408 Jun 15 08:12
-rw-r--r--    tokenizer.json           3522871 Jun 15 08:12
-rw-r--r--    tokenizer_config.json        383 Jun 15 08:12
```

### D-18 teaser (final wording, as committed)
```markdown
## What's Next: Two Model-Packaging Patterns

This lab built **Pattern A — OCI ImageVolume packaging**: the merged model is shipped as a container image
and mounted into the serving pod via Kubernetes ImageVolume. This is one of two model-packaging patterns
covered in the v1.0.0 LLMOps curriculum:

- **Pattern A — OCI ImageVolume** (this lab): Best for ≤2GB models with immutable promotion via image tag.
- **Pattern B — Disk-based loading via MinIO + initContainer** (covered in a later phase): Best for >2GB models.

The decision lab lands in the same later phase that introduces Pattern B.
```

## Key Findings

- ImageVolume mounts the entire OCI image filesystem. `COPY merged-model/ /model/` → files at `/models/model/` when mounted at `/models`. vLLM arg `--model=/models/model` matches this.
- merge_lora.py includes tokenizer_config.json fix (extra_special_tokens list → {}) required for transformers ≥4.50 / vLLM 0.9.1 compatibility.
- D-20 honored: no inline comparison table in lab-03 doc.

## Git Commits
- Lab 03 changes committed as part of docs(02-06) commit

## Cluster State
STILL RUNNING — rag-retriever active, merge/test pods cleaned up, model OCI image in kind-registry. Continue to Lab 04 (plan 02-07).
