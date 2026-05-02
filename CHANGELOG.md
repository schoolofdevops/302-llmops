# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v0.1.0] — 2026-05-02

First release. Labs 00–06 verified end-to-end on a KIND cluster (macOS, CPU-only, 16 GB RAM).

### Labs Included

| Lab | Title | Status |
|-----|-------|--------|
| Lab 00 | Cluster Setup (KIND + registry) | Verified |
| Lab 01 | Dataset Preparation (Smile Dental JSONL) | Verified |
| Lab 02 | RAG Retriever (FastAPI + FAISS + fastembed) | Verified |
| Lab 03 | CPU LoRA Fine-Tuning (SmolLM2-135M + PEFT) | Verified |
| Lab 04 | Model Packaging (OCI image via Kaniko) | Verified |
| Lab 05 | Model Serving (vLLM 0.9.1 CPU) | Verified |
| Lab 06 | Chainlit Web UI + Observability (Prometheus + Grafana) | Verified |

### Added

- Full end-to-end lab guide suite (`course-content/docs/labs/lab-00` through `lab-06`)
- Docusaurus site configuration replacing MkDocs
- Lab 00: complete cluster bootstrap with tool prerequisites, Docker memory warning, numbered steps, troubleshooting section
- Lab 02: switched from sentence-transformers to fastembed for lighter pod deployment
- Lab 05: vLLM 0.9.1 CPU serving with `schoolofdevops/vllm-cpu-nonuma:0.9.1`, `--dtype=float32`, OCI model volume mount
- Lab 06: Chainlit 2.11.0 glass-box UI with expandable pipeline steps (RAG retrieval, prompt construction, LLM generation)
- Lab 06: Prometheus metrics on separate port 9090 (workaround for Chainlit catch-all route)
- Lab 06: kube-prometheus-stack Helm install with ServiceMonitors for vLLM, RAG retriever, and Chainlit
- Lab 06: Grafana dashboard with 9 panels: TTFT (P50/P95), TPOT (P50/P95), E2E Latency, Token Throughput, Active & Queued (KEDA signal), KV Cache Utilization, RAG Retriever Rate, Chat Rate, Chat E2E Latency
- Lab 06: `generate-traffic-full.sh` — full pipeline traffic generator (RAG + vLLM, populates 7/9 panels)
- Lab 06: `generate-traffic.sh` — vLLM-only traffic generator for isolated load testing

### Fixed

- Repo URL throughout lab guides: `llmops-course.git` → `302-llmops.git`
- Lab 00: `mkdir -p llmops-project` moved after `git clone` (correct order)
- Lab 02: removed non-existent `tools/` directory reference; added explicit copy instructions
- Lab 03: optional inference test now activates venv and installs transformers before running
- Lab 05: vLLM replica count reduced from 3 to 2 to conserve memory on 16 GB laptops
- Lab 06: KV cache Grafana panel metric corrected — vLLM 0.9.1 exports `vllm:gpu_cache_usage_perc` even on CPU (no `vllm:cpu_cache_usage_perc` exists)
- Lab 06: Chainlit metrics port changed from 8000 (intercepted by catch-all route) to 9090 (standalone prometheus_client server)

### Known Limitations

- Labs 07–12 (KEDA autoscaling, GitOps, AgentOps, Kubernetes Agent Sandbox) not yet included in this release
- All workloads CPU-only; GPU path not tested
- Windows compatibility not verified in this release cycle
