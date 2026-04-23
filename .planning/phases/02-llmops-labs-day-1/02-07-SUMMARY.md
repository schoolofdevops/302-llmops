---
phase: 02-llmops-labs-day-1
plan: "07"
subsystem: course-content/docs/labs
tags: [docusaurus, lab-guides, rag, finetuning, vllm, chainlit, observability]
dependency_graph:
  requires:
    - 02-02 (synth data + RAG code in labs/lab-01/solution/)
    - 02-03 (fine-tuning code in labs/lab-02/solution/)
    - 02-05 (vLLM serving code in labs/lab-04/solution/)
    - 02-06 (Chainlit UI + observability code in labs/lab-05/ + lab-06/solution/)
  provides:
    - All 6 Day 1 Docusaurus lab guide pages with complete step-by-step instructions
  affects:
    - course-content/docs/labs/ (6 MDX lab pages)
    - Learner experience for Day 1 workshop
tech_stack:
  added: []
  patterns:
    - Docusaurus MDX with Tabs (groupId=operating-systems) for OS-specific commands
    - :::note and :::warning Docusaurus callout blocks for critical warnings
    - "After This Lab" table summarizing artifacts and downstream consumers
key_files:
  created: []
  modified:
    - course-content/docs/labs/lab-01-synthetic-data.md
    - course-content/docs/labs/lab-02-rag-retriever.md
    - course-content/docs/labs/lab-03-finetuning.md
    - course-content/docs/labs/lab-04-model-packaging.md
    - course-content/docs/labs/lab-05-model-serving.md
    - course-content/docs/labs/lab-06-web-ui.md
decisions:
  - All lab pages reference actual solution code files (synth_data.py, build_index.py, retriever.py, train_lora.py, merge_lora.py, Dockerfile.model-asset, 30-deploy-vllm.yaml, app.py) verified by reading the files before writing
  - vLLM image confirmed as schoolofdevops/vllm-cpu-nonuma:0.9.1 per critical_override
  - Lab 03 includes explicit 15-20 minute timing warning with instructor tip to continue slides
  - Lab 05 includes :::warning blocks for both VLLM_CPU_KVCACHE_SPACE=2 constraint and 2-3 min NotReady startup
  - Lab 06 Part B documents vllm: colon prefix (not underscore) for v0.19.x metrics
metrics:
  duration: "8min"
  completed: "2026-04-23T09:33:00Z"
  tasks_completed: 2
  files_modified: 6
---

# Phase 02 Plan 07: Lab Guides for Day 1 — Summary

**One-liner:** Six complete Docusaurus MDX lab guides covering the full Day 1 LLMOps pipeline — synthetic data, FAISS RAG, CPU LoRA fine-tuning, OCI model packaging, vLLM serving, and Chainlit glass-box UI with Prometheus/Grafana observability.

## What Was Built

All 6 Day 1 lab guide pages were written from placeholder content to complete, educational, runnable guides. Each page follows the established structure: Learning Objectives → concept explanation (WHY) → code walkthrough → numbered lab steps → verification commands → "After This Lab" artifact summary.

### Lab Pages

| Page | Lines | Key Content |
|------|-------|-------------|
| `lab-01-synthetic-data.md` | 227 | synth_data.py walkthrough, JSONL chat format explained, verification of 300+ examples |
| `lab-02-rag-retriever.md` | 253 | FAISS IndexFlatIP + normalize_embeddings explained, initContainer pattern, curl verification |
| `lab-03-finetuning.md` | 256 | LoRA 0.3% trainable params, 15-20 min CPU timing warning, merge_and_unload pattern |
| `lab-04-model-packaging.md` | 182 | alpine:3.20 strategy, no CMD/ENTRYPOINT data-only image, ImageVolume mount explained |
| `lab-05-model-serving.md` | 230 | VLLM_CPU_KVCACHE_SPACE=2 OOM warning, 2-3 min NotReady startup warning, test script |
| `lab-06-web-ui.md` | 293 | Chainlit Steps glass-box mode (Part A), kube-prometheus-stack (Part B), vllm: prefix fix |

## Decisions Made

1. Read all actual solution code files before writing any lab content — ensures commands and file paths are accurate (not generic)
2. lab-06 structured as "Part A / Part B" to cover both Chainlit and Observability under one lab number without splitting across two guide pages
3. Docusaurus :::warning callouts used for the three most critical pitfalls: KV cache OOM, startup timing, and vLLM metric prefix change
4. The note about the streaming message being created before `cl.Step` context is documented in lab-06 — this is a subtle Chainlit pattern that students may copy incorrectly

## Deviations from Plan

None — plan executed exactly as written. The lab-04 page initially lacked "Smile Dental" branding and was fixed inline before commit (Rule 1 auto-fix applied — acceptance criteria check caught it).

## Self-Check

Files exist:
- course-content/docs/labs/lab-01-synthetic-data.md: 227 lines
- course-content/docs/labs/lab-02-rag-retriever.md: 253 lines
- course-content/docs/labs/lab-03-finetuning.md: 256 lines
- course-content/docs/labs/lab-04-model-packaging.md: 182 lines
- course-content/docs/labs/lab-05-model-serving.md: 230 lines
- course-content/docs/labs/lab-06-web-ui.md: 293 lines

All >= 80 lines. No placeholder text remaining. All contain "Smile Dental" branding.

Commits:
- 892a619: feat(02-07): write lab-01 through lab-03 Docusaurus pages
- 69ae39c: feat(02-07): write lab-04 through lab-06 Docusaurus pages

## Self-Check: PASSED
