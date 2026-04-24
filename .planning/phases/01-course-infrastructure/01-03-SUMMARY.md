---
phase: 01-course-infrastructure
plan: "03"
subsystem: infra
tags: [bash, powershell, preflight, docker, kind, kubectl, helm, cross-platform]

# Dependency graph
requires:
  - phase: 01-01
    provides: course-code repo skeleton with lab-00/starter/ and lab-00/solution/ directories

provides:
  - "preflight-check.sh — bash preflight for macOS/Linux/Git Bash with Docker, tools, ports, stale KIND cluster checks"
  - "preflight-check.ps1 — PowerShell mirror with Test-NetConnection, Get-Command, docker system info"
  - "test-preflight-check.sh — 14-test bash test suite validating preflight script behavior"

affects: [lab-00-content, student-setup-guide, prerequisites-doc]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bash strict mode (#!/usr/bin/env bash + set -euo pipefail) for all course shell scripts"
    - "pass()/warn()/fail() counter pattern with summary exit-code pattern for preflight scripts"
    - "docker system info --format '{{.MemTotal}}' for Docker memory detection"
    - "Memory threshold: fail <8GB, warn 8-12GB, pass >=12GB"
    - "TDD for bash scripts: test-preflight-check.sh verifies behavior before and after implementation"

key-files:
  created:
    - "course-code/labs/lab-00/starter/scripts/preflight-check.sh"
    - "course-code/labs/lab-00/solution/scripts/preflight-check.sh"
    - "course-code/labs/lab-00/starter/scripts/preflight-check.ps1"
    - "course-code/labs/lab-00/solution/scripts/preflight-check.ps1"
    - "course-code/labs/lab-00/starter/scripts/test-preflight-check.sh"
  modified: []

key-decisions:
  - "Starter and solution scripts are identical — no REPLACE placeholders in scripts, only in lab guide files"
  - "Memory warn threshold: 8-12GB (warn not fail) because this machine runs 9.7GB — students at minimum 8GB can still proceed"
  - "Disk check uses df -BG on Docker root dir; falls back to Warn if detection fails (avoids false failures)"
  - "TDD applied to bash script: test-preflight-check.sh with 14 tests (structural + functional)"

patterns-established:
  - "Pattern: preflight scripts use [PASS]/[WARN]/[FAIL] prefix on every output line"
  - "Pattern: Preflight summary line format: '==> Preflight summary: N passed, N warnings, N failed'"
  - "Pattern: Exit 1 if FAIL > 0; warnings are non-blocking"
  - "Pattern: PowerShell script uses $script:Pass/Warn/Fail scope for counter functions"

requirements-completed: [INFRA-03, K8S-03]

# Metrics
duration: 2min
completed: "2026-04-12"
---

# Phase 01 Plan 03: Preflight Scripts Summary

**Cross-platform environment validation scripts: bash preflight-check.sh (macOS/Linux/Git Bash) and PowerShell preflight-check.ps1 (Windows), both checking Docker memory, required tools, port availability, and stale KIND clusters**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-12T06:32:03Z
- **Completed:** 2026-04-12T06:34:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Bash preflight script with strict mode, [PASS]/[WARN]/[FAIL] output, Docker memory warn-not-fail at 8-12GB, stale cluster detection, exit code based on fail count
- PowerShell preflight script mirroring all bash checks using native Windows cmdlets (Test-NetConnection, Get-Command, docker system info)
- TDD bash test suite (14 tests) validating structural and functional correctness
- Identical files in both starter/ and solution/ directories (4 script files total)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create bash preflight script (preflight-check.sh)** - `263bddd` (feat + test — TDD RED/GREEN)
2. **Task 2: Create PowerShell preflight script (preflight-check.ps1)** - `74c542c` (feat)

**Plan metadata:** `3657c21` (docs: complete preflight scripts plan)

_Note: Task 1 used TDD — test-preflight-check.sh written first (RED), then preflight-check.sh written to make tests pass (GREEN)._

## Files Created/Modified

- `course-code/labs/lab-00/starter/scripts/preflight-check.sh` - Cross-platform bash preflight (macOS/Linux/Git Bash)
- `course-code/labs/lab-00/solution/scripts/preflight-check.sh` - Identical copy in solution directory
- `course-code/labs/lab-00/starter/scripts/preflight-check.ps1` - Native Windows PowerShell preflight
- `course-code/labs/lab-00/solution/scripts/preflight-check.ps1` - Identical copy in solution directory
- `course-code/labs/lab-00/starter/scripts/test-preflight-check.sh` - 14-test bash test suite (TDD)

## Decisions Made

- **Starter = Solution for scripts:** No REPLACE placeholders in scripts (only in lab guide markdown). Both directories get identical content. Simplifies maintenance.
- **Memory warn threshold at 8GB:** This machine runs 9.7GB allocated. Warn between 8-12GB, fail below 8GB — students at 8GB minimum can proceed Lab 00 but may hit memory pressure in later resource-heavy labs.
- **Disk check fallback to Warn:** `df -BG` on Docker root may fail on some systems (e.g., Docker Desktop VM path). Falls back to Warn rather than false-failing.
- **TDD for bash:** Applied test-preflight-check.sh with 14 tests covering shebang, strict mode, required patterns, functional behavior, port checks, and memory thresholds.

## Deviations from Plan

None — plan executed exactly as written. Scripts match the provided full implementation from the plan exactly.

## Issues Encountered

None. Script ran successfully on first attempt: 10 PASS, 2 WARN (Docker memory 9GB = borderline warn, disk check = fallback warn), 0 FAIL, exit 0.

## Known Stubs

None — scripts are fully functional with no placeholders.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- preflight-check.sh is ready to be referenced in Lab 00 setup instructions and the Docusaurus prerequisites page
- preflight-check.ps1 mirrors all checks for Windows students
- Scripts in starter/ are what students run; solution/ copies confirm no hidden differences
- Lab 00 cluster setup content (plan 01-04) can now reference these scripts

---
*Phase: 01-course-infrastructure*
*Completed: 2026-04-12*
