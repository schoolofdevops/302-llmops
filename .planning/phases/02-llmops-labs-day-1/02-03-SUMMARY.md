---
phase: 02-llmops-labs-day-1
plan: "03"
subsystem: training
tags: [peft, lora, transformers, pytorch, kubernetes, fine-tuning, smollm2]

# Dependency graph
requires:
  - phase: 02-llmops-labs-day-1
    provides: datasets/train/dental_chat.jsonl from Lab 01 data generation

provides:
  - "LoRA fine-tuning script (train_lora.py) for SmolLM2-135M-Instruct on CPU"
  - "LoRA adapter merge script (merge_lora.py) producing deployment-ready model"
  - "K8s batch Job YAML (20-job-train-lora.yaml) for running training in llm-app namespace"
  - "Dockerfile with python:3.11-slim + torch 2.11.0 CPU wheel"
  - "Starter skeletons with TODO comments for students"

affects:
  - 02-04-PLAN (Lab 03 OCI packaging reads merged-model/ output)
  - 02-05-PLAN (Lab 04 serving uses packaged model image)

# Tech tracking
tech-stack:
  added:
    - peft==0.19.0 (LoRA adapter training)
    - transformers==5.5.4 (model loading, Trainer, TrainingArguments)
    - accelerate==1.13.0 (distributed training backend for Trainer)
    - datasets==4.8.4 (HuggingFace Dataset wrapper)
    - torch==2.11.0 CPU wheel from download.pytorch.org/whl/cpu
  patterns:
    - "LoraConfig with r=8, lora_alpha=16, target_modules=[q_proj, v_proj] for SmolLM2-135M"
    - "no_cuda=True + use_cpu=True in TrainingArguments for CPU-only K8s nodes"
    - "torch_dtype=torch.float32 for CPU stability (not bfloat16)"
    - "JSONL messages format -> apply_chat_template() -> DataCollatorForSeq2Seq training"
    - "Timestamped run directories: OUTPUT_ROOT/run-{YYYYmmdd-HHMMSS}/"
    - "K8s Job with ttlSecondsAfterFinished: 600 for auto-cleanup after run"

key-files:
  created:
    - course-code/labs/lab-02/solution/training/train_lora.py
    - course-code/labs/lab-02/solution/training/merge_lora.py
    - course-code/labs/lab-02/solution/training/Dockerfile
    - course-code/labs/lab-02/solution/training/requirements.txt
    - course-code/labs/lab-02/solution/k8s/20-job-train-lora.yaml
    - course-code/labs/lab-02/starter/training/train_lora.py
    - course-code/labs/lab-02/starter/training/merge_lora.py
    - course-code/labs/lab-02/starter/training/Dockerfile
    - course-code/labs/lab-02/starter/training/requirements.txt
    - course-code/labs/lab-02/starter/k8s/20-job-train-lora.yaml
  modified: []

key-decisions:
  - "MAX_STEPS=50 default enforced in both train_lora.py and K8s Job YAML — completes in ~15 min on CPU (Pitfall 4)"
  - "PEFT 0.19.0 stable params used: r, lora_alpha, target_modules, lora_dropout, bias, task_type — no deprecated 0.12 params"
  - "Starter Dockerfile and K8s YAML identical to solution — students don't write infrastructure per D-09"
  - "PeftModel.merge_and_unload() produces a plain HuggingFace model directory compatible with Lab 03 OCI packaging"

patterns-established:
  - "Training: JSONL messages -> apply_chat_template -> Dataset.from_list -> DataCollatorForSeq2Seq -> Trainer"
  - "K8s Job pattern: batch/v1 Job with backoffLimit: 1, ttlSecondsAfterFinished: 600, hostPath /mnt/project"
  - "Starter files contain TODO stubs only; solution files contain complete implementation"

requirements-completed: [TUNE-01, TUNE-02, TUNE-03]

# Metrics
duration: 3min
completed: 2026-04-23
---

# Phase 02 Plan 03: Lab 02 CPU LoRA Fine-tuning Summary

**CPU LoRA fine-tuning of SmolLM2-135M-Instruct via PEFT 0.19.0 with K8s batch Job, max_steps=50 completing in ~15 minutes**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-23T09:07:14Z
- **Completed:** 2026-04-23T09:10:04Z
- **Tasks:** 2
- **Files created:** 10

## Accomplishments

- Created complete solution training scripts: train_lora.py (CPU LoRA, max_steps=50) and merge_lora.py (merge_and_unload for deployment)
- Created K8s batch Job YAML with correct namespace (llm-app), 4 CPU / 8Gi resource limits, and hostPath volume mount for /mnt/project
- Created starter skeleton files with TODO comments, giving students a structured starting point without implementation

## Task Commits

Each task was committed atomically:

1. **Task 1: Create LoRA training scripts (solution/)** - `ad5edb2` (feat)
2. **Task 2: Create K8s Job YAML + starter skeletons** - `1b8891c` (feat)

**Plan metadata:** (see final commit)

## Files Created/Modified

- `course-code/labs/lab-02/solution/training/train_lora.py` - CPU LoRA fine-tuning: JSONL dataset loading, LoraConfig(r=8, target_modules=[q_proj,v_proj]), Trainer with no_cuda=True
- `course-code/labs/lab-02/solution/training/merge_lora.py` - Adapter merge: PeftModel.from_pretrained + merge_and_unload() + save_pretrained
- `course-code/labs/lab-02/solution/training/Dockerfile` - python:3.11-slim, torch 2.11.0 CPU wheel, peft/transformers/accelerate/datasets
- `course-code/labs/lab-02/solution/training/requirements.txt` - transformers==5.5.4, peft==0.19.0, accelerate==1.13.0, datasets==4.8.4
- `course-code/labs/lab-02/solution/k8s/20-job-train-lora.yaml` - batch/v1 Job in llm-app ns, 4CPU/8Gi limits, hostPath /mnt/project, ttl=600
- `course-code/labs/lab-02/starter/training/train_lora.py` - Skeleton with env vars and TODO stubs
- `course-code/labs/lab-02/starter/training/merge_lora.py` - Skeleton with env vars and TODO stubs
- `course-code/labs/lab-02/starter/training/Dockerfile` - Identical to solution (infrastructure provided)
- `course-code/labs/lab-02/starter/training/requirements.txt` - Identical to solution
- `course-code/labs/lab-02/starter/k8s/20-job-train-lora.yaml` - Identical to solution (K8s manifests provided per D-09)

## Decisions Made

- MAX_STEPS=50 enforced in both train_lora.py env default AND K8s Job YAML value — prevents students accidentally running 500+ step jobs on CPU (Pitfall 4 from RESEARCH.md)
- PEFT 0.19.0 stable parameter set used (r, lora_alpha, target_modules, lora_dropout, bias, task_type) — avoids deprecated 0.12 patterns that break with newer PEFT
- Starter Dockerfile and YAML files are identical to solution per D-09 design decision (students copy infrastructure, not write it)
- torch.float32 selected for CPU training stability (bfloat16 can cause NaN/instability on some CPU builds)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. The plan verification command `grep "MAX_STEPS.*50"` fails on the K8s YAML because YAML places name and value on separate lines (standard YAML format). The actual value "50" is correctly set. This is a documentation artifact, not a code issue.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Lab 02 training code is complete: students can build the Docker image, push to kind-registry:5001, and run the K8s Job
- The merged-model/ output from merge_lora.py is the input for Lab 03 (OCI image packaging)
- Plan 02-04 can proceed immediately

---
*Phase: 02-llmops-labs-day-1*
*Completed: 2026-04-23*
