---
phase: 02-llmops-labs-day-1
plan: "06"
subsystem: observability
tags: [prometheus, grafana, servicemonitor, vllm, kube-prometheus-stack, helm]
dependency_graph:
  requires: [02-04]
  provides: [lab-06-observability-code]
  affects: [monitoring-namespace, llm-serving-namespace, llm-app-namespace]
tech_stack:
  added: [kube-prometheus-stack 83.4.2, Prometheus ServiceMonitor CRD]
  patterns: [ServiceMonitor cross-namespace scraping, Grafana dashboard auto-discovery via ConfigMap label]
key_files:
  created:
    - course-code/labs/lab-06/solution/scripts/install-monitoring.sh
    - course-code/labs/lab-06/solution/k8s/observability/50-servicemonitor-vllm.yaml
    - course-code/labs/lab-06/solution/k8s/observability/50-servicemonitor-retriever.yaml
    - course-code/labs/lab-06/solution/k8s/observability/50-servicemonitor-chainlit.yaml
    - course-code/labs/lab-06/solution/k8s/observability/50-grafana-dashboard-cm.yaml
    - course-code/labs/lab-06/starter/scripts/install-monitoring.sh
    - course-code/labs/lab-06/starter/k8s/observability/50-servicemonitor-vllm.yaml
    - course-code/labs/lab-06/starter/k8s/observability/50-servicemonitor-retriever.yaml
    - course-code/labs/lab-06/starter/k8s/observability/50-servicemonitor-chainlit.yaml
    - course-code/labs/lab-06/starter/k8s/observability/50-grafana-dashboard-cm.yaml
  modified: []
decisions:
  - "vLLM v0.19.x uses colon prefix vllm: in metric names — all PromQL in dashboard uses colon prefix (not legacy underscore vllm_ from < 0.15)"
  - "Starter files identical to solution for observability — infrastructure-as-code is provided, not written by students"
  - "serviceMonitorSelectorNilUsesHelmValues=false is required for cross-namespace ServiceMonitor discovery"
  - "Grafana auto-discovery via grafana_dashboard: '1' label on ConfigMap — no manual import needed"
metrics:
  duration: 2min
  completed: 2026-04-23T09:22:24Z
  tasks: 2
  files: 10
---

# Phase 02 Plan 06: Lab 06 Observability (Prometheus + Grafana) Summary

**One-liner:** Prometheus + Grafana observability for vLLM v0.19.x using ServiceMonitors with colon-prefixed metric names and a 6-panel Grafana dashboard auto-discovered via ConfigMap label.

## What Was Built

Lab 06 provides complete Kubernetes observability infrastructure for the Smile Dental LLM pipeline:

1. **Helm install script** — `install-monitoring.sh` installs kube-prometheus-stack 83.4.2 with Grafana on NodePort 30400 and Prometheus on NodePort 30500. Sets `serviceMonitorSelectorNilUsesHelmValues=false` enabling cross-namespace ServiceMonitor scraping.

2. **Three ServiceMonitors** — Prometheus ServiceMonitor CRDs for:
   - vLLM in `llm-serving` namespace (selector: `app: vllm`)
   - RAG Retriever in `llm-app` namespace (selector: `app: rag-retriever`)
   - Chainlit UI in `llm-app` namespace (selector: `app: chainlit-ui`, placeholder pattern)
   All in `monitoring` namespace with `release: kps` label for kube-prometheus-stack discovery.

3. **Grafana dashboard ConfigMap** — Auto-discovered via `grafana_dashboard: "1"` label. Contains 6 panels using correct vLLM v0.19.x metric names with `vllm:` colon prefix:
   - Time to First Token P95: `histogram_quantile(0.95, rate(vllm:time_to_first_token_seconds_bucket[5m]))`
   - E2E Request Latency P95: `histogram_quantile(0.95, rate(vllm:e2e_request_latency_seconds_bucket[5m]))`
   - Token Throughput: `rate(vllm:generation_tokens_total[1m])`
   - Active & Queued Requests: `vllm:num_requests_running` + `vllm:num_requests_waiting`
   - KV Cache Utilization: `vllm:kv_cache_usage_perc`
   - RAG Retriever Query Rate: `rate(search_requests_total[1m])`

## Key Technical Decisions

| Decision | Rationale |
|----------|-----------|
| `vllm:` colon prefix in PromQL | vLLM v0.19.x changed metric naming convention — colon prefix is mandatory. Old `vllm_request_ttft_seconds` pattern silently returns no data |
| `serviceMonitorSelectorNilUsesHelmValues=false` | Without this flag, kube-prometheus-stack only discovers ServiceMonitors in the same namespace as the Helm release |
| `grafana_dashboard: "1"` label | Standard kube-prometheus-stack pattern for automatic Grafana dashboard provisioning — no manual JSON import needed |
| Starter = Solution for observability | Per D-08/D-09: ServiceMonitors and Helm scripts are infrastructure provided to students, not code they write from scratch |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all dashboard panels use real metric names from vLLM v0.19.x.

Note: The Chainlit ServiceMonitor (`50-servicemonitor-chainlit.yaml`) is documented as a placeholder pattern since Chainlit doesn't expose `/metrics` by default. This is intentional and documented with a comment in the file.

## Self-Check: PASSED

Files verified:
- course-code/labs/lab-06/solution/scripts/install-monitoring.sh: EXISTS
- course-code/labs/lab-06/solution/k8s/observability/50-servicemonitor-vllm.yaml: EXISTS
- course-code/labs/lab-06/solution/k8s/observability/50-servicemonitor-retriever.yaml: EXISTS
- course-code/labs/lab-06/solution/k8s/observability/50-servicemonitor-chainlit.yaml: EXISTS
- course-code/labs/lab-06/solution/k8s/observability/50-grafana-dashboard-cm.yaml: EXISTS
- course-code/labs/lab-06/starter/ mirror: EXISTS (all 5 files)

Commits verified:
- 9500b05: feat(02-06): add Lab 06 ServiceMonitors and Helm install script
- f2a4d2f: feat(02-06): add Grafana dashboard ConfigMap with vLLM v0.19.x metrics
