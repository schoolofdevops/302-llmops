---
gsd_state_version: 1.0
milestone: v0.19.0
milestone_name: milestone
status: Ready to execute
stopped_at: Completed 03-agentops-labs-day-2/03-03-PLAN.md
last_updated: "2026-05-02T11:22:52.722Z"
progress:
  total_phases: 5
  completed_phases: 3
  total_plans: 20
  completed_plans: 16
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-12)

**Core value:** Teach practitioners how to take AI systems (LLMs + agents) from prototype to production on Kubernetes — the only course covering the full journey from RAG to agentic deployments with K8s Agent Sandbox.
**Current focus:** Phase 03 — agentops-labs-day-2

## Current Position

Phase: 03 (agentops-labs-day-2) — EXECUTING
Plan: 5 of 7

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**

- Last 5 plans: none yet
- Trend: -

*Updated after each plan completion*
| Phase 01-course-infrastructure P01 | 2min | 2 tasks | 32 files |
| Phase 01-course-infrastructure P02 | 16min | 2 tasks | 40 files |
| Phase 01-course-infrastructure P03 | 2min | 2 tasks | 5 files |
| Phase 01-course-infrastructure P04 | 4min | 2 tasks | 6 files |
| Phase 01-course-infrastructure P05 | 2min | 2 tasks | 3 files |
| Phase 02-llmops-labs-day-1 P01 | 1min | 2 tasks | 2 files |
| Phase 02-llmops-labs-day-1 P03 | 3min | 2 tasks | 10 files |
| Phase 02-llmops-labs-day-1 P02 | 6min | 2 tasks | 20 files |
| Phase 02-llmops-labs-day-1 P04 | 4min | 2 tasks | 10 files |
| Phase 02-llmops-labs-day-1 P06 | 2min | 2 tasks | 10 files |
| Phase 02-llmops-labs-day-1 P05 | 7min | 2 tasks | 13 files |
| Phase 02-llmops-labs-day-1 P07 | 8min | 2 tasks | 6 files |
| Phase 02.1-flatten-workspace-and-switch-to-uv P01 | 15min | 2 tasks | 3 files |
| Phase 03-agentops-labs-day-2 P01 | 4min | 3 tasks | 3 files |
| Phase 03-agentops-labs-day-2 P02 | ~6h | 3 tasks | 17 files |
| Phase 03-agentops-labs-day-2 P03 | 7min | 1 tasks | 1 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Pre-phase]: Agent framework = Hermes Agent (NousResearch) — configure and deploy, not build from scratch
- [Pre-phase]: Two-phase LLM — Labs 00-05 use local SmolLM2-135M, Labs 06+ use Gemini/Groq free-tier API
- [Pre-phase]: No LangGraph/CrewAI — Hermes is the modern approach
- [Pre-phase]: FAISS in-process (zero overhead) over Qdrant/Milvus
- [Pre-phase]: Docusaurus replaces MkDocs; Chainlit for web UI
- [Phase 01-course-infrastructure]: D-02: lab-NN zero-padded two-digit naming (lab-00 through lab-13)
- [Phase 01-course-infrastructure]: D-10/D-12: Generic namespace names and no domain branding in infrastructure (llm-serving, llm-app, monitoring, argocd, argo-workflows)
- [Phase 01-course-infrastructure]: Redirect Docusaurus homepage to /docs instead of landing page — keeps learners on docs immediately
- [Phase 01-course-infrastructure]: Docusaurus Tabs pattern (groupId=operating-systems) established for all OS-specific commands in lab pages
- [Phase 01-course-infrastructure]: Preflight scripts: starter and solution identical (no REPLACE placeholders in scripts); memory warn 8-12GB not fail; TDD bash test suite with 14 tests
- [Phase 01-course-infrastructure]: Dual ImageVolume gate pattern (kubeadmConfigPatches + KubeletConfiguration) required for KIND cluster — single location silently fails
- [Phase 01-course-infrastructure]: bootstrap-kind.sh uses mktemp+sed substitution for REPLACE_HOST_PATH — preserves placeholder in tracked config
- [Phase 01-course-infrastructure]: Solution KIND config uses ./llmops-project relative path (not absolute) — works on macOS and Windows Git Bash from repo root
- [Phase 01-course-infrastructure]: cleanup-phase3.sh uses per-CRD kubectl delete lines for --ignore-not-found on each CRD individually
- [Phase 01-course-infrastructure]: helm status guard pattern before helm uninstall prevents script failure when release was never installed
- [Phase 02-llmops-labs-day-1]: Use official vllm/vllm-openai-cpu:v0.19.0-x86_64 image — abandoned schoolofdevops/vllm-cpu-nonuma:0.9.1 removed
- [Phase 02-llmops-labs-day-1]: KServe marked N/A for Phase 2 labs — plain K8s Deployment used per D-10
- [Phase 02-llmops-labs-day-1]: MAX_STEPS=50 enforced in both train_lora.py default and K8s Job YAML — prevents accidental long CPU runs (Pitfall 4)
- [Phase 02-llmops-labs-day-1]: PEFT 0.19.0 stable params: r, lora_alpha, target_modules, lora_dropout, bias, task_type — avoids deprecated 0.12 patterns
- [Phase 02-llmops-labs-day-1]: torch.float32 for CPU training (not bfloat16) — CPU stability for workshop laptops
- [Phase 02-llmops-labs-day-1]: FAISS IndexFlatIP(384) with normalize_embeddings=True — inner product equals cosine on L2-normalised vectors
- [Phase 02-llmops-labs-day-1]: K8s initContainer builds FAISS index before retriever container starts — avoids 30s+ startup delay in serving container
- [Phase 02-llmops-labs-day-1]: VLLM_CPU_KVCACHE_SPACE=2 (not 4) for OOM protection on 5Gi KIND nodes; ImageVolume mounts model OCI image at /models; readinessProbe initialDelaySeconds=120 for 60-180s CPU model load time
- [Phase 02-llmops-labs-day-1]: vLLM v0.19.x uses colon prefix vllm: in all metric names — PromQL must use vllm:time_to_first_token_seconds not vllm_request_ttft_seconds
- [Phase 02-llmops-labs-day-1]: serviceMonitorSelectorNilUsesHelmValues=false required for cross-namespace ServiceMonitor discovery in kube-prometheus-stack
- [Phase 02-llmops-labs-day-1]: Grafana auto-discovery via grafana_dashboard: '1' ConfigMap label — no manual dashboard import needed
- [Phase 02-llmops-labs-day-1]: Chainlit streaming message created before cl.Step context to stream tokens to main chat thread, not step output
- [Phase 02-llmops-labs-day-1]: Pitfall 5 enforced: --host 0.0.0.0 in Chainlit CMD is mandatory for NodePort WebSocket (without it: 403)
- [Phase 02-llmops-labs-day-1]: Lab guides read actual solution code before writing — ensures accurate file paths and commands
- [Phase 02.1]: uv pip install --system for student-facing commands — avoids venv requirement in workshop context
- [Phase 02.1]: Flat workspace pattern: all student files go directly into llmops-project/ — no per-lab sub-directories
- [Phase 02.1]: K8s initContainer pip unchanged — uv not available inside pod images
- [Phase 03-agentops-labs-day-2]: filelock >=3.13.0 pinned as W4 Windows-compatibility requirement for book_appointment MCP tool local-JSON mode
- [Phase 03-agentops-labs-day-2]: Groq llama-3.3-70b-versatile is default LLM_MODEL in config.env; Gemini is alternative (student-toggled)
- [Phase 03-agentops-labs-day-2]: kindnet does NOT enforce NetworkPolicy (documented in COURSE_VERSIONS.md Notes for Lab 08 planner)
- [Phase 03-agentops-labs-day-2]: TransportSecuritySettings(enable_dns_rebinding_protection=False) required for FastMCP servers in Docker where Host header is a service name
- [Phase 03-agentops-labs-day-2]: Hermes v0.12.0: CPU-only startup confirmed with 'hermes gateway' (not 'hermes gateway run'); /health responds in ~6s; closes RESEARCH.md Q2+Q3
- [Phase 03-agentops-labs-day-2]: B1 Gemini live path verified: Gemini 2.5 Flash via OpenAI-compat endpoint exercises all 3 MCP tools; config.yaml default kept as groq/llama-3.3-70b-versatile for students without GOOGLE_API_KEY
- [Phase 03-agentops-labs-day-2]: HTML comments (<!-- -->) replaced with MDX JSX comments ({/* */}) for Docusaurus MDX parser compatibility
- [Phase 03-agentops-labs-day-2]: OS Tabs dropped from Lab 07 Part F — docker compose commands identical on macOS and Windows Git Bash

### Pending Todos

None yet.

### Roadmap Evolution

- Phase 02.1 inserted after Phase 2: Flatten workspace and switch to uv (URGENT)

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-05-02T11:22:52.719Z
Stopped at: Completed 03-agentops-labs-day-2/03-03-PLAN.md
Resume file: None
