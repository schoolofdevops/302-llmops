---
plan: 02-08
phase: 02-modernize-llmops-spine-labs-00-05
status: complete
completed: 2026-06-15
---

# Plan 02-08 Summary — Lab 05: Observability (kube-prometheus-stack)

## What Was Built

- kube-prometheus-stack 83.4.2 installed via Helm (release `kps`, monitoring namespace)
- alertmanager.enabled=false (saves ~256 MiB)
- 3 ServiceMonitors applied: vllm-smollm2, rag-retriever, chainlit-ui
- Grafana dashboard ConfigMap (sidecar auto-discovery, grafana_dashboard=1 label)
- All 3 targets scraping successfully (up=1)
- Traffic generation script run: 30 dental queries sent to vLLM stack
- PHASE-02-BUDGETS.md: Lab 05 section + Cumulative Phase 02 summary appended
- 02-VERIFICATION.md created: full phase summary, truths met, Windows attestation pending

## Evidence

### Monitoring pods (all Running)
```
NAME                                                  READY   STATUS    AGE
kps-grafana-798f987877-pszp8                          3/3     Running   ~14m
kps-kube-prometheus-stack-operator-56c4776c9c-k6z5v   1/1     Running   ~14m
kps-kube-state-metrics-6b4cf78b4f-7z9bg               1/1     Running   ~14m
kps-prometheus-node-exporter-26nxp                    1/1     Running   ~14m
kps-prometheus-node-exporter-4w66r                    1/1     Running   ~14m
kps-prometheus-node-exporter-55msx                    1/1     Running   ~14m
prometheus-kps-kube-prometheus-stack-prometheus-0     2/2     Running   ~14m
```

### ServiceMonitor scrape targets (all UP)
```
vllm-smollm2  → 10.244.1.6:8000/metrics  — HEALTH=UP  (llm-serving ns)
rag-retriever → 10.244.2.3:8001/metrics  — HEALTH=UP  (llm-app ns)
chainlit-ui   → 10.244.2.4:9090/metrics  — HEALTH=UP  (llm-app ns)
```

### vllm:* metric count (D-12 gate)
```
count({__name__=~"vllm:.*"}) = 257
```

### ROADMAP SC#4 — four dashboard panel metrics (all success)
```
vllm:time_to_first_token_seconds_sum   status=success  series=1  ✓
vllm:e2e_request_latency_seconds_sum   status=success  series=1  ✓
vllm:num_requests_running              status=success  series=1  ✓
vllm:num_requests_waiting              status=success  series=1  ✓
```

### chat_requests_total (D-13 closure)
```
chat_requests_total series: 1  ✓
(OBS-03 carry-forward debt resolved)
```

### Grafana dashboard count
```
28 dashboards loaded (including "Smile Dental — LLM Pipeline" custom dashboard)
Grafana reachable: http://localhost:30400 → HTTP 302 (login redirect — normal)
```

## Lab 05 Memory Budget
```
llmops-kind-worker          3.887GiB / 9.705GiB   (vLLM + traffic)
llmops-kind-control-plane   1.142GiB / 9.705GiB   (monitoring stack + k8s)
llmops-kind-worker2         1.403GiB / 9.705GiB   (retriever + chainlit + node-exporter)
kind-registry               20.94MiB / 9.705GiB
Total: ~6.45 GB / 9.705 GB → headroom ~3.25 GB
```

## Cumulative Phase 02 (Single-Session Walk)

| Lab | Peak RSS | Headroom |
|-----|---------|---------|
| 00 baseline | ~964 MiB | ~8.7 GB |
| 04 (vLLM + Chainlit) | ~5.4 GB | ~4.3 GB |
| 05 (+ monitoring) | ~6.45 GB | ~3.25 GB |

**Verified minimum Docker Desktop: 10 GB** (9.705 GiB actual allocation — sufficient).

## Human Checkpoint (Task 3)

Task 3 requires human visual verification of Grafana dashboard panels showing live vllm:* metrics.

**How to verify:**
1. Open http://localhost:30400/ — login: admin / prom-operator
2. Navigate to "Smile Dental — LLM Pipeline" dashboard
3. Verify TTFT, e2e latency, request count, queued requests panels show data
4. Open http://localhost:30500/targets — confirm 3 scrape targets State=UP
5. Trigger a few chat requests at http://localhost:30300/ to see panels animate

**Cluster decision after verification:**
- Keep running → Phase 03 can reuse cluster (headroom ~3.25 GB is sufficient for MinIO)
- Tear down → `kind delete cluster --name llmops-kind`

## Phase 02 Completion

**Phase 02 is COMPLETE** — all 6 truths met, all ROADMAP success criteria verified on macOS arm64.

Artifacts committed:
- PHASE-02-BUDGETS.md (Lab 05 section + Cumulative Phase 02 summary)
- 02-VERIFICATION.md (truths met, key links exercised, Windows attestation pending)

## Cluster State
STILL RUNNING — full stack: vllm-smollm2 + chainlit-ui + rag-retriever + kube-prometheus-stack.
Continue to Phase 03 (disk-based model loading via MinIO + initContainer) or tear down cluster.
