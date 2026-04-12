---
phase: 01-course-infrastructure
plan: "04"
subsystem: infra
tags: [kind, kubernetes, cluster-setup, namespaces, bootstrap, version-pinning]

# Dependency graph
requires:
  - phase: 01-course-infrastructure/01-01
    provides: course-code repo skeleton with lab-00/starter and lab-00/solution directories

provides:
  - KIND cluster config YAML (starter with REPLACE_HOST_PATH, solution with working relative path)
  - bootstrap-kind.sh script creating 3-node cluster and applying namespaces
  - shared/k8s/namespaces.yaml defining 5 course namespaces
  - COURSE_VERSIONS.md pinning all 14+ course dependencies

affects:
  - all subsequent lab phases (depend on KIND cluster and namespaces)
  - lab-00 documentation (references these files)
  - preflight scripts (validates cluster created by bootstrap-kind.sh)

# Tech tracking
tech-stack:
  added:
    - KIND config v1alpha4 with dual ImageVolume feature gate pattern
    - 3-node cluster topology (1 control-plane + 2 workers)
    - kindest/node:v1.34.0 pinned node image
  patterns:
    - "Dual-gate pattern: ImageVolume enabled in BOTH kubeadmConfigPatches AND KubeletConfiguration"
    - "REPLACE_HOST_PATH placeholder in starter, relative ./llmops-project in solution"
    - "bootstrap-kind.sh detects placeholder and prompts user; substitutes via mktemp + sed"
    - "Generic namespace naming: llm-serving, llm-app (no domain branding in infrastructure)"

key-files:
  created:
    - course-code/labs/lab-00/starter/setup/kind-config.yaml
    - course-code/labs/lab-00/solution/setup/kind-config.yaml
    - course-code/labs/lab-00/starter/scripts/bootstrap-kind.sh
    - course-code/labs/lab-00/solution/scripts/bootstrap-kind.sh
    - course-code/shared/k8s/namespaces.yaml
    - course-code/COURSE_VERSIONS.md
  modified: []

key-decisions:
  - "REPLACE_HOST_PATH appears exactly 3 times in starter (one per node extraMounts) — comment reworded to avoid inflating count"
  - "Solution kind-config uses ./llmops-project relative path — works on macOS and Windows Git Bash when run from repo root"
  - "Bootstrap script uses mktemp + sed to substitute path into temp config — avoids modifying the tracked config file"
  - "bootstrap-kind.sh is identical for starter and solution — path substitution logic works regardless of which config it reads"
  - "COURSE_VERSIONS.md covers 14 components across 5 categories with compatibility reasons, 58 lines"

patterns-established:
  - "Dual ImageVolume gate: kubeadmConfigPatches (API server + controller-manager + scheduler) AND KubeletConfiguration.featureGates"
  - "Port mapping standard: 30000 (Prometheus), 32000 (Grafana/ArgoCD), 8000 (vLLM), 80/443 (HTTP/HTTPS), 30080 (Chainlit), 30090 (ArgoCD)"
  - "Namespace labels: course=llmops + purpose={function} for all course namespaces"
  - "COURSE_VERSIONS.md format: Component | Pinned Version | Compatibility Reason per component category"

requirements-completed: [INFRA-04, K8S-01, K8S-02]

# Metrics
duration: 4min
completed: "2026-04-12"
---

# Phase 01 Plan 04: KIND Cluster Setup Summary

**3-node KIND cluster config with dual ImageVolume feature gates, bootstrap script with REPLACE_HOST_PATH substitution, 5-namespace manifest, and 14-component COURSE_VERSIONS.md**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-04-12T06:36:26Z
- **Completed:** 2026-04-12T06:39:51Z
- **Tasks:** 2
- **Files created:** 6

## Accomplishments

- KIND config YAML created for both starter (REPLACE_HOST_PATH placeholder) and solution (working relative path) with dual ImageVolume gate pattern that prevents silent volume failures (Pitfall 1)
- bootstrap-kind.sh auto-detects placeholder config and prompts student for path; substitutes into temp file and creates 3-node cluster then applies namespaces in one run
- shared/k8s/namespaces.yaml defines exactly 5 namespaces (llm-serving, llm-app, monitoring, argocd, argo-workflows) with no old domain branding
- COURSE_VERSIONS.md pins 14+ dependencies across Core Infrastructure, ML/LLM Stack, Serving, Web UI, and Docs categories with compatibility rationale for each

## Task Commits

Each task was committed atomically:

1. **Task 1: KIND config YAML files** - `e14c371` (feat)
2. **Task 2: bootstrap script, namespaces, COURSE_VERSIONS** - `414e4fc` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified

- `course-code/labs/lab-00/starter/setup/kind-config.yaml` - 3-node KIND config template with REPLACE_HOST_PATH in all node extraMounts and dual ImageVolume gates
- `course-code/labs/lab-00/solution/setup/kind-config.yaml` - Working KIND config with ./llmops-project relative path and dual ImageVolume gates
- `course-code/labs/lab-00/starter/scripts/bootstrap-kind.sh` - Bootstrap script with REPLACE_HOST_PATH detection, path prompt, mktemp substitution, cluster creation, and namespace apply
- `course-code/labs/lab-00/solution/scripts/bootstrap-kind.sh` - Identical copy of bootstrap script (works for both starter and solution configs)
- `course-code/shared/k8s/namespaces.yaml` - 5 Namespace objects with course/purpose labels
- `course-code/COURSE_VERSIONS.md` - 58-line version table covering all major course dependencies

## Decisions Made

- Bootstrap script uses `mktemp + sed` substitution into temp file rather than modifying the tracked YAML — this preserves the placeholder in the committed config while allowing cluster creation with a concrete path
- Solution kind-config uses `./llmops-project` relative path (not `/Users/gshah`) — relative paths work on both macOS and Windows Git Bash when running from the repo root
- Starter comment about the placeholder was reworded to avoid including `REPLACE_HOST_PATH` literally in the comment, ensuring `grep -c "REPLACE_HOST_PATH"` returns exactly 3 (one per node)
- Bootstrap script is identical for both starter and solution — no need for divergent maintenance

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Minor: `grep -c "REPLACE_HOST_PATH"` returned 4 (3 in extraMounts + 1 in the comment). Fixed by rewording the comment to not literally repeat the placeholder text. Acceptance criteria requires count of 3 (one per node).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Lab 00 has complete cluster setup infrastructure: KIND config (starter + solution), bootstrap script, namespaces
- COURSE_VERSIONS.md provides version reference for all subsequent lab implementations
- Plan 05 (lab cleanup scripts or final infra plan) can proceed immediately
- All files verified: no personal paths, no old namespace names, dual ImageVolume gate in place

---
*Phase: 01-course-infrastructure*
*Completed: 2026-04-12*
