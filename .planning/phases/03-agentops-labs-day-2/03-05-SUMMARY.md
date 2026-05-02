---
phase: 03-agentops-labs-day-2
plan: "05"
subsystem: lab-08-doc
tags: [lab-08, docusaurus, kubernetes-agent-sandbox, sandboxwarmpool, hermes-agent, mcp, networkpolicy, cold-warm-demo]
dependency_graph:
  requires: [03-04]
  provides: [lab-08-student-walkthrough]
  affects: [03-06, 03-07]
tech-stack:
  added: []
  patterns: [docusaurus-tabs-router-mode, admonition-kindnet-caveat, cold-warm-timing-embed, mdx-jsx-comment]
key-files:
  created: []
  modified:
    - course-content/docs/labs/lab-08-agent-sandbox.md
key-decisions:
  - "ROUTER_MODE=gcr was the active path during verification build — GCR Router image confirmed pullable on KIND"
  - "Verbatim B4 timings embedded from 03-04-SUMMARY.md: Warm 7.95s, Cold refill 25.03s, Cold first request 2.54s"
  - "NetworkPolicy kindnet non-enforcement documented with explicit warning admonition in D.6 and again in Common Pitfalls"
  - "W5 pre-check guard confirmed: 03-04-SUMMARY.md exists and contains cold/warm timing values"
  - "W6 pre-check confirmed: node_modules present, npm run build exits 0"
metrics:
  duration: "5 minutes"
  completed: "2026-05-02"
  tasks_total: 1
  tasks_completed: 1
  files_created: 0
  files_modified: 1
---

# Phase 3 Plan 05: Lab 08 Documentation Summary

Full Docusaurus walkthrough for Lab 08 Agent Sandbox — 600-line page takes a student from installing K8s Agent Sandbox v0.4.3 CRDs through a live multi-step demo (Warm 7.95s / Cold refill 25.03s / Cold first request 2.54s), with explicit gcr-vs-port-forward branching and kindnet NetworkPolicy caveat.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Rewrite lab-08-agent-sandbox.md as complete K8s Agent Sandbox walkthrough | 4ede538 | course-content/docs/labs/lab-08-agent-sandbox.md |

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

### Design Choices During Execution

**Line count management:** The initial draft was 746 lines, exceeding the 600-line hard cap. Trimmed by: removing the full RBAC YAML block from D.1 (students read `60-booking-rbac.yaml`), shortening the mcp-triage Deployment YAML in D.3 to a prose explanation, removing the full NetworkPolicy YAML from D.6 in favour of a prose summary, and condensing the C.1 Secret section (removing the inline YAML block). Final: exactly 600 lines.

**Docusaurus build:** Used `npm run build` (not `npx docusaurus@3.10.0 build`) because `npx docusaurus@3.10.0` tries to install a separate package matching the exact version specifier `docusaurus@3.10.0` which does not exist as a standalone package. `npm run build` invokes the already-installed `@docusaurus/core@3.10.0` from `node_modules/.bin/docusaurus` — correct behavior.

## Line Count

Final: **600 lines** (hard cap: 600)

## The 5 Common Pitfalls Included

1. **kindnet does NOT enforce NetworkPolicy** — KIND's default CNI (kindnet) does not implement the NetworkPolicy spec; policy is applied as production documentation artifact only (RESEARCH Pitfall 2)
2. **Sandbox Router image may fail to pull on restricted networks** — links back to verify script and Part D.5 port-forward fallback (RESEARCH Pitfall 5)
3. **book_appointment returns 403 from K8s API** — must apply `60-booking-rbac.yaml` and use `serviceAccountName: mcp-booking-sa` in the book_appointment Deployment (RESEARCH Pitfall 6)
4. **DNS broken by missing NetworkPolicy UDP rule** — Pitfall 7 from RESEARCH.md; UDP+TCP 53 must be allowed (already in the policy, do not remove)
5. **First Hermes pull is slow** — pre-pull `nousresearch/hermes-agent:latest` and `kind load` to avoid 5+ min wait in Part D.4

## Observed B4 Timings (from 03-04-SUMMARY.md)

Embedded verbatim in Part G:

```
  Warm: HTTP 200 in 7.95s
  Cold WarmPool refill (0 -> 2 ready): 25.03s
  Cold: HTTP 200 in 2.54s
```

Analysis also embedded: Warm 7.95s = LLM API round-trip (3 tool calls); Cold refill 25.03s = image cached, only Hermes startup; Cold first request 2.54s = WarmPool already ready by request time.

## Router Mode During Verification

**ROUTER_MODE=gcr** — the active path during plan execution. `verify-sandbox-router-image.sh` confirmed the GCR-hosted Router image (`us-central1-docker.pkg.dev/k8s-staging-images/agent-sandbox/sandbox-router:latest-main`) pulls without GCP credentials on KIND.

## W5 + W6 Pre-condition Status

- **W5:** `.planning/phases/03-agentops-labs-day-2/03-04-SUMMARY.md` exists and contains observed warm + cold timing values — PASSED
- **W6:** `course-content/node_modules` exists (no `npm ci` needed) — PASSED; `npm run build` exits 0 — PASSED

## Docusaurus Build

**Status: PASSED**

Build command: `npm run build` from `course-content/`
Output: `[SUCCESS] Generated static files in "build".`

## Known Stubs

None — all sections contain production-ready content referencing real solution files. The `{/* TODO: screenshot */}` pattern from Lab 07 was deliberately omitted from Lab 08 (not in the plan spec).

## Self-Check: PASSED

File exists and has 600 lines:
- `course-content/docs/labs/lab-08-agent-sandbox.md` — FOUND (600 lines)

Commit exists:
- `4ede538` — FOUND
