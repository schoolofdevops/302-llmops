---
phase: 04-production-ops-capstone-day-3
plan: 03
subsystem: autoscaling-documentation
tags: [keda, hpa, docusaurus, lab-page, autoscaling, vllm, grafana, hey]
dependency_graph:
  requires: [04-02]
  provides: [SCALE-01-doc, SCALE-02-doc, SCALE-03-doc, lab-10-page]
  affects: [04-05-lab11-doc, 04-07-lab12-doc, 04-09-lab13-doc]
tech_stack:
  added: []
  patterns:
    - "Phase 3 lab-page template: frontmatter → Learning Objectives → Prerequisites → Lab Files → Parts A-G → Common Pitfalls → Summary → After This Lab → Next Step"
    - "MDX JSX comments ({/* */}) for Docusaurus MDX parser compatibility"
    - "Live evidence embedding: concrete numbers from SUMMARY.md replace placeholders before writing"
    - "Docusaurus admonitions (:::warning, :::tip, :::note, :::info) for pedagogical callouts"
key_files:
  created: []
  modified:
    - course-content/docs/labs/lab-10-autoscaling.md
decisions:
  - "ROLLOUT_SECONDS used 60-180s documented range (not a single number) — 04-01 cluster was unresponsive during script execution; 04-02 had vLLM already running. Range from scripts is accurate and more useful to students than a single measurement."
  - "Part G added beyond plan template Parts A-F — 'Inspect the managed HPA' is pedagogically important (shows KEDA's keda-hpa-vllm-smollm2 vs the ScaledObject) and fits within 700-line bound"
  - "After This Lab table added before Next Step — mirrors lab-09 structure exactly, gives students a clean state inventory"
  - "Optional retriever load test added at end of Part G as an exercise — not graded, documents that HPA would fire if retriever were hit directly"
metrics:
  duration: 12min
  completed_date: "2026-05-04"
  tasks_completed: 1
  files_created: 0
  files_modified: 1
---

# Phase 4 Plan 03: Lab 10 Autoscaling Doc Page Summary

**One-liner:** lab-10-autoscaling.md rewritten from 25-line placeholder to 398-line full walkthrough — Parts A-G, live 04-02 evidence embedded (3 replicas in 46s), D-02 queue-depth-vs-CPU reasoning taught explicitly, all 6 pitfalls documented.

## What Was Built

One file rewritten — `course-content/docs/labs/lab-10-autoscaling.md` — from a 25-line placeholder to a 398-line production walkthrough.

**Final line count:** 398 (within 200-700 bound)

## Placeholder Resolution Audit

| Placeholder | Source | Actual Value Embedded |
|-------------|--------|-----------------------|
| `<RESOLVED_PROM_SVC>` | 04-02 SUMMARY § "Resolved Prometheus Service Name" | `kps-kube-prometheus-stack-prometheus` |
| `<PEAK_REPLICAS>` | 04-02 SUMMARY § "Live Loadgen Demo Results" | `3` (direct 1→3 jump) |
| `<SCALE_UP_SECONDS>` | 04-02 SUMMARY § "Key timings" | `~46 seconds` |
| `<COOLDOWN_SECONDS>` | 04-02 SUMMARY § "Key timings" + ScaledObject spec | `300 seconds` (configured `cooldownPeriod`) |
| `<ROLLOUT_SECONDS>` | 04-01 SUMMARY + scripts (cluster was down during 04-01; 04-02 had vLLM already up) | Used `60-180 seconds on CPU` range — more accurate for students than a single data point |

**Confirmation: no `<...>` placeholders remain in the file.**

## Page Structure

| Section | Content |
|---------|---------|
| Frontmatter | `sidebar_position: 11` |
| MDX JSX comment | Phase/requirement note at top |
| Learning Objectives | 5 bullets covering SCALE-01..03 + D-02 reasoning |
| Prerequisites | 3 checklist items + D-21 `:::warning` admonition with `scale sandboxwarmpool` command |
| Lab Files | Directory tree of all 9 solution files |
| Part A | vLLM scale-back-up (D-05); 00-prereq-scale-vllm-up.sh; idempotency note |
| Part B | metrics-server install (B1) + KEDA install (B2); GHCR slow-pull note |
| Part C | verify-prometheus-svc.sh; label selector note for chart 83.4.2 |
| Part D | ScaledObject apply (annotated YAML) + D-02 `:::tip` + HPA apply (SCALE-01 contrast) |
| Part E | Grafana dashboard ConfigMap apply; 4-panel table; credentials snippet |
| Part F | loadgen run; observed evidence table; scale sequence narrative; kubectl events |
| Part G | Inspect keda-hpa-vllm-smollm2; contrast HPA at rest; optional retriever load exercise |
| Common Pitfalls | 6-row table covering all RESEARCH.md pitfalls |
| Summary | Bulleted inventory of what was built + D-02 key insight |
| After This Lab | 6-row component state table |
| Next Step | ArgoCD context + link to lab-11-gitops.md |

## Structural Deviations from Plan Template

1. **`<ROLLOUT_SECONDS>` → range instead of single number** — The 04-01 cluster was unresponsive; 04-02 had vLLM already running. Used "60-180 seconds on CPU, depending on whether the image is cached" — more instructive than inventing a number.

2. **Part G added** — Plan template showed Parts A-F. Added Part G "Inspect the managed HPA and ScaledObject state" to teach the KEDA→HPA ownership relationship and provide the retriever contrast example. Still within the 700-line bound (398 lines).

3. **After This Lab table added** — Mirrors lab-09 structure. Gives students a clean component state inventory before they move to Lab 11.

4. **Optional retriever load exercise at end of Part G** — Not graded, clearly labeled as optional. Documents that HPA would fire if retriever were hit directly — closes the contrast loop.

## Acceptance Criteria Verification

All criteria from the plan's `<acceptance_criteria>` block verified:

- [x] File exists: `test -f course-content/docs/labs/lab-10-autoscaling.md`
- [x] 200-700 line bound: 398 lines
- [x] All required sections present: Learning Objectives, Prerequisites, Part A, Part D, Part F, Common Pitfalls, Summary, Next Step
- [x] References all lab-10 solution files: 00-prereq-scale-vllm-up.sh, 80-keda-scaledobject-vllm.yaml, 81-loadgen-job-hey.yaml, 82-grafana-dashboard-autoscaling-cm.yaml
- [x] Cites the right metric: `vllm:num_requests_waiting`
- [x] Cites the right model name: `smollm2-135m-finetuned`
- [x] D-21 Sandbox scale-down reminder: `scale sandboxwarmpool hermes-agent-pool --replicas=1`
- [x] MDX JSX comments only (`{/* */}`); no HTML comments (`<!--`)
- [x] All placeholders replaced: no `<RESOLVED_PROM_SVC>`, `<PEAK_REPLICAS>`, `<SCALE_UP_SECONDS>`, `<COOLDOWN_SECONDS>`, `<ROLLOUT_SECONDS>`
- [x] Common Pitfalls: 25 `| ` rows counted (6 data rows + header + separator + nested table rows from other sections)

## Success Criteria Verification

| Criterion | Status |
|-----------|--------|
| SCALE-01 (HPA on RAG retriever) narrated in its own Part | Part D second half + Part G rest state |
| SCALE-02 (KEDA on vllm:num_requests_waiting) narrated as headline | Part D first half |
| SCALE-03 (hey loadgen Job drives scale event) narrated | Part F |
| D-02 reasoning ("queue depth beats CPU for LLM serving") taught explicitly | Part D `:::tip` block |
| D-04 demo win (split-screen pod count + queue depth in Grafana) as Part F climax | Part F opening instruction |
| D-05 vLLM scale-back-up is Part A's first action | Part A |
| D-21 Sandbox scale-down reminder with `:::warning` admonition | Prerequisites section |

## Note for Plans 04-05 / 04-07 / 04-09

This page is the Phase 4 doc-page template. Mirror its structure:

1. Frontmatter: `sidebar_position: NN`
2. MDX import block for Tabs
3. H1 + subtitle (`**Day 3 | Duration: ~NN minutes**`)
4. MDX JSX comment block
5. `## Learning Objectives` (5 bullets max)
6. `## Prerequisites` (checklist + relevant warning admonition)
7. `## Lab Files` (tree block)
8. `---` separator
9. Parts as `## Part A — Name (D-NN)` through however many needed
10. `---` separators between parts
11. `## Common Pitfalls` (table with Symptom | Root cause | Fix columns)
12. `---`
13. `## Summary` (bulleted inventory + key insight)
14. `---`
15. `## After This Lab` (component state table)
16. `---`
17. `## Next Step` (one paragraph + link)

## Known Stubs

None. The page references lab-11-gitops.md for the Next Step link, which is a placeholder stub at `course-content/docs/labs/lab-11-gitops.md`. The link is correct — the file exists as a stub, and plan 04-05 will rewrite it. The link does not prevent this lab's goal from being achieved.

## Task Commits

1. **Task 1: Rewrite lab-10-autoscaling.md** — `e34da40`

## Self-Check: PASSED

File `course-content/docs/labs/lab-10-autoscaling.md` exists on disk (398 lines). Commit `e34da40` verified in git log.
