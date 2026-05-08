# Phase 02: Modernize LLMOps Spine (Labs 00-05) - Context

**Gathered:** 2026-05-08
**Status:** Ready for planning
**Approach:** Carry-forward + re-verify v0.19.0 LLMOps spine (Labs 01-06) on post-migration cluster, with two structural merges (synth+rag → Lab 01; vLLM+Chainlit → Lab 04), Phase-01 orphan cleanup, single-session 16GB-budget verification on macOS arm64, freeze on v0.19.0 dependency pins, and a small carry-forward debt fix (Chainlit `/metrics`).

<domain>
## Phase Boundary

Deliver six end-to-end-verified LLMOps labs (00-05) on a single post-migration KIND cluster:
- **Lab 00:** Cluster setup (KIND v1.34.0 + ImageVolume gates)
- **Lab 01:** Synthetic data + FAISS RAG retriever (merged from v0.19.0 lab-01 + lab-02)
- **Lab 02:** CPU LoRA fine-tuning of SmolLM2-135M (was v0.19.0 lab-03)
- **Lab 03:** OCI ImageVolume packaging — framed as "Pattern A" packaging (was v0.19.0 lab-04)
- **Lab 04:** Plain vLLM Deployment + Chainlit web UI — framed as "Pattern A" serving (merged from v0.19.0 lab-05 + lab-06)
- **Lab 05:** Prometheus + Grafana observability for vLLM + Chainlit (was v0.19.0 lab-06)

Students end Phase 02 with a running Smile Dental assistant: synthetic data → FAISS index → fine-tuned merged model → OCI image → plain vLLM Deployment + Chainlit UI at NodePort 30300, with live `vllm:` metrics on Grafana NodePort 30400.

**Out of scope for this phase:**
- New serving patterns (vLLM Router → Phase 04; KServe → Phase 05)
- Disk-based model loading (→ Phase 03)
- Decision/comparison labs for serving or packaging (→ Phase 03/05)
- Production ops layer — autoscaling, GitOps, training pipeline (→ Phase 06)
- Distributed tracing, full guardrails, cost middleware (→ v1.1 GOVERN)
- Dependency bumps beyond v0.19.0 pins (→ v1.1)

</domain>

<decisions>
## Implementation Decisions

### Lab structure (renumber + merge)
- **D-01:** Final lab count is **6** (00-05). Merge v0.19.0's 7 lab pages down to 6 by collapsing two pairs.
- **D-02:** Merge synthetic-data + RAG-retriever into a single Lab 01.
  - `course-code/labs/lab-01/` + `course-code/labs/lab-02/` consolidate into the new `course-code/labs/lab-01/`.
  - `course-content/docs/labs/lab-01-synthetic-data.md` + `lab-02-rag-retriever.md` consolidate into the new `course-content/docs/labs/lab-01-synthetic-data-and-rag.md` (filename can be tightened during planning).
  - The old `lab-02-*` page + `lab-02/` dir are deleted (NOT redirected — internal restructure within v1.0.0; v0.19.x branch + Phase 01 redirects already cover v0.19.0 URL holders).
- **D-03:** Merge plain-vLLM-serving + Chainlit-UI into a single Lab 04.
  - `course-code/labs/lab-05/` (vLLM serve) + `lab-06/` (Chainlit UI) consolidate into the new `course-code/labs/lab-04/`.
  - `course-content/docs/labs/lab-05-model-serving.md` + `lab-06-web-ui.md` consolidate into `course-content/docs/labs/lab-04-serving-and-ui.md` (final name TBD in planning).
  - Lab 04 ends with the full stack running (vLLM + Chainlit), readying Lab 05 to scrape it.
- **D-04:** Renumber `course-code/labs/` directories so dir number matches lab page number 1:1 after merges. Final layout:
  - `lab-00/` cluster, `lab-01/` synth+rag, `lab-02/` finetune, `lab-03/` packaging, `lab-04/` serve+ui, `lab-05/` observability.
  - v0.19.x maintenance branch is the safety net for existing learners; main is free to renumber cleanly.

### Phase-01 orphan cleanup
- **D-05:** First task of Phase 02 plan is `rm -rf course-code/labs/lab-{07,09,12,13}` — empty leftover directories from Phase 01 deletion (none track files, none contain content). Single commit. No prerequisite for spine work.

### 2026 dependency policy (freeze, not bump)
- **D-06:** Freeze on v0.19.0 `COURSE_VERSIONS.md` pins for Phase 02. Re-verify they still install + run cleanly on the post-migration cluster. Do NOT chase 2026-05 latest versions in this phase. Bumps are deferred to v1.1.
  - PyTorch 2.4+ (CPU), Transformers 4.50+, PEFT 0.14+, Sentence-Transformers 3.x, NumPy 1.26.4, FAISS faiss-cpu latest, Chainlit 2.11.0, Docusaurus 3.10.0.
- **D-07:** Keep `schoolofdevops/vllm-cpu-nonuma:0.9.1` as the vLLM image. Purpose-built CPU image for mac/windows; intentionally not the upstream `vllm/vllm-openai-cpu`. (Memory: user explicitly chose to keep this — confirmed via `auto memory` and v0.19.0 verification gap resolution.)
- **D-08:** Pin `kube-prometheus-stack` Helm chart to **83.4.2** explicitly in `COURSE_VERSIONS.md` (currently says "latest Helm chart"). Reproducibility for workshop delivery; matches v0.19.0 working version.
- **D-09:** Trim `COURSE_VERSIONS.md` Day 2 section in Phase 02:
  - **Strip:** Hermes Agent + Sandbox + MCP SDK + OTEL/Tempo + Groq/Gemini rows + agent notes (these moved to 303-agentops).
  - **Keep:** Day 3 ops rows (KEDA, ArgoCD, Argo Workflows) — they're owned by Phase 06 and stay in 302-llmops.
  - **Remove:** DeepEval row (eval moved to 303-agentops per ROADMAP).
  - Update "Last verified" timestamp + "Workshop delivery" version when applying.

### Verification methodology
- **D-10:** Single continuous KIND session walks Lab 00 → Lab 05 sequentially without teardown between labs (matches ROADMAP success criterion 5 literally). After each lab, capture `kubectl top pods -A`, `kubectl top nodes`, and Docker Desktop memory reading. This validates the cumulative 16GB-RAM budget claim, not just per-lab footprint.
- **D-11:** Resource-budget evidence is durable: written to `.planning/phases/02-modernize-llmops-spine-labs-00-05/PHASE-02-BUDGETS.md` with one section per lab. Becomes input for v1.1 GPU sizing decisions and the final serving-decision lab in Phase 05.
- **D-12:** Verification is gated on the budget file being populated AND `vllm:` metrics being live on Grafana, not just on artifacts existing. Hollow ServiceMonitors don't count (Pitfall: see D-13).

### Carry-forward debt fix (Chainlit /metrics)
- **D-13:** Fix v0.19.0 OBS-03 gap in the new merged Lab 04. Specifically:
  - Add `prometheus-client` to the merged `course-code/labs/lab-04/solution/ui/requirements.txt`.
  - Instrument `app.py` with a request counter + latency histogram exposed via `make_asgi_app()` mounted on the Chainlit FastAPI sub-app (or starlette middleware route at `/metrics`).
  - Remove the `placeholder` self-description from the Chainlit ServiceMonitor (now under `course-code/labs/lab-05/solution/k8s/observability/`).
  - Verify with a `curl http://chainlit-svc/metrics` step in Lab 05 verification.
  - Scope cap: ~30 lines. Do NOT introduce OTEL or distributed tracing here — that's v1.1 GOVERN-03.

### Cross-platform verification scope
- **D-14:** Phase 02 verification runs on user's primary machine (macOS arm64 / Apple Silicon). Docusaurus Tabs continue to provide macOS + Windows command variants (existing pattern from Phase 1).
- **D-15:** Drop Intel-mac (macOS amd64) from supported platform claim. Update both ROADMAP success criterion 1 and PROJECT.md "Constraints" section. Rationale: Intel macs out of mainstream sale since 2023; verification cost not justified by audience size.
- **D-16:** ROADMAP success criterion 1 is amended at planning time to read: "Lab 00 brings up a KIND cluster on KIND 1.34 + Docker Desktop on macOS arm64 (verified) and Windows amd64 (attestation pending) with ImageVolume feature gate enabled and dual ImageVolume gates verified". Windows verification is acknowledged as outstanding in `02-VERIFICATION.md` rather than blocking phase completion.
- **D-17:** Update `course-code/COURSE_VERSIONS.md` opening sentence: "All versions verified on macOS Apple Silicon and x86-64 Windows" → "All versions verified on macOS Apple Silicon; Windows x86-64 verification follows the same Docker Desktop + KIND path documented per-lab".

### Pattern-A framing (forward refs to Phases 03/04/05)
- **D-18:** Add a brief teaser at the end of Lab 03 (OCI packaging): "This is one of two model-packaging patterns. Pattern B (disk-based loading via MinIO + initContainer) is covered in Phase 03 / Lab 06 of the upcoming module. The decision lab comparing both lands there."
- **D-19:** Add a brief teaser at the end of Lab 04 (plain vLLM + Chainlit): "This is one of three serving patterns. Pattern B (vLLM Router multi-pod) is in Phase 04 / Lab 07. Pattern C (KServe InferenceService) is in Phase 05 / Lab 08. The serving-decision lab comparing all three lands at the end of Phase 05."
- **D-20:** Do NOT inline the comparison tables now. The Patterns B + C content does not exist yet; the decision labs in Phase 03 PACKAGE-03 and Phase 05 SERVE-04 own the comparisons.

### Claude's Discretion
- Final filenames for the two merged lab pages (`lab-01-synthetic-data-and-rag.md` vs `lab-01-rag-and-data.md` etc.; `lab-04-serving-and-ui.md` vs `lab-04-serve-and-chat.md` etc.).
- Exact prometheus-client metric names + label cardinality on Chainlit instrumentation. Stick with low-cardinality (request_total, request_duration_seconds) — no per-user labels.
- Whether the Chainlit `/metrics` endpoint mounts on the Chainlit ASGI app directly or on a separate uvicorn sub-route.
- Layout/order of the two consolidated lab pages (does merged Lab 01 lead with synthetic-data section then RAG, or interleave?).
- Exact `kubectl top` capture cadence within each lab (after deploy, after first request, at lab end).
- Per-lab teardown commands inside the single-session run (kept minimal — just delete throwaway test pods, NOT the lab's deployments).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project + roadmap
- `.planning/PROJECT.md` — overall milestone vision; Key Decisions table (entries dated 2026-05-07).
- `.planning/REQUIREMENTS.md` — SPINE-01..06 + SERVE-01 alias + PACKAGE-01 alias rows + Out of Scope list.
- `.planning/ROADMAP.md` §"Phase 02: Modernize LLMOps Spine (Labs 00-05)" — five success criteria + Notes for Plan-Phase (live-cluster gates).

### Prior context (v0.19.0 carry-forward)
- `.planning/milestones/v0.19.0-phases/02-llmops-labs-day-1/02-CONTEXT.md` — D-01..D-12 from v0.19.0 (Smile Dental data, Chainlit Steps, plain Deployment, namespace conventions).
- `.planning/milestones/v0.19.0-phases/02-llmops-labs-day-1/02-VERIFICATION.md` — last passing verification of Labs 01-06 (2026-04-23). Confirms artifacts wired, flags OBS-03 (Chainlit /metrics) gap.
- `.planning/milestones/v0.19.0-phases/02-llmops-labs-day-1/02-RESEARCH.md` — v0.19.0 RESEARCH.md (vLLM CPU pitfalls, Chainlit Steps API, FAISS index params).
- `.planning/milestones/v0.19.0-phases/02-llmops-labs-day-1/02-0{1..7}-PLAN.md` + `*-SUMMARY.md` — original 7-lab plan, lab-by-lab task breakdown that maps onto the new 6-lab structure.
- `.planning/milestones/v0.19.0-phases/02.1-flatten-workspace-and-switch-to-uv/02.1-RESEARCH.md` — locks the flat `llmops-project/` workspace + `uv` primary installer (already applied to Labs 01-03 lab guides).

### Phase 01 outputs (what Phase 02 builds on)
- `course-code/config.env` — central config (CLUSTER_NAME, namespaces, MODEL_IMAGE_TAG, BASE_MODEL, EMBEDDING_MODEL).
- `course-code/COURSE_VERSIONS.md` — current pins; D-08 + D-09 edits applied here in Phase 02.
- `course-code/labs/lab-00/solution/setup/kind-config.yaml` — working KIND config (ImageVolume gates).
- `course-code/shared/k8s/namespaces.yaml` — generic namespaces (llm-serving, llm-app, monitoring).
- `course-content/docusaurus.config.ts` — site config; `onBrokenLinks: 'throw'` is on. Renames in this phase must keep it green.
- `course-content/sidebars.ts` — sidebar entries that need pruning when lab-02 + lab-06 pages disappear (D-02 + D-03).

### Codebase maps (Phase 02 reuse)
- `.planning/codebase/STACK.md` — current stack baseline.
- `.planning/codebase/STRUCTURE.md` — directory layout reference.
- `.planning/codebase/CONCERNS.md` — pre-existing concerns (hardcoded paths, placeholder tokens, Chainlit ServiceMonitor placeholder); D-13 closes one entry.

### Pitfalls + research (when planning)
- `.planning/research/PITFALLS.md` (if present) — vLLM CPU KV cache OOM, ImageVolume silent failure, Docker Desktop memory cap.
- ROADMAP §"Notes for Plan-Phase" — explicit live-cluster verification gate items: "exact resource budgets per lab on a real 16GB laptop via `kubectl top pods -A`" applies directly to Phase 02 (D-10, D-11).

### Live cluster artifacts touched in Phase 02
- `course-code/labs/lab-04/solution/ui/app.py` (post-D-13 instrumentation target).
- `course-code/labs/lab-04/solution/ui/requirements.txt` (post-D-13 prometheus-client addition).
- `course-code/labs/lab-05/solution/k8s/observability/50-servicemonitor-chainlit.yaml` (placeholder removal).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- v0.19.0 Phase 02 solution code in `course-code/labs/lab-{01..06}/solution/` — verified passing (2026-04-23). Carry forward minus the structural merges in D-02 + D-03 and the `/metrics` patch in D-13.
- `course-code/config.env` — already has `VLLM_IMAGE=schoolofdevops/vllm-cpu-nonuma:0.9.1` (D-07) + `BASE_MODEL`, `EMBEDDING_MODEL`, `NS_SERVING/APP/MONITORING`. No changes required for spine.
- `course-code/labs/lab-00/solution/scripts/bootstrap-kind.sh` — working KIND bootstrap with ImageVolume feature gate; reused as Phase 02 cluster-setup entry.
- `course-content/docs/labs/lab-{00..06}-*.md` — current 7 lab pages, target of D-02 + D-03 merges.

### Established Patterns
- Starter/solution dir structure per lab.
- Docusaurus `<Tabs>` for OS-specific commands (macOS / Windows command variants).
- Bash scripts with `set -euo pipefail`.
- Generic namespaces (`llm-serving`, `llm-app`, `monitoring`) sourced from `config.env`.
- Flat `llmops-project/` workspace mounted to `/mnt/project` inside KIND nodes.
- `uv` as primary installer in student-facing commands (`pip` documented as fallback).
- Phase-01 redirects pattern (`@docusaurus/plugin-client-redirects`) — internal renames here do NOT need redirects (D-02 note).

### Integration Points
- Lab 01 (RAG) output: FAISS index + retriever API → consumed by Lab 04 (vLLM serving stack reads retrieval) and Lab 05 (observability scrapes retriever metrics).
- Lab 02 (finetune) output: merged model artifact at `/mnt/project/training/merged-model/` → consumed by Lab 03 (OCI build).
- Lab 03 (OCI build) output: `kind-registry:5001/smollm2-135m-finetuned:v1.0.0` → consumed by Lab 04 (ImageVolume mount).
- Lab 04 output: vLLM NodePort 30200 + Chainlit NodePort 30300 → scraped by Lab 05 ServiceMonitors.
- Lab 05 output: kube-prometheus-stack with `vllm:` metrics on Grafana NodePort 30400 — closes the "running stack with observability" deliverable.
- v0.19.x maintenance branch + Phase 01 redirects sit upstream of all this; Phase 02 must not break either (Docusaurus build still passes `onBrokenLinks: 'throw'`).

</code_context>

<specifics>
## Specific Ideas

- **Single-session verification is load-bearing** — the 16GB cumulative budget is the hardest constraint of v1.0.0 and the actual reason multi-pattern serving phases (03, 04, 05) require teardown between phases. Phase 02 establishes the per-lab footprint baseline that informs every later phase's teardown decisions. PHASE-02-BUDGETS.md is reused by Phase 06 (production ops layer must validate against the same baseline).
- **D-13 closes a real gap** — the v0.19.0 verification flagged Chainlit `/metrics` as a HOLLOW link with concrete fix instructions (add prometheus-client, instrument app.py, mount `make_asgi_app()`). Don't expand scope to OTEL or tracing here.
- **Renumbering is safe under v0.19.x** — existing learners who pinned to the v0.19.0 tag or v0.19.x maintenance branch (Phase 01 deliverable) are unaffected. The new numbering is a v1.0.0-only change.
- **Don't chase upstream vLLM** — `schoolofdevops/vllm-cpu-nonuma:0.9.1` is a deliberate course-built image (not abandoned upstream package). User confirmed in v0.19.0 verification this is the intended image for mac/windows CPU inference. Memory record: `project_vllm_image.md`.
- **The two structural merges are about pedagogy, not just file layout** — Lab 01 telling the synthetic-data + RAG story end-to-end is the right learning shape (data → index → retriever in one lab). Lab 04 ending with the full chat-stack running matches the "you have a working assistant by end of Day 1" promise.

</specifics>

<deferred>
## Deferred Ideas

- **Distributed tracing (OTEL) for the inference path** — Chainlit → Retriever → vLLM. Belongs in v1.1 GOVERN-03.
- **Cost-tracking middleware** for self-hosted vLLM — pairs with API-02 build-vs-buy decision tree. v1.1 GOVERN-04.
- **Inference-layer guardrails** (PII redaction, toxicity filter, rate limiting) — v1.1 GOVERN-02. Distinct from agent guardrails (303-agentops).
- **Bumping PyTorch / Transformers / PEFT / Chainlit / Docusaurus to 2026-05 latest** — v1.1.
- **Bumping `schoolofdevops/vllm-cpu-nonuma`** off 0.9.1 — open-ended; would require fresh CPU image build + verification on mac arm64 + Windows. Out of scope.
- **Macos amd64 (Intel mac) verification** — explicitly dropped in D-15 (not deferred — removed from supported claim).
- **Per-lab independent teardown verification** — the alternative to D-10 single-session approach. Could re-add as a v1.0.x patch if cumulative-budget evidence is challenged.
- **Inline Pattern A vs B vs C comparison tables in Lab 03 / Lab 04** — D-20 keeps these in the decision labs (Phase 03 PACKAGE-03 + Phase 05 SERVE-04) where Patterns B + C actually exist.
- **Bumping Chainlit ServiceMonitor to scrape OTEL spans instead of prom metrics** — speculative; depends on v1.1 GOVERN-03 design.
- **Sidebar reorganization** beyond the two file removals (lab-02 + lab-06 page slots) — keep current structure.
- **Renaming `course-code/labs/lab-00/` to something domain-named** — leave as `lab-00` to keep dir parity with page numbers (D-04).

### Reviewed Todos (not folded)
None — no pending todos matched Phase 02 scope from `gsd-tools todo match-phase 02`.

</deferred>

---

*Phase: 02-modernize-llmops-spine-labs-00-05*
*Context gathered: 2026-05-08*
