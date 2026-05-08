# Phase 02: Modernize LLMOps Spine (Labs 00-05) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 02-CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-08
**Phase:** 02-modernize-llmops-spine-labs-00-05
**Areas discussed:** Lab renumber+merge, Orphans cleanup, 2026 dep refresh, Verify methodology, Cross-platform scope, Chainlit /metrics, Pattern-A framing
**Mode:** discuss (interactive); user selected `all` 7 areas

---

## Lab renumber+merge

### Q1 — Synth+RAG merge

| Option | Description | Selected |
|--------|-------------|----------|
| Merge into one Lab 01 (Recommended) | Combine course-code/labs/lab-01/ + lab-02/ into single lab-01/; merge .md pages into lab-01-synthetic-data-and-rag.md; delete lab-02. Matches roadmap, cleaner dependency story. | ✓ |
| Keep split, renumber others | Keep 2 dirs but treat as parts (1a, 1b). Then total stays 7 — conflicts roadmap. Skip. | |
| Single page, two code dirs | Single .md page covers both, but keep separate code dirs lab-01 (synth) + lab-02 (rag) for clarity. Hybrid. | |

**User's choice:** Merge into one Lab 01 (Recommended)
**Notes:** Pedagogically sound — synthetic data → index → retriever told as one story.

### Q2 — Serve+UI merge

| Option | Description | Selected |
|--------|-------------|----------|
| Merge into Lab 04 (Recommended) | Combine course-code/labs/lab-05/ (vLLM serve) + lab-06/ (Chainlit) into lab-04/; merge pages; delete lab-05+06. Lab 04 ends with running stack (vLLM + Chainlit). Prom/Graf becomes Lab 05. | ✓ |
| Keep separate, renumber | Two pages but renumber lab-05 → lab-04 (serve), lab-06 → lab-05 (UI), lab-06=Prom/Graf. Total still 7 — conflicts roadmap. | |
| Page merge only | Single .md but keep code dirs lab-04 (serve) + lab-05 (UI). Hybrid. | |

**User's choice:** Merge into Lab 04 (Recommended)
**Notes:** End of Lab 04 = running Smile Dental assistant (the Day 1 promise).

### Q3 — Renumber dirs

| Option | Description | Selected |
|--------|-------------|----------|
| Renumber dirs to match (Recommended) | course-code/labs/ matches course-content/docs/labs/ 1:1. Lab 03 finetune → lab-02/, Lab 04 pkg → lab-03/, Lab 04 serve+ui → lab-04/, Lab 05 obs → lab-05/. Clean. v0.19.x branch protects existing learners. | ✓ |
| Keep existing dir numbers | Dir numbers != lab page numbers. Confusing for students. Avoid. | |
| Renumber only the merged pairs | Only rename the 2 merge targets; leave finetune+pkg dirs at 03/04. Still requires shifts. Messy. | |

**User's choice:** Renumber dirs to match (Recommended)
**Notes:** v0.19.x maintenance branch (from Phase 01) is the existing-learner safety net.

---

## Orphans cleanup

### Q1 — Cleanup approach

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 02 first task (Recommended) | Sweep `rm -rf course-code/labs/lab-{07,09,12,13}` as opening task of Phase 02 plan 02-00 (cluster setup). Single commit. No prereq for spine work. | ✓ |
| Pre-phase /gsd:quick | Split as separate tiny task before Phase 02 starts. Cleaner state-machine but extra ceremony for trivial cleanup. | |
| Defer | Empty dirs are harmless. Leave as-is. Risk: confuses students browsing course-code/labs/. | |

**User's choice:** Phase 02 first task (Recommended)
**Notes:** Verified at discuss-time: all four dirs empty (no tracked files, no contents). Trivial sweep.

---

## 2026 dep refresh

### Q1 — Bump-or-freeze policy

| Option | Description | Selected |
|--------|-------------|----------|
| Freeze on v0.19.0 pins (Recommended) | Keep current COURSE_VERSIONS.md pins (PyTorch 2.4+, Transformers 4.50+, PEFT 0.14+, Chainlit 2.11.0, kube-prometheus-stack 83.4.2). Verify they still install + work. Defer bumps to v1.1. Lowest-risk path. | ✓ |
| Bump to latest stable | Re-research each pin to 2026-05 latest (PyTorch 2.5+, Transformers 4.55+, PEFT 0.15+, Chainlit 2.12+). Higher carry-forward value but more verification surface. | |
| Selective bump | Bump only deps with known security/bug issues or breaking changes; keep rest. Per-pin decision in plan. | |

**User's choice:** Freeze on v0.19.0 pins (Recommended)
**Notes:** Phase 02 is verification-heavy already; deferring bumps to v1.1 keeps surface manageable.

### Q2 — Versions doc trim

| Option | Description | Selected |
|--------|-------------|----------|
| Strip Day 2 only (Recommended) | Remove Hermes/Sandbox/OTEL/Tempo/Groq/Gemini sections + agent notes. Keep Day 3 ops sections (KEDA/ArgoCD/Argo Workflows minus DeepEval) — they belong to Phase 06. Drop DeepEval row. Phase 02 task. | ✓ |
| Strip Day 2 AND Day 3 | Trim to Day 1 only now; re-add Day 3 components in Phase 06. Cleaner snapshot but defers re-research. | |
| Leave as-is | Don't touch versions doc in Phase 02; let later phases edit. Risk: stale agent rows confuse 302-llmops readers. | |

**User's choice:** Strip Day 2 only (Recommended)
**Notes:** Day 3 ops rows survive because Phase 06 owns them; DeepEval row drops because eval moved to 303-agentops.

### Q3 — kps pin policy

| Option | Description | Selected |
|--------|-------------|----------|
| Add explicit pin to versions doc (Recommended) | Pin kube-prometheus-stack=83.4.2 in COURSE_VERSIONS.md (currently says 'latest Helm chart'). Reproducibility for workshop delivery. Re-test on KIND in Phase 02 plan. | ✓ |
| Bump to 2026-05 latest | Research current chart version, pin newest. Risk: dashboard ConfigMap selector changes. | |
| Keep 'latest' floating | Workshop install grabs current latest. Risk: course breaks when chart bumps. | |

**User's choice:** Add explicit pin to versions doc (Recommended)
**Notes:** 83.4.2 is what passed v0.19.0 Phase 02 verification.

---

## Verify methodology

### Q1 — Single vs per-lab verification

| Option | Description | Selected |
|--------|-------------|----------|
| Single continuous session (Recommended) | One KIND cluster, walk Lab 00→Lab 05 sequentially without teardown between labs. Capture `kubectl top pods -A` after each lab. Matches roadmap success criterion literally. Verifies cumulative footprint stays under 16GB. | ✓ |
| Per-lab independent verify | Spin fresh KIND for each lab, teardown between. Exercises lab-00 setup more but ignores cumulative-budget question. | |
| Hybrid: cumulative for spine, independent for obs | Single session for Labs 00-04, fresh cluster for Lab 05 (Prom/Graf to test cold install). Two evidence sets. | |

**User's choice:** Single continuous session (Recommended)
**Notes:** Cumulative-budget evidence is the load-bearing claim of ROADMAP success #5.

### Q2 — Budget capture format

| Option | Description | Selected |
|--------|-------------|----------|
| Capture per-lab into PHASE-02-BUDGETS.md (Recommended) | After each lab, run `kubectl top pods -A` + `kubectl top nodes` + Docker Desktop memory reading. Write to `.planning/phases/02-*/PHASE-02-BUDGETS.md`. Becomes durable evidence + input to v1.1 GPU sizing decisions. | ✓ |
| Capture into VERIFICATION.md only | Inline the budget snapshots into the VERIFICATION.md report. Single artifact but less reusable. | |
| Best-effort, don't gate | Run kubectl top opportunistically. Don't block phase completion on budget evidence. Risk: skip and miss the 16GB ceiling check. | |

**User's choice:** Capture per-lab into PHASE-02-BUDGETS.md (Recommended)
**Notes:** Reused by Phases 03-06 as the baseline for teardown decisions and serving-pattern footprint comparisons.

---

## Cross-platform scope

### Q1 — Verification platform scope

| Option | Description | Selected |
|--------|-------------|----------|
| Verify on user's primary; doc tabs for others (Recommended) | User runs the single-session verification on their actual laptop (likely macOS arm64 per Darwin 24.3.0). Docusaurus Tabs cover macOS+Windows command variants per existing pattern. Mark amd64+Windows as 'attestation pending' in VERIFICATION.md — honest evidence, not faked. | ✓ |
| Block phase until all 3 verified | Hold Phase 02 done-state until user secures amd64 + Windows machines (or VMs/CI). Accurate but blocks v1.0.0 timeline indefinitely. | |
| Mac arm64 only, drop Windows claim | Verify only on user's mac. Update REQUIREMENTS.md to drop Windows-tested claim. Risk: contradicts CLAUDE.md cross-platform constraint. | |
| Defer Windows verify to a v1.0.x patch | Phase 02 verifies mac only. Open follow-up phase 'Windows + amd64 verify' as v1.0.1. Documents the gap explicitly. | |

**User's choice:** Verify on user's primary; doc tabs for others (Recommended)
**Notes:** Windows attestation pending; ROADMAP success #1 amended at planning time.

### Q2 — amd64 mac scope

| Option | Description | Selected |
|--------|-------------|----------|
| Drop amd64 mac; arm64 mac + Windows only (Recommended) | Intel macs out of mainstream sale since 2023. Focus on macOS arm64 (Apple Silicon) + Windows amd64. Update REQUIREMENTS.md + ROADMAP success criterion. Frees verification surface. | ✓ |
| Keep all 3 (mac arm64 + mac amd64 + Windows) | Document support, best-effort verify. Maintains broadest reach but verification cost. | |
| Flag as gray area for plan-phase | Defer the amd64 question to plan-phase research; gather telemetry/audience data first. | |

**User's choice:** Drop amd64 mac; arm64 mac + Windows only (Recommended)
**Notes:** PROJECT.md + ROADMAP + COURSE_VERSIONS.md all updated to drop the amd64-mac claim.

---

## Chainlit /metrics

### Q1 — Fix vs defer

| Option | Description | Selected |
|--------|-------------|----------|
| Fix in Phase 02 Lab 05 (Recommended) | Add prometheus-client to lab-04 (merged serve+ui) requirements.txt; instrument app.py with request counter + latency histogram via `make_asgi_app()`; remove 'placeholder' label from ServiceMonitor. Closes carry-forward debt before v1.0.0 ships. Small scope (~30 lines). | ✓ |
| Defer to v1.1 GOVERN-03 | Distributed tracing (OTEL) coming in v1.1 GOVERN-03 will replace the metrics gap with richer instrumentation. Skip now. Risk: Lab 05 obs still has hollow ServiceMonitor. | |
| Drop the Chainlit ServiceMonitor entirely | Remove the placeholder ServiceMonitor; only vLLM is scraped. Honest about what's wired. Loses UI-level visibility. | |

**User's choice:** Fix in Phase 02 Lab 05 (Recommended)
**Notes:** Closes v0.19.0 OBS-03 gap before v1.0.0 ships. Hard scope cap to keep it from drifting into OTEL design work.

---

## Pattern-A framing

### Q1 — Forward-reference framing

| Option | Description | Selected |
|--------|-------------|----------|
| Add brief teaser per lab (Recommended) | End of Lab 03: 'This is one of two packaging patterns; Pattern B (disk-based) in Phase 03'. End of Lab 04: 'This is one of three serving patterns; Patterns B + C in upcoming labs'. Sets expectation, no comparison content yet (decision labs land in Phase 03/05). | ✓ |
| No teasers; comparison only in decision labs | Keep Lab 03/04 self-contained; Phase 03 PACKAGE-03 + Phase 05 SERVE-04 own all comparison narrative. Cleaner separation, but readers don't know more is coming. | |
| Full inline comparison table now | Add the Pattern A vs B/C tables to Lab 03/04 now. Premature: Patterns B/C don't exist yet, content drifts when Phase 03/05 land. | |

**User's choice:** Add brief teaser per lab (Recommended)
**Notes:** No comparison tables — those land in Phase 03 PACKAGE-03 and Phase 05 SERVE-04.

---

## Claude's Discretion

- Final filenames for the two merged lab pages.
- Exact prometheus-client metric names + cardinality on Chainlit instrumentation.
- Whether the `/metrics` endpoint mounts on Chainlit ASGI app or separate uvicorn route.
- Layout/order of consolidated lab pages (synth-then-RAG vs interleave).
- Per-lab teardown commands inside the single-session run.
- Exact `kubectl top` capture cadence within each lab.

## Deferred Ideas

- Distributed tracing (OTEL) for inference path — v1.1 GOVERN-03.
- Cost-tracking middleware for self-hosted vLLM — v1.1 GOVERN-04.
- Inference-layer guardrails — v1.1 GOVERN-02.
- Bumping PyTorch / Transformers / PEFT / Chainlit / Docusaurus to 2026-05 latest — v1.1.
- Bumping `schoolofdevops/vllm-cpu-nonuma` off 0.9.1.
- Per-lab independent teardown verification (alternative to D-10).
- Inline Pattern A vs B vs C comparison tables — owned by Phase 03 + Phase 05 decision labs.
- Sidebar reorganization beyond removing lab-02 + lab-06 page slots.

## Reviewed Todos (not folded)

None — `gsd-tools todo match-phase 02` returned 0 matches.
