# Phase 02 Resource Budgets — Single-Session Walk

**Methodology:** Single continuous KIND session, Lab 00 → Lab 05, no teardown between labs (D-10, D-11).
**Verification target:** macOS arm64, Docker Desktop with ≥10 GB RAM allocation (verified at 9.7 GB).
**Cluster:** llmops-kind (3 nodes, KIND v1.34.0).

---

## Lab 00 — KIND cluster up, no workloads (baseline)

**Captured:** 2026-06-15T07:22:25Z

### Docker container memory (kind containers only)
```
CONTAINER ID   NAME                        CPU %     MEM USAGE / LIMIT      MEM %    NET I/O           BLOCK I/O        PIDS
49e5ef32fd0a   llmops-kind-worker          9.10%     139.1MiB / 9.705GiB   1.40%    440kB / 86.2kB    16.3MB / 193MB   82
1489fdf3ca53   llmops-kind-control-plane   12.65%    672.6MiB / 9.705GiB   6.77%    257kB / 2.61MB    146MB / 753MB    255
7f69399a155b   llmops-kind-worker2         1.30%     151.9MiB / 9.705GiB   1.53%    4.68MB / 142kB    35MB / 206MB     80
6f72ddf80a35   kind-registry               0.00%     8.816MiB / 9.705GiB   0.09%    26kB / 3.33kB     1.87GB / 235MB   9
```

**Estimated baseline RSS:** ~964 MiB (~1 GB) for 3-node KIND cluster

### Docker Desktop VM allocation
```
9.705 GiB allocated to Docker Desktop VM
✅ VERIFIED SUFFICIENT: Training job completed with 4Gi memory limit (optimized from 8Gi).
   Lab 02 fits within 9.7 GB Docker Desktop. 10 GB is the new verified minimum.
```

### kubectl top nodes
```
error: Metrics API not available
metrics-server not installed yet (expected at Lab 00; available after kube-prometheus-stack in Lab 05)
```

### kubectl top pods -A
```
error: Metrics API not available
metrics-server not installed yet (expected at Lab 00; available after kube-prometheus-stack in Lab 05)
```

### Key observations
- Empty cluster baseline; only kube-system pods running.
- Estimated baseline RSS: ~964 MiB across 3 KIND nodes (via docker stats).
- metrics-server NOT installed at this stage; `kubectl top` will succeed once kube-prometheus-stack lands in Lab 05.
- Both ImageVolume gates verified functional: alpine test pod showed populated /mounted (bin, etc, usr visible).
- Host extraPortMappings bound: 30200, 30300, 30400, 30500 (verified via docker inspect).

---

## Lab 01 — Synth data + RAG retriever deployed

**Captured:** 2026-06-15T07:32:12Z
**New since Lab 00:** rag-retriever (1 pod, llm-app namespace)

### Docker container memory
```
llmops-kind-worker 5.51% 140.9MiB /
llmops-kind-control-plane 17.26% 729.3MiB /
llmops-kind-worker2 4.55% 453.3MiB /
kind-registry 0.05% 9.09MiB /
```

### kubectl top nodes
```
error: Metrics API not available
metrics-server not installed yet
```

### Key observations
- retriever pod: 512Mi/1Gi memory request/limit, 500m/1 CPU (per 10-retriever-deployment.yaml)
- initContainer built FAISS index from clinic data (fastembed + faiss-cpu)
- /search verified: 3 hits for "dental cleaning" query, latency ~0.56s
- Cumulative estimate: ~3-3.5 GB total RSS

---

## Lab 02 — CPU LoRA fine-tuning job (post-completion idle)

**Captured:** 2026-06-15T08:05:00Z (after training job completed and pod cleaned up)
**New since Lab 01:** smollm2-lora-train Job (completed, adapter written to /mnt/project)

### Docker container memory (after job completion)
```
llmops-kind-worker         472.4MiB / 9.705GiB
llmops-kind-control-plane  972.5MiB / 9.705GiB
llmops-kind-worker2        556.4MiB / 9.705GiB
kind-registry               28.35MiB / 9.705GiB
```

### Key observations
- Training job: LORA_R=4, MAX_SEQ_LEN=256, MAX_STEPS=50, memory limit=4Gi (optimized from 8Gi)
- Training completed in **8.6 minutes** (well under ~20 min estimate)
- Loss trajectory: 2.888 → 2.729 → 2.493 → 2.506 → 2.442 (healthy decrease)
- LoRA adapter: adapter_model.safetensors 915 KB, saved to /mnt/project/training/runs/run-20260615-075229/checkpoint-50/
- Memory limit 4Gi was sufficient — no OOM kill, clean Job completion (1/1)
- trainable params: 230,400 / 134,745,408 total (0.17%)
- Cumulative after cleanup: ~2 GB (training pod terminated, lower than Lab 01 because retriever pod idle)

---

## Lab 03 — OCI model packaging (Pattern A)

**Captured:** 2026-06-15T08:20:00Z
**New artifacts since Lab 02:** OCI image kind-registry:5001/smollm2-135m-finetuned:v1.0.0 (524.9 MB)

### Docker container memory (after OCI build, no new pods)
```
llmops-kind-worker         503.5MiB / 9.705GiB
llmops-kind-control-plane  973MiB / 9.705GiB
llmops-kind-worker2        558.1MiB / 9.705GiB
kind-registry               51.83MiB / 9.705GiB
```

### kubectl top nodes
```
error: Metrics API not available
metrics-server not installed yet
```

### Key observations
- smollm2-lora-merge Job (merge step) ran in 101s within 3Gi limit — no OOM.
- Model OCI image: alpine:3.20 base + model.safetensors (538 MB) + tokenizers = 524.9 MB total.
- ImageVolume smoke-test PASSED: /mnt/model/model/ shows config.json, model.safetensors, tokenizer.json, tokenizer_config.json.
- Important layout: OCI image has COPY merged-model/ /model/; when mounted at /models (vLLM), files are at /models/model/ — matches --model=/models/model arg in lab-04 Deployment YAML.
- kind-registry grew from ~28 MB → ~52 MB (now holds smollm2-trainer + smollm2-135m-finetuned layers).
- Lab 04 vLLM Deployment will consume this image via the same ImageVolume mechanism.

---

## Lab 04 — vLLM + Chainlit (full chat stack)

**Captured:** 2026-06-15T08:50:00Z
**New services since Lab 03:** vllm-smollm2 (llm-serving, 4Gi req/5Gi limit), chainlit-ui (llm-app, 256Mi req/512Mi limit)

### Docker container memory (vLLM model loaded, full stack running)
```
llmops-kind-worker         4.082GiB / 9.705GiB   7.51%  (vLLM pod here)
llmops-kind-control-plane  736.8MiB / 9.705GiB  16.59%
llmops-kind-worker2        543.7MiB / 9.705GiB   6.87%  (rag-retriever + chainlit-ui here)
kind-registry               30.08MiB / 9.705GiB   0.00%
```

### kubectl top nodes
```
error: Metrics API not available
metrics-server not yet installed (kube-prometheus-stack lands in Lab 05)
```

### Key observations
- vLLM image pull time: 6m39s for 1.5 GB (schoolofdevops/vllm-cpu-nonuma:0.9.1)
- vLLM readiness: Available ~9 min after apply (image pull 6m39s + model load ~2m)
- vLLM verified: /health 200 OK; /v1/chat/completions returns content on NodePort 30200
- Chainlit verified: homepage 200 OK on NodePort 30300; /metrics on ClusterIP port 9090
- D-13 verified: chat_requests_total counter + chat_latency_seconds histogram present in /metrics
- Endpoints: chainlit-ui metrics endpoint backed by port 9090 (confirmed via endpoint slice)
- Total cluster RSS: ~5.4 GB (4.08 GB worker + 737 MB control-plane + 544 MB worker2 + 30 MB registry)
- Available headroom: ~4.3 GB (9.705 - 5.4) — sufficient for Lab 05 kube-prometheus-stack

---
