# GUARD-03 — Governance overview

This folder contains the **source content** for Lab 13's Governance walkthrough section. The lab page (`course-content/docs/labs/lab-13-capstone.md`, written by plan 04-09) embeds this material verbatim.

Per D-18 (Phase 4 CONTEXT.md), GUARD-03 is a documentation deliverable, not new tooling — every component cited here already exists from Labs 09, 11, and 12.

## The three pillars

### Pillar 1: Model versioning audit trail — via Lab 12 image-tag git history

Lab 12's pipeline (`step-commit-tag` in `101-workflowtemplate-llm-pipeline.yaml`) writes one commit per successful eval-gate pass. Each commit message follows the format:

    ci(lab-12): bump model-version to <tag> (eval gate passed)

The `<tag>` field is `smollm2-135m-finetuned-<workflow-creation-timestamp>` — a deterministic, sortable identifier tied to the Argo Workflow run that produced it. To audit which model version was deployed when, run the queries in `audit-trail-queries.sh` (Section "Model versioning").

### Pillar 2: GitOps deploy-time provenance — via ArgoCD Application history

Lab 11 set up ArgoCD with auto-sync. Every commit on the gitops-repo that ArgoCD detects creates a row in the Application's `history` field, mapping a git commit SHA to the timestamp the cluster reached the new desired state. Audit query examples in `audit-trail-queries.sh` (Section "GitOps provenance").

The combination of (1) + (2) gives end-to-end traceability:
"Which model version was running on date D?" → check `argocd app history vllm` for the SHA active at D, then `git show <SHA>` for the model-version tag committed at that SHA.

### Pillar 3: Runtime compliance evidence — via OTEL traces

Lab 09 wired Tempo + OpenTelemetry collector. Every MCP tool invocation (including the Lab 13 `insurance_check` tool and the GuardrailMiddleware-blocked queries) emits a span. To produce trace evidence for an audit:

- "Show me the trace where Aetna+root canal was queried on date D" → use the TraceQL selector in `otel-trace-evidence-selector.md`
- "Show me a trace where a guardrail blocked a query" → same file documents the selector for blocked-query traces (status=ERROR + tool name)

The cost middleware (Lab 09) attaches `agent_llm_cost_usd_total` to a Grafana panel — for compliance reports, screenshot the panel filtered to the relevant time range.

## Why D-18 chose doc-only

The roadmap requirement for GUARD-03 is "governance overview — audit trail + OTEL evidence." Building a new audit dashboard or compliance scanner would have been scope creep; we already have all three pillars wired by Day 1+2 + Lab 11 + Lab 12. GUARD-03 is implemented as no new tooling — only documentation and query recipes that teach students to use the existing stack for compliance evidence. The teaching value is showing students how to *use* what they built for compliance, not building yet another tool.

## Files in this folder

| File | Purpose |
|------|---------|
| `README.md` | This file — Lab 13 doc plan reads it as the source structure |
| `audit-trail-queries.sh` | Executable script with copy-paste queries for all three pillars |
| `otel-trace-evidence-selector.md` | TraceQL/Grafana Explore URL recipes for evidence queries |
