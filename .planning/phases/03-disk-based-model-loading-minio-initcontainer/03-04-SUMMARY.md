---
phase: 03-disk-based-model-loading-minio-initcontainer
plan: "04"
subsystem: course-content
tags: [lab-guide, docusaurus, minio, initcontainer, pattern-b, decision-guide]
dependency_graph:
  requires: ["03-03"]
  provides: ["lab-06-disk-model-loading.md", "sidebars-lab-06-entry", "course-versions-minio"]
  affects: ["course-content/docs/labs/", "course-content/sidebars.ts", "course-code/COURSE_VERSIONS.md"]
tech_stack:
  added: ["minio-official/minio 5.4.0 documented", "quay.io/minio/mc:RELEASE.2024-11-21T17-21-54Z documented"]
  patterns: ["Docusaurus lab guide with OS Tabs", "Pattern A vs B comparison table", "initContainer pedagogy"]
key_files:
  created:
    - course-content/docs/labs/lab-06-disk-model-loading.md
  modified:
    - course-content/sidebars.ts
    - course-code/COURSE_VERSIONS.md
decisions:
  - "Used cut -d' ' -f1 for sha256 parsing (not awk) per prior wave finding that mc image lacks awk"
  - "Lab guide tells students to watch log output for sha256 verification; actual sha256 logic lives in the manifest"
  - "Part 4 re-download exercise uses pod delete (not scale to 0) to demonstrate emptyDir lifecycle explicitly"
metrics:
  duration_minutes: 2
  completed_date: "2026-06-15"
  tasks_completed: 2
  files_created: 1
  files_modified: 2
---

# Phase 03 Plan 04: Lab 06 Guide + Sidebar + Versions Summary

**One-liner:** Lab 06 disk-based model loading guide (323 lines) delivering PACKAGE-02 (Pattern B lab) and PACKAGE-03 (OCI vs disk decision page) with MinIO 5.4.0 sidebar entry and version table additions.

## Tasks Completed

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | Write Lab 06 lab guide (PACKAGE-02 + PACKAGE-03) | `6c9cbb9` | course-content/docs/labs/lab-06-disk-model-loading.md (323 lines) |
| 2 | Update sidebars.ts and COURSE_VERSIONS.md | `432a0b3` | course-content/sidebars.ts, course-code/COURSE_VERSIONS.md |

## What Was Built

### Task 1: Lab 06 Guide

`course-content/docs/labs/lab-06-disk-model-loading.md` (323 lines, sidebar_position: 7, Day 2 | ~60 minutes) with:

- **Learning Objectives** — 4 bullets covering MinIO install, model upload, Pattern B deploy, and decision criteria
- **Why Disk-Based Loading?** — conceptual framing contrasting Pattern A (OCI) vs Pattern B (MinIO + initContainer)
- **Prerequisites section** — cluster recreate warning for NodePorts 30203/30900/30901
- **Part 1: Install MinIO** — Helm repo add, namespace create, chart install with values file, rollout wait, health check, console access; demo-grade credential warning
- **Part 2: Upload Model** — model-uploader Job apply, Job wait, mc verify run; ClusterIP vs NodePort explanation
- **Part 3: Deploy Pattern B** — memory budget warning (scale Pattern A to 0), Service + Deployment apply, initContainer log watch, rollout wait, health + models API test, chat completion curl
- **Part 4: Observe Re-Download** — pod delete and re-watch initContainer to make emptyDir trade-off concrete; PVC alternative mentioned with Phase 06 forward reference
- **Part 5: Decision Guide** — 6-row comparison table (model size, update cadence, registry dependency, cold-start, credential management, production choice) + Choose Pattern A / Choose Pattern B bullet lists + closing context note

All commands use `<Tabs>` with macOS/Linux and Windows PowerShell variants, matching the existing lab-05 convention.

### Task 2: Sidebar + Versions

**sidebars.ts:** `'labs/lab-06-disk-model-loading'` added immediately after `'labs/lab-05-observability'` in the Labs category items array. No other entries changed.

**COURSE_VERSIONS.md:**
- `Last verified` updated to `2026-06-15 (v1.0.0 Phase 03)`
- New `## Object Storage (Phase 03+)` section added after Serving & Deployment with MinIO chart 5.4.0 row and mc RELEASE.2024-11-21T17-21-54Z row
- Notes section: added MinIO standalone install note with `mode=standalone` AND `replicas=1` requirement

## Deviations from Plan

None — plan executed exactly as written.

The RESEARCH.md code example for sha256 verification used `awk '{print $1}'` but the prior wave (03-03) correctly implemented `cut -d' ' -f1` in the manifest (mc image lacks awk). The lab guide does not show the internal script — students only see the expected log output — so no change to the guide was needed.

## Known Stubs

None. The lab guide references real manifests created in waves 03-02 and 03-03 that have been verified running on the live cluster.

## Threat Flags

None. Documentation-only changes; no new network endpoints, auth paths, or schema changes introduced.

## Self-Check: PASSED

- [x] `course-content/docs/labs/lab-06-disk-model-loading.md` exists (323 lines)
- [x] `sidebar_position: 7` present in frontmatter
- [x] All five Parts (1-5) present
- [x] Part 5 comparison table has 6 rows
- [x] Memory budget warning (scale Pattern A to 0) in Part 3
- [x] emptyDir re-download teaching moment in Part 4
- [x] Demo-grade credential warning (minio/minio123) in Part 1
- [x] Day 2 | Duration: ~60 minutes present
- [x] No emoji in file
- [x] `course-content/sidebars.ts` has `lab-06-disk-model-loading` after `lab-05-observability` (line 21 > line 20)
- [x] `course-code/COURSE_VERSIONS.md` has new Object Storage section with `minio-official/minio` 5.4.0 and mc RELEASE.2024-11-21T17-21-54Z
- [x] Commits `6c9cbb9` and `432a0b3` confirmed in git log
