---
plan: 02-07
phase: 02-modernize-llmops-spine-labs-00-05
status: complete
completed: 2026-06-15
---

# Plan 02-07 Summary — Lab 04: vLLM Serving + Chainlit UI

## What Was Built

- vLLM Deployment (llm-serving) serving smollm2-135m-finetuned via OCI ImageVolume from Lab 03
- Chainlit UI Deployment (llm-app) connecting to rag-retriever + vLLM
- D-19 placeholder replaced with final Pattern-A teaser (three serving patterns)
- Lab 04 budget appended to PHASE-02-BUDGETS.md

## Evidence

### Pod status (full stack)
```
NAMESPACE    NAME                             READY   STATUS    AGE
llm-app      chainlit-ui-7799748bfb-xtvh9     1/1     Running   ~20m
llm-app      rag-retriever-55d69dc4d8-sh8p9   1/1     Running   ~1h
llm-serving  vllm-smollm2-745d49cbf9-46hvv    1/1     Running   ~15m
```

### vLLM /health
```
{"status": "ok"}  (HTTP 200 on localhost:30200)
```

### vLLM /v1/chat/completions response
```json
choices[0].message.content: 237 chars (dental cleaning cost response)
```

### Chainlit /metrics (D-13 verified)
```
# HELP chat_requests_total Total chat messages processed
# TYPE chat_requests_total counter
# HELP chat_latency_seconds End-to-end chat response latency
# TYPE chat_latency_seconds histogram
process_cpu_seconds_total ...  (default process metrics present)
```

### Chainlit metrics endpoint
```
chainlit-ui Service: ports [http:8000/30300, metrics:9090] (ClusterIP-only for metrics)
Endpoint port: 9090 (confirmed via endpoint slice)
```

## vLLM Loading Timeline
- Image pull: schoolofdevops/vllm-cpu-nonuma:0.9.1 (1.5 GB) → 6m39s
- Model load: SmolLM2-135M-Instruct from /models/model (ImageVolume) → ~2 min
- Total time to Available: ~9 min

## Memory Budget (Lab 04 peak)
- worker: 4.082 GiB (vLLM pod)
- control-plane: 737 MiB
- worker2: 544 MiB (retriever + chainlit)
- kind-registry: 30 MiB
- Total: ~5.4 GB / 9.705 GB → headroom ~4.3 GB for Lab 05

## Human Checkpoint
This plan has a human-verify checkpoint (Task 4: browser chat) that will be completed when the user opens the browser. The automated verifications are all complete.

## Cluster State
STILL RUNNING — vllm-smollm2 + chainlit-ui + rag-retriever all running. Continue to Lab 05 (plan 02-08).
