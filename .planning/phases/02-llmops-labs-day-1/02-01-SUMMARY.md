---
phase: 02-llmops-labs-day-1
plan: "01"
subsystem: infra
tags: [vllm, config, docker-image, course-versions]

# Dependency graph
requires: []
provides:
  - Corrected VLLM_IMAGE in config.env pointing to official vllm/vllm-openai-cpu:v0.19.0-x86_64
  - Updated COURSE_VERSIONS.md with consistent vLLM row and arm64 variant note
  - KServe row updated to reflect Phase 2 does not use KServe
affects: [02-02, 02-03, 02-04, 02-05, 02-06, 02-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "config.env VLLM_IMAGE uses official vllm/vllm-openai-cpu image family going forward"
    - "COURSE_VERSIONS.md notes both x86_64 and arm64 variants for cross-platform clarity"

key-files:
  created: []
  modified:
    - course-code/config.env
    - course-code/COURSE_VERSIONS.md

key-decisions:
  - "Use official vllm/vllm-openai-cpu:v0.19.0-x86_64 image (abandoned schoolofdevops/vllm-cpu-nonuma:0.9.1 image removed)"
  - "KServe marked N/A for Phase 2 labs — plain K8s Deployment used per D-10"

patterns-established:
  - "config.env VLLM_IMAGE comment pattern: note x86_64 vs arm64 variant choice for learners"

requirements-completed: [SERVE-01, SERVE-02]

# Metrics
duration: 1min
completed: 2026-04-23
---

# Phase 02 Plan 01: Fix vLLM Image Reference Summary

**Replaced abandoned schoolofdevops/vllm-cpu-nonuma:0.9.1 with official vllm/vllm-openai-cpu:v0.19.0-x86_64 in config.env and COURSE_VERSIONS.md**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-04-23T09:02:40Z
- **Completed:** 2026-04-23T09:03:33Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- config.env VLLM_IMAGE now references the official CPU image that students can actually pull
- COURSE_VERSIONS.md vLLM row is internally consistent (version number and image tag both say v0.19.0)
- KServe row updated to reflect it is not used in Phase 2 Day 1 labs (plain K8s Deployment)
- Notes section updated to remove all schoolofdevops references
- Added arm64 variant comment for Apple Silicon users

## Task Commits

Each task was committed atomically:

1. **Task 1: Update config.env with correct vLLM image** - `56733f5` (fix)
2. **Task 2: Fix COURSE_VERSIONS.md vLLM row** - `acc20c1` (fix)

**Plan metadata:** (docs commit below)

## Files Created/Modified
- `course-code/config.env` - VLLM_IMAGE updated to official image + arm64 comment added
- `course-code/COURSE_VERSIONS.md` - vLLM table row corrected; KServe marked N/A for Phase 2; Notes updated

## Decisions Made
- Used official `vllm/vllm-openai-cpu` image family (v0.19.0-x86_64 for Intel/AMD, v0.19.0-arm64 for Apple Silicon) — the previous `schoolofdevops/vllm-cpu-nonuma:0.9.1` is abandoned and will fail on docker pull

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Updated Notes section in COURSE_VERSIONS.md**
- **Found during:** Task 2 (Fix COURSE_VERSIONS.md vLLM row)
- **Issue:** The Notes section at bottom of COURSE_VERSIONS.md still referenced the abandoned schoolofdevops image with incorrect rationale ("NUMA-capable hardware" claim). This would confuse students using the official image.
- **Fix:** Updated the Notes bullet to reference the official vllm/vllm-openai-cpu images and mention both x86_64 and arm64 variants.
- **Files modified:** course-code/COURSE_VERSIONS.md
- **Verification:** `grep schoolofdevops COURSE_VERSIONS.md` returns no matches
- **Committed in:** acc20c1 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical — Notes section cleanup)
**Impact on plan:** Necessary for consistency; no scope creep.

## Issues Encountered
None — straightforward string replacements with clear verification.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- config.env is now the correct central config for all subsequent lab YAML manifests
- All plans in 02-llmops-labs-day-1 that `source config.env` and use `$VLLM_IMAGE` will pull the correct image
- No blockers for 02-02 and beyond

---
*Phase: 02-llmops-labs-day-1*
*Completed: 2026-04-23*
