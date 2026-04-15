# Phase 2: LLMOps Labs (Day 1) - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Build 6 labs (Lab 01-06) covering the complete LLMOps pipeline: synthetic data generation + RAG retriever, CPU LoRA fine-tuning, OCI model packaging, vLLM serving, Chainlit web UI with glass-box learning mode, and Prometheus/Grafana observability. Students end Day 1 with a running Smile Dental assistant accessible through a branded chat interface with visible LLM metrics.

</domain>

<decisions>
## Implementation Decisions

### Smile Dental Data
- **D-01:** Keep Indian context (INR, Pune) — just rename clinic from "Atharva" to "Smile Dental". No globalization needed.
- **D-02:** Richer dataset than current course: 10-15 treatments, 8-10 policies, 10+ FAQs, plus mock appointment slots and doctor schedules (for Phase 3 Hermes Agent).
- **D-03:** Include appointment data now so Phase 3 doesn't need to extend the dataset. Doctor names, availability windows, specializations.

### Chainlit UI Design
- **D-04:** Use Chainlit's built-in Step feature for glass-box mode — collapsible panels showing RAG context retrieved, LLM prompt sent, raw response, and timing per step. Native support, minimal custom code.
- **D-05:** Branded Smile Dental UI — logo, dental-themed colors, welcome message mentioning the clinic.
- **D-06:** UI-04 requirement (glass box) implemented via Chainlit Steps — students can expand each step to see internals.

### Lab Progression
- **D-07:** One lab per topic, 6 labs total for Day 1:
  - Lab 01: Synthetic data generation + FAISS RAG retriever
  - Lab 02: CPU LoRA fine-tuning (SmolLM2-135M)
  - Lab 03: OCI model packaging (ImageVolumes)
  - Lab 04: vLLM model serving
  - Lab 05: Chainlit web UI (glass-box learning mode)
  - Lab 06: Prometheus + Grafana observability
- **D-08:** Skeleton starters — starter/ has directory structure + empty placeholder files. Solution/ has full working code. Students follow lab guide which explains the code, then copy from solution/ or lab guide.
- **D-09:** Python application code (FastAPI services, training scripts) is PROVIDED in solution/. Lab guide explains the code so students understand. Students copy code from solution/ to their workspace. Focus is on LLMOps concepts, not writing Python from scratch.

### vLLM Configuration
- **D-10:** Plain K8s Deployment + Service for vLLM serving — no KServe. Keeps it simpler, reduces complexity and resource overhead.
- **D-11:** vLLM 0.19.0 (upgrade from 0.9.1). Needs CPU compatibility verification during execution. Use official `vllm/vllm-openai-cpu` image if available, fall back to custom build if needed.
- **D-12:** vLLM Router noted as potential addition but NOT mandatory for v1. If it simplifies the serving story vs KServe, consider it. Otherwise skip.

### Carrying Forward from Phase 1
- FAISS for vector store (zero overhead, in-process)
- SmolLM2-135M-Instruct as base model
- config.env has CLUSTER_NAME, namespaces, model references
- Docusaurus tabs for OS-specific commands
- Generic namespaces: llm-serving, llm-app, monitoring
- Solution KIND config uses ./llmops-project relative path

### Claude's Discretion
- Exact Chainlit theme colors and logo design
- FAISS index parameters (dimension, metric)
- LoRA hyperparameters (rank, alpha, learning rate)
- Prometheus ServiceMonitor vs PodMonitor choice
- Grafana dashboard layout and panel arrangement
- vLLM CPU-specific flags (kv-cache, max-model-len, OMP threads)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Course (Reference for Rewrite)
- `llmops-labuide/docs/lab01.md` — Existing RAG lab (data generation, FAISS index, retriever API). Rewrite source.
- `llmops-labuide/docs/lab02.md` — Existing fine-tuning lab (LoRA, SmolLM2-135M, merge). Rewrite source.
- `llmops-labuide/docs/lab03.md` — Existing OCI packaging lab. Rewrite source.
- `llmops-labuide/docs/lab04.md` — Existing vLLM serving lab (KServe RawDeployment, Chat API). Reference for vLLM config but switching to plain Deployment.
- `llmops-labuide/docs/lab05.md` — Existing observability lab (Prometheus, Grafana, ServiceMonitors). Rewrite source.

### Phase 1 Artifacts
- `course-code/config.env` — Central config with model names, namespaces, cluster settings
- `course-code/COURSE_VERSIONS.md` — Pinned dependency versions
- `course-code/labs/lab-00/solution/setup/kind-config.yaml` — Working KIND config (ImageVolume gates)
- `course-code/shared/k8s/namespaces.yaml` — 5 namespaces

### Research
- `.planning/research/STACK.md` — vLLM 0.19.0, Chainlit 2.11.0, DeepEval, recommended versions
- `.planning/research/PITFALLS.md` — vLLM CPU KV cache OOM, ImageVolume silent failure, Docker Desktop memory

### Project Context
- `.planning/PROJECT.md` — Key decisions: two-phase LLM strategy, Hermes Agent, FAISS, Chainlit
- `.planning/REQUIREMENTS.md` — RAG-01-04, TUNE-01-03, PKG-01-02, SERVE-01-03, UI-01-04, OBS-01-04

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `course-code/config.env` — Already has VLLM_IMAGE, BASE_MODEL, EMBEDDING_MODEL, namespace keys
- `course-code/labs/lab-00/solution/scripts/bootstrap-kind.sh` — Working KIND bootstrap (reference for lab scripts)
- `llmops-labuide/docs/lab01.md` lines 69-188 — Existing synthetic data (treatments.json, policies, FAQ). Rename Atharva→Smile, expand to richer dataset.
- `llmops-labuide/docs/lab02.md` lines 50-100 — Existing training Dockerfile and LoRA config. Update versions.
- `llmops-labuide/docs/lab04.md` lines 60-100 — Existing vLLM KServe config. Replace KServe with plain Deployment.

### Established Patterns
- Starter/solution directory structure per lab (Phase 1)
- Docusaurus tabs for OS-specific commands (Phase 1)
- Bash scripts with `set -euo pipefail` (Phase 1)
- Config sourced from config.env for consistent values

### Integration Points
- Lab 01 output (FAISS index, retriever API) → consumed by Lab 04 (vLLM serving needs retriever) and Lab 05 (web UI connects to retriever)
- Lab 02 output (merged model) → consumed by Lab 03 (OCI packaging)
- Lab 03 output (OCI image) → consumed by Lab 04 (vLLM mounts it via ImageVolume)
- Lab 04 output (running vLLM endpoint) → consumed by Lab 05 (Chainlit connects to it)
- Lab 06 (observability) scrapes all services from Labs 01, 04, 05

</code_context>

<specifics>
## Specific Ideas

- Python app code should be PROVIDED (not written by students). Lab guides explain the code, students understand it, then copy from solution/. Focus is on LLMOps operations, not Python development.
- Chainlit Steps for glass-box mode — each step (retrieval, prompt construction, LLM call, response parsing) visible as collapsible panels
- Smile Dental branding in UI (logo, colors, welcome message) but generic naming in infrastructure
- Appointment data included now for Phase 3 Hermes Agent use — doctor schedules, availability windows, specializations
- vLLM Router is a stretch goal, not mandatory

</specifics>

<deferred>
## Deferred Ideas

- vLLM Router as alternative to KServe — evaluate if needed, but not in v1 scope
- Agent-specific tools in the dataset (appointment booking logic) — data is included but tool implementation is Phase 3

</deferred>

---

*Phase: 02-llmops-labs-day-1*
*Context gathered: 2026-04-15*
