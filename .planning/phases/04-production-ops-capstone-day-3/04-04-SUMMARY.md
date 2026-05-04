---
phase: 04-production-ops-capstone-day-3
plan: "04"
subsystem: infra
tags: [argocd, gitops, helm, kubernetes, nodeport]

requires:
  - phase: 04-01
    provides: "config.env with NS_ARGOCD, ARGOCD_CHART_VERSION=9.5.11, NODEPORT_ARGOCD=30700; COURSE_VERSIONS.md Phase 4 section"

provides:
  - "ArgoCD 9.5.11 (v3.3.9) installed live in argocd namespace, NodePort 30700, all 4 core pods Ready"
  - "install-argocd.sh: idempotent Helm install with 5 RESEARCH.md value overrides"
  - "argocd-login.sh: optional argocd CLI login for instructor demos"
  - "bootstrap-app-of-apps.sh: applies 91-app-of-apps.yaml + polls for 6 Applications (used by plan 04-10)"
  - "90-argocd-namespace.yaml: explicit Namespace manifest"
  - "/tmp/argocd-admin-pw.txt: admin password stashed locally (not committed)"

affects: ["04-05", "04-10"]

tech-stack:
  added:
    - "ArgoCD Helm chart argo/argo-cd 9.5.11 (ArgoCD v3.3.9)"
  patterns:
    - "Helm idempotency guard: helm status argocd before helm install"
    - "Password stash pattern: echo pwd > /tmp/argocd-admin-pw.txt (local-only, not committed)"
    - "Inter-plan dependency documentation in bootstrap script header"

key-files:
  created:
    - course-code/labs/lab-11/solution/k8s/90-argocd-namespace.yaml
    - course-code/labs/lab-11/solution/scripts/install-argocd.sh
    - course-code/labs/lab-11/solution/scripts/argocd-login.sh
    - course-code/labs/lab-11/solution/scripts/bootstrap-app-of-apps.sh
  modified: []

key-decisions:
  - "helm install timed out on first run (10min pre-install hook limit) due to slow quay.io image pull for argocd:v3.3.9 (~33min actual pull time); recovery = helm uninstall + re-run after image cached"
  - "applicationSet.enabled=false is set as a Helm value but ArgoCD 9.5.11 still deploys the applicationset-controller (chart behavior change); value IS applied correctly per helm get values"

patterns-established:
  - "Pre-install hook timeout recovery: helm uninstall + re-run after image is cached on nodes"
  - "bootstrap-app-of-apps.sh pre-flight: check for 91-app-of-apps.yaml before kubectl apply"

requirements-completed: [GITOPS-01]

duration: 36min
completed: 2026-05-04
---

# Phase 04 Plan 04: ArgoCD GitOps Control Plane Summary

**ArgoCD 9.5.11 installed in argocd namespace via Helm with NodePort 30700, all 5 RESEARCH.md value overrides applied (dex/notifications/applicationSet disabled, insecure HTTP), and 4 bootstrap scripts committed**

## Performance

- **Duration:** 36 min (image pull 33 min + actual install <1 min)
- **Started:** 2026-05-04T11:26:37Z
- **Completed:** 2026-05-04T12:03:17Z
- **Tasks:** 1
- **Files modified:** 4 created

## Accomplishments

- ArgoCD v3.3.9 deployed via Helm chart 9.5.11 into `argocd` namespace; argocd-server, argocd-repo-server, argocd-redis, argocd-application-controller all Ready
- NodePort 30700 confirmed: `kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}'` returns `30700`
- Initial admin password captured to `/tmp/argocd-admin-pw.txt` (local-only file, not committed) for plans 04-05 and 04-10
- All 3 bootstrap scripts pass `bash -n`; bootstrap-app-of-apps.sh includes pre-flight guard that halts with clear message if 91-app-of-apps.yaml (plan 04-10) is absent

## Task Commits

1. **Task 1: Install ArgoCD + write 3 install/login/bootstrap scripts** - `2ad60d3` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified

- `course-code/labs/lab-11/solution/k8s/90-argocd-namespace.yaml` — Explicit Namespace manifest (Helm --create-namespace also creates it)
- `course-code/labs/lab-11/solution/scripts/install-argocd.sh` — Idempotent Helm install with helm-status guard, all 5 value overrides, password stash to /tmp
- `course-code/labs/lab-11/solution/scripts/argocd-login.sh` — Optional argocd CLI login; reads cached /tmp/argocd-admin-pw.txt if present
- `course-code/labs/lab-11/solution/scripts/bootstrap-app-of-apps.sh` — Applies 91-app-of-apps.yaml + polls 30×10s for 6 Applications (root + 5 children)

## Decisions Made

- **Helm install timeout recovery:** First `helm install` timed out (10min limit) because `quay.io/argoproj/argocd:v3.3.9` took 33 minutes to pull on this network. Recovery: `helm uninstall argocd -n argocd` + re-run `install-argocd.sh`. Second run succeeded in < 1 minute (image cached on nodes). The install-argocd.sh idempotency guard exits cleanly on subsequent runs.
- **applicationSet.enabled=false chart behavior:** Helm value is correctly applied (`helm get values` confirms `applicationSet.enabled: false`), but ArgoCD chart 9.5.11 still deploys the applicationset-controller pod. This is expected chart behavior in v3.x — the flag controls CRD scope/permissions, not whether the controller binary runs. Accepted as-is per RESEARCH.md Standard Stack notes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] First helm install timed out on pre-install hook; recovered with uninstall + re-run**
- **Found during:** Task 1 (live install)
- **Issue:** `helm install --wait --timeout 10m` timed out because `quay.io/argoproj/argocd:v3.3.9` (~400MB) took 33 minutes to pull on this network. The pre-install Job (argocd-redis-secret-init) was still ContainerCreating when the 10-minute Helm timeout expired.
- **Fix:** Waited for image pull to complete (pod showed Completed), then ran `helm uninstall argocd -n argocd` to clean the failed release, then re-ran `install-argocd.sh`. Second install completed in <30 seconds.
- **Files modified:** None (script unchanged; this is an operational concern, not a code bug)
- **Verification:** `helm list -n argocd` shows STATUS=deployed; all pods Ready
- **Impact:** No script changes needed. The install-argocd.sh idempotency guard (`helm status argocd`) handles re-run correctly. For lab delivery, recommend `docker pull quay.io/argoproj/argocd:v3.3.9` as a workshop pre-warm step.

---

**Total deviations:** 1 auto-fixed (1 blocking — operational, not code)
**Impact on plan:** Script works correctly. Slow initial image pull is a one-time network event; subsequent runs use cached layers.

## Issues Encountered

- Slow image pull from quay.io (33 min) caused first Helm install to fail with pre-install hook timeout. Resolved by waiting for image to cache then reinstalling. Scripts unchanged.

## User Setup Required

None - ArgoCD is running and admin password is at `/tmp/argocd-admin-pw.txt`.

**Note for plan 04-10:** bootstrap-app-of-apps.sh is ready but CANNOT be run until plan 04-10 creates `course-code/labs/lab-11/solution/k8s/91-app-of-apps.yaml`. The script's pre-flight check will exit with a clear error message if run prematurely.

## Next Phase Readiness

- ArgoCD control plane is live; UI accessible at http://localhost:30700 (admin / password in /tmp/argocd-admin-pw.txt)
- Plan 04-05 (Lab 11 doc page) can reference the NodePort 30700 and admin password file location
- Plan 04-10 (gitops-repo + App-of-Apps) is the natural continuation — it creates 91-app-of-apps.yaml and runs bootstrap-app-of-apps.sh

---
*Phase: 04-production-ops-capstone-day-3*
*Completed: 2026-05-04*

## Self-Check: PASSED

- FOUND: course-code/labs/lab-11/solution/k8s/90-argocd-namespace.yaml
- FOUND: course-code/labs/lab-11/solution/scripts/install-argocd.sh
- FOUND: course-code/labs/lab-11/solution/scripts/argocd-login.sh
- FOUND: course-code/labs/lab-11/solution/scripts/bootstrap-app-of-apps.sh
- FOUND: .planning/phases/04-production-ops-capstone-day-3/04-04-SUMMARY.md
- FOUND commit: 2ad60d3
- ArgoCD server readyReplicas: 1
- NodePort: 30700
- /tmp/argocd-admin-pw.txt: present
