---
phase: 01-curriculum-migration-to-303-agentops
plan: "03"
subsystem: docusaurus-site
tags: [redirects, title-rename, changelog, readme, sidebar-cleanup]
dependency_graph:
  requires: [01-02]
  provides: [redirects-plugin-registered, title-renamed, sidebar-pruned, changelog-updated, readme-created]
  affects: [01-04]
tech_stack:
  added: ["@docusaurus/plugin-client-redirects@3.10.0"]
  patterns: [client-redirects, version-selector-readme]
key_files:
  created:
    - README.md
    - course-content/package-lock.json (updated)
  modified:
    - course-content/package.json
    - course-content/docusaurus.config.ts
    - course-content/sidebars.ts
    - CHANGELOG.md
decisions:
  - "Redirects use single landing page target (https://github.com/schoolofdevops/303-agentops) for all 7 lab URLs per D-05 default"
  - "logo.alt updated from 'LLMOps & AgentOps Logo' to 'LLMOps Logo' alongside title rename (D-06)"
  - "tagline updated to 'Production LLM serving on Kubernetes' to reflect LLMOps-only scope"
metrics:
  duration_seconds: 199
  completed_date: "2026-05-07T08:18:16Z"
  tasks_completed: 4
  files_changed: 6
---

# Phase 01 Plan 03: Redirects, Title Rename, CHANGELOG, README Summary

**One-liner:** Registered 7 client-side redirects (lab-07..13 to 303-agentops), renamed Docusaurus site to 'LLMOps with Kubernetes', pruned sidebar, prepended CHANGELOG v1.0.0 entry, and created repo-root README with version selector.

## What Was Built

This plan executed D-05, D-06, D-07, D-08 from 01-CONTEXT.md — the "prepare before deletion" step in the D-10 ordered sequence. Lab files are NOT deleted yet (that is plan 01-04's job).

### Task 1: Add @docusaurus/plugin-client-redirects dependency
- **Commit:** `85e2c15`
- **Files:** `course-content/package.json`, `course-content/package-lock.json`
- Added `"@docusaurus/plugin-client-redirects": "3.10.0"` to dependencies, pinned to match other `@docusaurus/*` packages
- `npm install` run to install into node_modules

### Task 2: Update docusaurus.config.ts
- **Commit:** `a269857`
- **Files:** `course-content/docusaurus.config.ts`
- Title renamed: `'LLMOps & AgentOps with Kubernetes'` → `'LLMOps with Kubernetes'` (D-06)
- Tagline updated: `'From RAG to production agents on Kubernetes'` → `'Production LLM serving on Kubernetes'`
- `logo.alt` updated: `'LLMOps & AgentOps Logo'` → `'LLMOps Logo'`
- `plugins[]` array added before `presets`: registers `@docusaurus/plugin-client-redirects` with 7 redirect entries
- `onBrokenLinks: 'throw'` preserved (not modified)
- TypeScript check (`npx tsc --noEmit`) passed with no errors

### Task 3: Sidebar cleanup, CHANGELOG, README
- **Commit:** `f530c3d`
- **Files:** `course-content/sidebars.ts`, `CHANGELOG.md`, `README.md`
- `sidebars.ts`: 7 agent lab entries (lab-07..13) removed from Labs category; category now ends at `lab-06-web-ui`
- `CHANGELOG.md`: `## v1.0.0 — split from v0.19.0` entry prepended above `## [v0.1.0]`; includes v0.19.0 SHA `3c4e0b120efd93a147d61f916a943e6a775ec717`, 303-agentops link, removed labs list
- `README.md`: created at repo root with "Which version are you on?" table linking v1.0.0 main, v0.19.0 tag, v0.19.x branch, 303-agentops companion

### Task 4: Push to origin
- All 3 commits pushed to `origin/main`
- `git log --oneline origin/main -1` confirms `f530c3d` is on origin

## Redirect Map

| From (internal URL) | To (external) |
|---------------------|---------------|
| `/docs/labs/lab-07-agent-core` | https://github.com/schoolofdevops/303-agentops |
| `/docs/labs/lab-08-agent-sandbox` | https://github.com/schoolofdevops/303-agentops |
| `/docs/labs/lab-09-observability` | https://github.com/schoolofdevops/303-agentops |
| `/docs/labs/lab-10-autoscaling` | https://github.com/schoolofdevops/303-agentops |
| `/docs/labs/lab-11-gitops` | https://github.com/schoolofdevops/303-agentops |
| `/docs/labs/lab-12-pipelines` | https://github.com/schoolofdevops/303-agentops |
| `/docs/labs/lab-13-capstone` | https://github.com/schoolofdevops/303-agentops |

## Deviations from Plan

None — plan executed exactly as written. All edits matched the verified_facts in the plan's context block.

## Lab Files Status

Lab-07..13 markdown files are STILL present on disk (not deleted). Deletion happens in plan 01-04 as the final step per D-10 order.

- `course-content/docs/labs/lab-07-agent-core.md` — still present
- `course-content/docs/labs/lab-13-capstone.md` — still present

## Next Plan

**01-04:** Delete AgentOps lab files from 302-llmops `main` (`git rm` commit) + verify Docusaurus build passes (`npm run build`). This completes MIGRATE-05.

## Known Stubs

None — no stub data in any files created or modified by this plan.

## Self-Check: PASSED

- `course-content/package.json` contains `@docusaurus/plugin-client-redirects` — FOUND
- `course-content/docusaurus.config.ts` contains `title: 'LLMOps with Kubernetes'` — FOUND
- `course-content/docusaurus.config.ts` contains `@docusaurus/plugin-client-redirects` plugin — FOUND
- 7 redirect `from:` entries present — FOUND (count: 7)
- `course-content/sidebars.ts` has 0 agent lab references — CONFIRMED (count: 0)
- `CHANGELOG.md` has `## v1.0.0 — split from v0.19.0` — FOUND
- `CHANGELOG.md` has SHA `3c4e0b120efd93a147d61f916a943e6a775ec717` — FOUND
- `README.md` exists at repo root — FOUND
- `README.md` has "Which version are you on?" — FOUND
- Commits on origin: `85e2c15`, `a269857`, `f530c3d` — VERIFIED
