---
phase: 04-vllm-router-multi-pod-serving
status: pass
verified_at: "2026-06-16"
verifier: gsd-verifier (manual + automated)
---

# Phase 04 Verification — vLLM Router + Multi-Pod Serving

## Phase Goal

Deploy the vLLM Production Stack router with session-affinity routing and KEDA autoscaling, and produce a complete Lab 07 guide with teardown/restore of Pattern A.

## Goal Achievement

| Goal | Status | Evidence |
|------|--------|----------|
| vllm-stack Helm chart installs (router + 2 backends) | ✅ PASS | `helm status vllm-stack -n llm-serving` → STATUS=deployed rev 7 |
| Router NodePort 30201 accessible | ✅ PASS | `curl http://localhost:30201/health` → 200 OK |
| Session routing sticky per `x-user-id` | ✅ PASS | 3 requests with `dental-session-001` all routed to `10.244.1.8:8000` (router log confirmed) |
| KEDA ScaledObject triggers scale-up | ✅ PASS | HPA event: `New size: 3; reason: external metric s0-prometheus (above target)` |
| ServiceMonitor scrapes vLLM backends | ✅ PASS | Prometheus TSDB has `vllm:num_requests_waiting` from both backends |
| Lab 07 guide written | ✅ PASS | `course-content/docs/labs/lab-07-vllm-router.md` (14 sections) |
| sidebars.ts updated | ✅ PASS | `labs/lab-07-vllm-router` added after `labs/lab-06-disk-model-loading` |
| COURSE_VERSIONS.md updated | ✅ PASS | vllm-stack 0.1.11 + lmstack-router v0.1.11 rows added; Last verified → 2026-06-16 Phase 04 |
| Docusaurus build passes | ✅ PASS | `npm run build` exit 0, `Generated static files in "build"` |
| vllm-stack torn down | ✅ PASS | `helm uninstall vllm-stack -n llm-serving` → release "vllm-stack" uninstalled |
| Pattern A restored | ✅ PASS | `vllm-smollm2` scaled to 1 replica, 1/1 Running, `/v1/chat/completions` 200 OK |

## Deviations from Plan

| Plan Assumption | Actual | Resolution |
|----------------|--------|------------|
| `kind-config.yaml` hostPath `./llmops-project` | Resolved to `setup/llmops-project/` (empty dir) | Fixed to `../../../../../llmops-project` (commit e6b1fa1) |
| lmstack-router image natively pullable by KIND | amd64-only; KIND arm64 nodes can't pull | Pre-push to `kind-registry:5001` via Rosetta (ARM64 workaround) |
| `kind load docker-image` for router | Failed: `no space left on device` | Used local registry push instead |
| KEDA query `{model="smollm2"}` | Actual label: `model_name="smollm2-135m-finetuned"` | Fixed query in values |
| ServiceMonitor inside `modelSpec[0]` | Chart expects it at `servingEngineSpec` level | Moved to correct level |
| Default probe timeoutSeconds=1 works | amd64 under Rosetta is slow; exit-137 at ~50s | Added timeoutSeconds=10 + failureThreshold=6/12 to values |
| Prometheus WAL empty | Disk 100% full (23.75GB reclaimed via prune) | `docker system prune -af` before install |
| 3rd replica scales up and runs | Pending: resource constrained (8 CPU consumed by 2 backends × 4 CPU each) | Expected behavior; documented in lab guide |

## Artifacts Produced

- `course-code/labs/lab-07/solution/k8s/00-values-vllm-router.yaml` — final values file
- `course-code/labs/lab-07/starter/k8s/00-values-vllm-router.yaml` — starter with TODO blanks
- `course-content/docs/labs/lab-07-vllm-router.md` — lab guide (14 sections)
- `course-content/sidebars.ts` — Lab 07 entry added
- `course-code/COURSE_VERSIONS.md` — vllm-stack 0.1.11 + router v0.1.11 rows
- `.planning/phases/04-vllm-router-multi-pod-serving/04-01-SUMMARY.md`
- `.planning/phases/04-vllm-router-multi-pod-serving/04-02-SUMMARY.md`
- `.planning/phases/04-vllm-router-multi-pod-serving/04-03-SUMMARY.md`
- `.planning/phases/04-vllm-router-multi-pod-serving/04-04-SUMMARY.md`

## Verdict: PASS

Phase 04 goals fully achieved. All lab deliverables committed. Pattern A restored. Docusaurus build clean.
