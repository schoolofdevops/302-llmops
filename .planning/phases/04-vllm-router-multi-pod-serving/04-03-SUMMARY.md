---
phase: 04-vllm-router-multi-pod-serving
plan: "03"
status: complete
completed_at: "2026-06-16"
commits:
  - 74b7469  # Finalized values (ServiceMonitor, KEDA query fix, probe timeouts)
wave: 2
---

# 04-03 Summary — Session Routing Demo + KEDA Scale Verification

## Task 1 Results: Session Routing + Metric Verification

### Session Routing Demo — CONFIRMED

3 sequential requests with `x-user-id: dental-session-001` all routed to same backend:

```
Routing request f3c89129 with session id dental-session-001 to http://10.244.1.8:8000
Routing request f8aa3aa1 with session id dental-session-001 to http://10.244.1.8:8000
Routing request 5c6f52f4 with session id dental-session-001 to http://10.244.1.8:8000
```

`dental-session-002` also routed consistently to `10.244.1.8:8000`. With 2 backends and low load, consistent hashing may map both session IDs to the same backend — this is correct behavior. Affinity within each session is guaranteed; cross-session diversity is probabilistic.

### vllm:num_requests_waiting — CONFIRMED

Metric present in backend `/metrics` endpoint:
```
# TYPE vllm:num_requests_waiting gauge
vllm:num_requests_waiting{model_name="smollm2-135m-finetuned"} 0.0
```

Prometheus scraping confirmed after enabling ServiceMonitor (`release: kps` label).

**Key discovery:** Actual label is `model_name` (not `model`). KEDA query was `{model="smollm2"}` → fixed to `{model_name="smollm2-135m-finetuned"}`.

### Prometheus Integration Issues Found + Fixed

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| Prometheus TSDB empty (all scrapes failing) | WAL disk full: `no space left on device` | `docker system prune -af` freed 23.75GB |
| ServiceMonitor not created | `serviceMonitor` was nested inside `modelSpec[0]` (wrong level) | Moved to `servingEngineSpec` level |
| KEDA query matched 0 series | Label filter `{model="smollm2"}` doesn't match; actual label is `model_name="smollm2-135m-finetuned"` | Fixed KEDA trigger query |

### Resource Budget

`kubectl top` unavailable (metrics-server not installed). Prometheus used instead.

- Disk freed: 23.75GB after Docker image prune
- Remaining disk: ~21GB free / 126GB total (84% used)
- Each vLLM backend: requests 4 CPU / 4Gi RAM
- Router: requests 400m CPU / 1000Mi RAM

## Task 2 Results: KEDA Scale-Up Demo

### Scale-Up — CONFIRMED

HPA event captured:
```
SuccessfulRescale: New size: 3; reason: external metric s0-prometheus
(above target)
```

Prometheus metric during burst: `sum(vllm:num_requests_waiting{model_name="smollm2-135m-finetuned"}) = 12` (threshold=5 → KEDA triggered scale).

### 3rd Pod Pending (Expected)

The 3rd replica remains Pending — resource-constrained KIND cluster:
- 2 worker nodes × ~4 CPU each = 8 CPU total
- 2 vLLM pods × 4 CPU each = 8 CPU consumed
- No headroom for 3rd pod requesting 4 CPU

This is expected in the lab environment. The HPA correctly scaled to 3; the Pending state is a capacity limit, not a KEDA/HPA bug. Lab guide should note this.

## Final Stack State

| Component | State |
|-----------|-------|
| Router | 1/1 Running, 0 restarts (probe timeouts fixed in values) |
| Backend A | 1/1 Running |
| Backend B | 1/1 Running |
| Backend C (scale-up) | 0/1 Pending (resource limit) |
| KEDA ScaledObject | READY=True, no Prometheus errors |
| ServiceMonitor | Active, both backends scraped |
| NodePort 30201 | `/health` 200 OK |

## Deviations from RESEARCH.md Assumptions

| Assumption | Status | Notes |
|-----------|--------|-------|
| A1: emptyDir initContainer works | ✅ CONFIRMED (CASE 1) | Completed in ~2min |
| A2: session routing per x-user-id | ✅ CONFIRMED | Log shows consistent IP per session |
| A3: KEDA scales on vllm:num_requests_waiting | ✅ CONFIRMED | HPA event logged |
| A4: kube-prometheus-stack scrapes vLLM | ✅ CONFIRMED after ServiceMonitor fix | Required `release: kps` label |
| A5: metric exported by CPU vLLM image | ✅ CONFIRMED | Label is `model_name` not `model` |

## Key Notes for Plan 04-04 (Lab Guide)

1. **ARM64 setup prerequisite**: `docker pull --platform linux/amd64 ... && docker tag ... localhost:5001/... && docker push localhost:5001/...` before `helm install`
2. **Disk space**: Docker prune recommended before install if disk >80%
3. **KEDA query label**: Use `model_name="smollm2-135m-finetuned"`, not `model`
4. **ServiceMonitor label**: Must include `release: kps` for kube-prometheus-stack
5. **3rd pod Pending**: Explain as expected behavior on resource-constrained KIND
6. **Probe timeouts**: `timeoutSeconds: 10` persisted in values (not `kubectl patch`)
7. **metrics-server**: Not installed; note `kubectl top` unavailable; add to prerequisites or document

## Ready for Plan 04-04
