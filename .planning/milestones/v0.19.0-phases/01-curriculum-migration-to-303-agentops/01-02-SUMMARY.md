---
phase: 01-curriculum-migration-to-303-agentops
plan: 02
subsystem: repo-bootstrap
tags: [migration, 303-agentops, bootstrap, context-transfer, Pitfall-9]
dependency_graph:
  requires: [01-01-SUMMARY.md]
  provides: [schoolofdevops/303-agentops on GitHub with bootstrap commit bec2dd2]
  affects: [01-03-PLAN.md (Docusaurus redirects step can now proceed)]
tech_stack:
  added: []
  patterns: [single-bootstrap-commit, fresh-copy-migration, context-dossier]
key_files:
  created:
    - "(303-agentops) PROJECT.md"
    - "(303-agentops) README.md"
    - "(303-agentops) MIGRATION-FROM-302-LLMOPS.md"
    - "(303-agentops) .gitignore"
    - "(303-agentops) course-code/labs/lab-07..lab-13/"
    - "(303-agentops) course-content/docs/labs/lab-07..lab-13.md"
    - "(303-agentops) .planning/phases/03-agentops-labs-day-2/ (19 files)"
    - "(303-agentops) .planning/phases/04-production-ops-capstone-day-3/ (12 agent slices)"
  modified: []
decisions:
  - "Single bootstrap commit per D-02 — fresh copy, no git filter-repo"
  - "303-agentops created with public visibility under schoolofdevops org"
  - "Phase 04 LLMOps slices (04-01..05, 04-10) kept in 302 archive per D-04a"
metrics:
  duration: "6 minutes"
  completed: "2026-05-07T08:12:07Z"
  tasks_completed: 5
  files_created: 216
---

# Phase 01 Plan 02: 303-agentops Bootstrap Summary

**One-liner:** Bootstrapped `schoolofdevops/303-agentops` with single commit `bec2dd2` — 216 files including verbatim Phase 3 validated content, full MIGRATION dossier (all 5 D-11 sections), and complete Phase 03 + agent-slice Phase 04 planning artifacts (Pitfall 9 mandate).

## What Was Done

### Task 1: GitHub repo exists (automated)
The `schoolofdevops/303-agentops` repo already existed (created in a prior session) and was empty. Automation probe confirmed: name `303-agentops`, visibility `PUBLIC`, contents HTTP 404 (empty). No human action required.

### Task 2: Clone empty repo to /Users/gshah/courses/303-agentops/
Cloned via `gh repo clone`. Empty repo left no default branch; initialized `main` manually. Verified sibling placement (NOT nested inside 302-llmops).

### Task 3: Copy lab code, docs, planning slices, .gitignore
- `course-code/labs/lab-07..13/` — 7 directories copied from 302-llmops working tree
- `course-content/docs/labs/lab-07-agent-core.md..lab-13-capstone.md` — 7 files copied
- `.planning/phases/03-agentops-labs-day-2/` — full 19-file Phase 3 archive
- `.planning/phases/04-production-ops-capstone-day-3/` — 12 agent slices (04-06/07/08/09 PLAN+SUMMARY pairs + 4 root .md files)
- LLMOps slices (04-04, 04-10) confirmed absent from 303
- `.gitignore` written with `__pycache__/`, `node_modules/`, `.venv/`, `.env.*`

### Task 4: Write PROJECT.md, README.md, MIGRATION-FROM-302-LLMOPS.md
All three root files written with required D-11 content.

**PROJECT.md verbatim checks passed:**
- `Hermes Agent (NousResearch v0.12.0) configured for Smile Dental` — present
- `Cold-vs-warm timing demo — observed warm 7.95s / cold refill 25.03s / cold 2.54s` — present
- `D-18 partial compliance documented honestly` — present
- All 7 AgentOps Key Decisions rows — present

**MIGRATION-FROM-302-LLMOPS.md all 5 D-11 sections:**
1. Why split — paragraph explaining dual-domain dilution
2. Full history pointer — `https://github.com/schoolofdevops/302-llmops/tree/v0.19.0` + SHA `3c4e0b120efd93a147d61f916a943e6a775ec717`
3. Inherited key decisions — verbatim table (7 rows)
4. Validated configs — Hermes (Lab 07), Sandbox v0.4.3 (Lab 08), observability with `agent_llm_tokens_total`/`agent_llm_cost_usd_total` (Lab 09), eval gate (Lab 12), guardrails + capstone (Lab 13)
5. Known issues — D-18 partial compliance documented with symptom + workaround paths

**README.md:** points to 302-llmops as prerequisite, includes full-history tag URL, links to MIGRATION-FROM-302-LLMOPS.md

### Task 5: Bootstrap commit + push
- Staged all 216 files
- Created single bootstrap commit: `bec2dd2 chore: bootstrap from 302-llmops v0.19.0`
- `git rev-list --count HEAD` = 1 (D-02 single commit verified)
- Pushed to `origin main`
- Verified: `git ls-remote https://github.com/schoolofdevops/303-agentops HEAD` = `bec2dd249c85d9216e4a07ea866d04adf5a89546`

## Verification Evidence

```
Bootstrap commit SHA: bec2dd249c85d9216e4a07ea866d04adf5a89546
Remote HEAD (ls-remote): bec2dd249c85d9216e4a07ea866d04adf5a89546  HEAD

File counts (from git ls-files on local clone = pushed state):
  .planning/phases/03-agentops-labs-day-2/: 19 files
  .planning/phases/04-production-ops-capstone-day-3/: 12 files
  course-code/labs/: lab-07..lab-13 (7 dirs)
  course-content/docs/labs/: 7 files
  Total: 216 files

LLMOps slice quarantine:
  04-04-PLAN.md in 303: ABSENT (PASS)
  04-10-PLAN.md in 303: ABSENT (PASS)

302-llmops main:
  Lab/course-content code changes: 0 (untouched)
  .planning/ pre-existing modification: 01-03-PLAN.md (tracked file, modified before this plan, not caused by plan 01-02)
```

## 302-llmops Main Status

The 302-llmops `main` branch has ONE pre-existing modification: `.planning/milestones/v0.19.0-phases/01-curriculum-migration-to-303-agentops/01-03-PLAN.md`. This file is tracked in git (committed before `.planning/` was added to `.gitignore`) and was modified in a prior session — NOT by this plan. All lab code, course-content, and Docusaurus files are unchanged. D-10 deletion-last is preserved.

## Deviations from Plan

None — plan executed exactly as written.

The only minor note: Task 1 was resolved by automation (repo existed from prior session, empty and public) rather than requiring human action. The plan's automation-first protocol worked as designed.

## Known Stubs

None. All files contain real content:
- PROJECT.md: verbatim validated data, real decisions table
- MIGRATION-FROM-302-LLMOPS.md: real dossier with evidence-based timing numbers
- Lab code/docs: working-tree copies from v0.19.0 validated state

## Next Plan

`01-03-PLAN.md` — Docusaurus redirects + title rename + CHANGELOG + README in 302-llmops. This plan modifies the 302-llmops course-content tree (not the new 303-agentops repo).

## Self-Check: PASSED

- `/Users/gshah/courses/303-agentops/.git/` exists: YES
- Bootstrap commit `bec2dd2` exists: YES (`git rev-parse HEAD` = `bec2dd249c85d9216e4a07ea866d04adf5a89546`)
- Remote HEAD matches local: YES (both `bec2dd249c85d9216e4a07ea866d04adf5a89546`)
- SUMMARY.md created at: `.planning/milestones/v0.19.0-phases/01-curriculum-migration-to-303-agentops/01-02-SUMMARY.md`
