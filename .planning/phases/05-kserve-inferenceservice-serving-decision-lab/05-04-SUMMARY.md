---
phase: 05-kserve-inferenceservice-serving-decision-lab
plan: 04
subsystem: docs
tags: [kserve, docusaurus, lab-guide, serving-decision, teardown, verification]

# Dependency graph
requires:
  - phase: 05-kserve-inferenceservice-serving-decision-lab
    plan: 03
    provides: "ClusterServingRuntime + InferenceService YAML (solution + starter); InferenceService smollm2 READY=True on cluster; NodePort 30202 verified"
provides:
  - "Lab 08 student guide (course-content/docs/labs/lab-08-kserve-inferenceservice.md)"
  - "Lab 09 serving-decision reference page (course-content/docs/labs/lab-09-serving-decision.md)"
  - "sidebars.ts updated with lab-08 + lab-09 entries after lab-07-vllm-router"
  - "COURSE_VERSIONS.md updated: cert-manager v1.16.5, Gateway API CRDs v1.2.1, KServe CRDs v0.18.0, KServe resources v0.18.0 rows; Last verified 2026-06-16 Phase 05"
  - "KServe stack fully torn down (kserve + cert-manager namespaces deleted, helm releases uninstalled)"
  - "Pattern A restored to replicas=1 and serving at NodePort 30200"
  - "VERIFICATION.md: all 5 SC rows PASS with evidence; Deviations table populated"
affects:
  - "Phase 06 can start with clean spine: Pattern A only, no KServe/cert-manager overhead"
  - "Students can reference Lab 09 as a standalone serving-decision bookmark"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Lab guide structure: ARM64 callout + Part-numbered sections + details solution blocks + Troubleshooting — mirror of lab-07-vllm-router.md"
    - "Serving-decision reference page: comparison table + ASCII decision tree + When-to-Use per pattern"
    - "D-13 teardown sequence: ISVC → CSR → helm uninstall kserve → kserve-crd → Gateway API CRDs → cert-manager → ns delete → Pattern A restore"

key-files:
  created:
    - course-content/docs/labs/lab-08-kserve-inferenceservice.md
    - course-content/docs/labs/lab-09-serving-decision.md
    - .planning/phases/05-kserve-inferenceservice-serving-decision-lab/VERIFICATION.md
    - .planning/phases/05-kserve-inferenceservice-serving-decision-lab/05-04-SUMMARY.md
  modified:
    - course-content/sidebars.ts
    - course-code/COURSE_VERSIONS.md

key-decisions:
  - "Lab 08 uses separate NodePort Service (25-svc-nodeport.yaml) pattern documented prominently — lab-08 teaches the correct KServe exposure pattern, not the kubectl patch anti-pattern"
  - "Lab 09 has no bash commands — pure reference page per D-08"
  - "COURSE_VERSIONS.md KServe N/A row replaced with 4 pinned rows (cert-manager + Gateway API CRDs + kserve-crd + kserve-resources)"
  - "Teardown executed successfully — kserve + cert-manager namespaces deleted, Pattern A restored, helm list shows only minio"

patterns-established:
  - "Three-pattern comparison table format for serving-decision page (Pattern A / Pattern B / Pattern C as columns, dimensions as rows)"
  - "ASCII decision tree for serving pattern selection"

requirements-completed: [SERVE-02, SERVE-04]

# Metrics
duration: 65min
completed: 2026-06-17
---

# Phase 05 Plan 04: Lab Guide, Serving Decision Page, Teardown, Verification — Summary

**Lab 08 (KServe InferenceService guide) + Lab 09 (Serving Decision Lab) written; sidebars + COURSE_VERSIONS updated; KServe stack torn down; Pattern A restored at replicas=1; VERIFICATION.md complete with 5 PASS rows.**

## Performance

- **Duration:** ~65 min
- **Started:** 2026-06-17T08:40:00Z
- **Completed:** 2026-06-17T09:45:00Z
- **Tasks:** 2 complete (2 auto)
- **Files created:** 4 (lab-08.md, lab-09.md, VERIFICATION.md, this SUMMARY.md)
- **Files modified:** 2 (sidebars.ts, COURSE_VERSIONS.md)

## Accomplishments

- Wrote `course-content/docs/labs/lab-08-kserve-inferenceservice.md` — 12 Parts mirroring lab-07 structure: ARM64 callout (D-10), cert-manager install (Pitfall 8 webhook-wait), Gateway API CRDs, KServe v0.18 Helm OCI install (RawDeployment), ConfigMap patch, ClusterServingRuntime (starter + solution details block), InferenceService (starter + solution details block), READY=True watch, separate NodePort Service (25-svc-nodeport.yaml pattern), chat verification (Tabs macOS/Linux vs PowerShell), resource budget, D-13 teardown, 8-pitfall troubleshooting section
- Wrote `course-content/docs/labs/lab-09-serving-decision.md` — Pattern A/B/C comparison table (8 dimensions, real YAML line counts), ASCII decision tree, When-to-Use sections for all 3 patterns with Lab 04/07/08 links, deferred topics callout (no benchmarks per D-08)
- Updated `course-content/sidebars.ts` — added `labs/lab-08-kserve-inferenceservice` and `labs/lab-09-serving-decision` after `labs/lab-07-vllm-router`
- Updated `course-code/COURSE_VERSIONS.md` — replaced `KServe | N/A (Phase 2)` row with 4 pinned rows; Last verified date updated to `2026-06-16 (v1.0.0 Phase 05)`
- Ran Docusaurus build — exit 0, `Generated static files in "build"` (onBrokenLinks: throw)
- Executed D-13 teardown: InferenceService + NodePort Service + ClusterServingRuntime deleted; kserve + kserve-crd Helm releases uninstalled; Gateway API CRDs deleted; cert-manager uninstalled; kserve + cert-manager namespaces deleted
- Restored Pattern A (`vllm-smollm2`) to replicas=1; rollout status confirmed; `curl http://localhost:30200/v1/chat/completions` returns valid chat completion
- Wrote VERIFICATION.md with 5 PASS rows (no placeholders), Deviations table, Resource Budget, Teardown Evidence sections

## Task Commits

1. **Task 1: Lab 08 + Lab 09 + sidebars + COURSE_VERSIONS** — `90ea8ec` (docs)
2. **Task 2: Teardown + VERIFICATION.md + SUMMARY.md** — this docs commit

## Files Created/Modified

- `course-content/docs/labs/lab-08-kserve-inferenceservice.md` — 800+ line student guide (12 Parts + Troubleshooting)
- `course-content/docs/labs/lab-09-serving-decision.md` — 100+ line serving-decision reference page
- `course-content/sidebars.ts` — added 2 lab entries
- `course-code/COURSE_VERSIONS.md` — replaced 1 placeholder row with 4 pinned rows; Last verified updated
- `.planning/phases/05-kserve-inferenceservice-serving-decision-lab/VERIFICATION.md` — 5 PASS rows + Deviations + Teardown Evidence

## Decisions Made

- Lab 08 documents the **separate NodePort Service pattern** prominently (Part 9 is dedicated to this) — the `kubectl patch svc` anti-pattern is mentioned in Troubleshooting as "why it doesn't work" educational content only
- Lab 09 is a **pure reference page** — no bash commands, no Tabs blocks, no ARM64 callouts (pure comparison/decision content per D-08)
- COURSE_VERSIONS.md now has **4 KServe-related rows** instead of 1 placeholder, giving students exact install info for all three prerequisites

## Deviations from Plan

### No Deviations

Plan executed exactly as written. All four files created per spec. Docusaurus build passed first attempt. Teardown ran cleanly without errors. Pattern A restored successfully.

The VERIFICATION.md documents 5 deviations from prior plans (05-01 through 05-03) — those are historical deviations recorded for audit, not new deviations introduced in this plan.

## Issues Encountered

- VERIFICATION.md lives in `.planning/` which is gitignored — committed via `git add -f` (same pattern as prior phase SUMMARY.md files). This is expected behavior.
- RTK proxy intercepts grep and rg with short options — switched to `rg "pattern" file` form for all verification checks.
- RTK proxy intercepts curl JSON output (shows schema instead of actual content) — used `rtk proxy curl` to bypass for Pattern A chat verification.

## Threat Surface Scan

No new network endpoints, auth paths, or schema changes introduced. Lab 08 and Lab 09 are static documentation files. No executable code, no API endpoints, no Kubernetes resources deployed by this plan (teardown removes all KServe resources).

T-05-14 (Docusaurus build with onBrokenLinks:throw): MITIGATED — build ran and exited 0.
T-05-15 (Phase 06 headroom): MITIGATED — teardown complete, kubectl top nodes (metrics-server absent) but helm list shows no KServe/cert-manager releases and kserve+cert-manager namespaces deleted.

## Known Stubs

None — all documentation content is grounded in actual Phase 05 verification results (READY=True evidence, NodePort 30202 curl verified, exact YAML file paths confirmed). No placeholder content in lab guides.

## Self-Check: PASSED

- `course-content/docs/labs/lab-08-kserve-inferenceservice.md`: EXISTS (800+ lines)
- `course-content/docs/labs/lab-09-serving-decision.md`: EXISTS (100+ lines)
- `course-content/sidebars.ts`: lab-08 + lab-09 entries present
- `course-code/COURSE_VERSIONS.md`: v1.16.5, v1.2.1, v0.18.0 rows + Phase 05 Last verified
- `rg "Apple Silicon" lab-08-kserve-inferenceservice.md`: MATCH
- `rg "RawDeployment" lab-08-kserve-inferenceservice.md`: MATCH (13 occurrences)
- `rg "disableIngressCreation" lab-08-kserve-inferenceservice.md`: MATCH
- `rg "Decision Tree" lab-09-serving-decision.md`: MATCH
- Docusaurus build: exit 0, "Generated static files in build"
- Teardown: kserve + cert-manager namespaces deleted, helm releases removed
- Pattern A: spec.replicas=1, status.readyReplicas=1, curl PASS

---
*Phase: 05-kserve-inferenceservice-serving-decision-lab*
*Completed: 2026-06-17*
