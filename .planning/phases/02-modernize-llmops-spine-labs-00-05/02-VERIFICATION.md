---
phase: 02-modernize-llmops-spine-labs-00-05
status: complete
verified: 2026-06-15
target: macOS arm64
---

# Phase 02 Verification

**Phase:** 02-modernize-llmops-spine-labs-00-05
**Verification target:** macOS arm64 (Apple Silicon, Docker Desktop 9.705 GiB) — verified.
**Windows amd64:** attestation pending (see "Windows Attestation" section below).
**Walk completed:** 2026-06-15
**Methodology:** Single continuous KIND session, Lab 00 → Lab 05, no teardown between labs (D-10).
**Cluster:** llmops-kind (kindest/node:v1.34.0, 3 nodes: control-plane + worker + worker2)

---

## Truths Met (per Phase Goal)

1. ✅ **Lab 00** — KIND cluster up (3 nodes, v1.34.0); dual ImageVolume gates verified functional (alpine test pod showed populated /mounted with bin, etc, usr); NodePorts 30200/30300/30400/30500 bound on host (GAP-1 fix: added to kind-config.yaml extraPortMappings).

2. ✅ **Lab 01** — Synthetic dental data generated (30 FAQs per category × 4 categories); FAISS index built; rag-retriever FastAPI deployed; `/search` returns 3 hits for "dental cleaning" query at ~0.56s latency.

3. ✅ **Lab 02** — LoRA fine-tune Job Complete (1/1); SmolLM2-135M-Instruct trained with LORA_R=4, MAX_SEQ_LEN=256, MAX_STEPS=50; completed in 8.6 minutes within 4Gi memory limit; adapter_model.safetensors 915 KB; loss 2.888 → 2.442 (healthy decrease); merged-model artifact written to /mnt/project.

4. ✅ **Lab 03** — OCI model image `kind-registry:5001/smollm2-135m-finetuned:v1.0.0` (524.9 MB) built and pushed; ImageVolume smoke-test confirmed model.safetensors at /mnt/model/model/ (538 MB).

5. ✅ **Lab 04** — vLLM Deployment (llm-serving ns) + Chainlit UI Deployment (llm-app ns) running; vLLM /health 200 OK on NodePort 30200; Chainlit homepage 200 OK on NodePort 30300; chat E2E verified (dental cleaning cost response, 237 chars); Chainlit /metrics returns chat_requests_total + chat_latency_seconds (D-13 instrumentation verified).

6. ✅ **Lab 05** — kube-prometheus-stack 83.4.2 installed (Helm release `kps`, monitoring ns); all 3 ServiceMonitors scraping (vllm-smollm2:8000/metrics, rag-retriever:8001/metrics, chainlit-ui:9090/metrics); 257 vllm:* series in Prometheus (D-12 gate met); chat_requests_total in Prometheus (D-13 closure); Grafana 28 dashboards loaded including "Smile Dental — LLM Pipeline" custom dashboard.

---

## Key Links Exercised

| Link | From | To | Verification |
|------|------|----|-------------|
| Chat E2E | Chainlit UI (30300) | retriever → vLLM (30200) | Browser chat verified at 02-07 human checkpoint |
| ImageVolume → vLLM | smollm2-135m-finetuned:v1.0.0 OCI image | vLLM /models/model path | Lab 03 smoke-test + Lab 04 inference response |
| Prometheus → vLLM | ServiceMonitor (app=vllm) | :8000/metrics | up=1, 257 vllm:* series |
| Prometheus → Chainlit | ServiceMonitor (app=chainlit-ui, port=metrics) | :9090/metrics | up=1, chat_requests_total present (D-13 closure) |
| Prometheus → retriever | ServiceMonitor (app=rag-retriever) | :8001/metrics | up=1 |
| Grafana sidecar | ConfigMap (grafana_dashboard=1) | Dashboard panels | 28 dashboards loaded, "Smile Dental — LLM Pipeline" confirmed |
| Lab 02 → Lab 03 | merged-model artifact (/mnt/project) | OCI image COPY | Dockerfile.model-asset COPY merged-model/ /model/ |
| Lab 03 → Lab 04 | OCI image in kind-registry | vLLM ImageVolume | --model=/models/model matches mount layout |

---

## Resource Budget

See: [PHASE-02-BUDGETS.md](PHASE-02-BUDGETS.md)

| Metric | Value |
|--------|-------|
| Docker Desktop RAM | 9.705 GiB (10 GB allocated) |
| Lab 02 peak (training) | ~5 GB cluster RSS |
| Lab 05 final state (peak simultaneous) | ~6.45 GB cluster RSS |
| Headroom at Lab 05 end | ~3.25 GB |
| Verified minimum Docker Desktop | **10 GB** |

Phase 02 completed within a 10 GB Docker Desktop allocation — confirmed sufficient on macOS arm64.

---

## Windows Attestation (Pending — D-16)

Phase 02 was verified on **macOS arm64** (Apple Silicon). Windows x86-64 (amd64) follows the same Docker Desktop + KIND path documented in each lab guide, but has not been independently walked end-to-end.

**Deferred attestation plan:** A future Windows-host volunteer or instructor will replay the same single-session walk (Lab 00 → Lab 05) on Windows 11 Pro / Docker Desktop 4.x and append a `## Windows Attestation Confirmed` section to this file with:
- Docker Desktop version
- KIND version
- Per-lab pass/fail
- Any Windows-specific workarounds needed

Known Windows differences to verify:
- `kind-config.yaml` uses Linux paths — should work unchanged under Docker Desktop
- `bash` scripts require Git Bash or WSL2 on Windows
- NodePort binding via `extraPortMappings` should be identical behavior

---

## Out-of-Scope Reminders

These items were explicitly deferred during Phase 02 planning — do not re-introduce them in Phase 02 fixes:

| Item | Decision | Where deferred |
|------|----------|----------------|
| Distributed tracing (OTEL) | Deferred to v1.1 | GOVERN-03 |
| Cost-tracking middleware | Deferred to v1.1 | GOVERN-04 |
| macOS amd64 (Intel Mac) | DROPPED | D-15 |
| Inline Pattern A/B/C comparison tables | Deferred to decision labs (Phase 03/05) | D-20 |
| Windows attestation | Pending human volunteer | D-16 |

---

## Next Phase

**Phase 03 — Disk-Based Model Loading (MinIO + initContainer)** — Pattern B model packaging.

This same cluster can be reused (headroom ~3.25 GB). Recommended:
- Keep cluster if starting Phase 03 immediately
- Run `kind delete cluster --name llmops-kind` if taking a break or if Phase 03 needs more headroom

Phase 03 introduces MinIO object storage + initContainer pattern for models >2 GB, completing the model-packaging comparison (Pattern A vs. Pattern B) started in Lab 03.
