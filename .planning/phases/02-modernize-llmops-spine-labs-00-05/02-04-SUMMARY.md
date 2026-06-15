---
plan: 02-04
phase: 02-modernize-llmops-spine-labs-00-05
status: complete
completed: 2026-06-15
---

# Plan 02-04 Summary — Lab 01: Synth Data + RAG Retriever

## What Was Built

- llmops-project/ workspace populated with lab-01 solution files
- synth_data.py regenerated 164 training examples → datasets/train/dental_chat.jsonl
- clinic-data + retriever-code ConfigMaps created in llm-app namespace
- rag-retriever Deployment + NodePort Service (31001) deployed and healthy
- initContainer built FAISS index from clinic JSON data inside the cluster
- /search verified returning relevant dental results

## Evidence

### Pod status
```
NAME                             READY   STATUS    RESTARTS   AGE
rag-retriever-55d69dc4d8-sh8p9   1/1     Running   0          3m
```

### /search sample response
```json
{
  "hits": [
    {"doc_id": "TX-CLEAN-01", "section": "treatments",
     "text": "Teeth Cleaning / Scaling... Cost: ₹800 to ₹2,000...",
     "score": 0.5985},
    {"doc_id": "TX-WHITE-01", ...},
    {"doc_id": "POL-02", ...}
  ],
  "latency_seconds": 0.5569
}
```

## Lab 01 Budget
- Docker stats after retriever: control-plane 729 MiB, worker2 453 MiB (retriever running there)
- Cumulative estimate: ~3-3.5 GB vs ~1 GB Lab 00 baseline
- metrics-server not yet installed

## Deviations
- ConfigMaps (clinic-data, retriever-code) not present as YAML files — created via kubectl imperative commands. Gap for course content: students need these commands documented in lab-01-synthetic-data-and-rag.md.
- Port-forward used on 8001 (deployment containerPort) not 8000 (plan assumed 8000).

## Git Commits
- `0f88923` — docs(02-04): append Lab 01 budget snapshot

## Cluster State
STILL RUNNING — rag-retriever pod active in llm-app. Continue to Lab 02 (plan 02-05).
