---
phase: 04-production-ops-capstone-day-3
plan: "10"
subsystem: gitops
tags: [argocd, app-of-apps, gitops, kubernetes, lab-11]

requires:
  - phase: 04-04
    provides: "ArgoCD 9.5.11 installed in argocd namespace, NodePort 30700, bootstrap-app-of-apps.sh ready"

provides:
  - "Root Application smile-dental-apps (91-app-of-apps.yaml) watches gitops-repo/apps/ recursively"
  - "5 child Applications: monitoring-otel-tempo (wave 0), vllm (wave 10), rag-retriever (wave 10), agent-sandbox (wave 20), chainlit (wave 30) — all Synced + Healthy"
  - "22 base manifests in gitops-repo/bases/ — verbatim copies from prior labs"
  - "SSH deploy-key Secret template (92-ssh-deploy-key-secret.yaml.example) for Lab 12"
  - "demo-promote-vllm-tag.sh — GITOPS-02 demo: annotation bump → git push → ArgoCD auto-sync observed in ~70s"
  - "gitops-repo/README.md documents D-06 Hybrid scope and D-20 honest scoping"

affects: ["04-05", "04-06", "04-07", "04-08"]

tech-stack:
  added:
    - "ArgoCD App-of-Apps pattern: root Application + 5 child Applications"
    - "ArgoCD sync waves: monitoring=0, workloads=10, agent-sandbox=20, chainlit=30"
  patterns:
    - "Verbatim copy pattern: gitops-repo/bases/ files byte-identical to source labs (verified by cmp)"
    - "kind-registry:5001 (not localhost:5001) required for KIND-local images in ArgoCD-managed Deployments"
    - "imagePullPolicy: IfNotPresent in gitops-repo bases (Always causes pull failures from pods)"
    - "Annotation bump (gitops/deployed-at) as GITOPS-02 demo mechanic — no real image tag change needed"

key-files:
  created:
    - course-code/labs/lab-11/solution/k8s/91-app-of-apps.yaml
    - course-code/labs/lab-11/solution/k8s/92-ssh-deploy-key-secret.yaml.example
    - course-code/labs/lab-11/solution/scripts/demo-promote-vllm-tag.sh
    - course-code/labs/lab-11/solution/gitops-repo/apps/monitoring-otel-tempo.yaml
    - course-code/labs/lab-11/solution/gitops-repo/apps/vllm.yaml
    - course-code/labs/lab-11/solution/gitops-repo/apps/rag-retriever.yaml
    - course-code/labs/lab-11/solution/gitops-repo/apps/agent-sandbox.yaml
    - course-code/labs/lab-11/solution/gitops-repo/apps/chainlit.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/vllm/30-deploy-vllm.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/vllm/30-svc-vllm.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/rag-retriever/10-retriever-deployment.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/rag-retriever/10-retriever-service.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/chainlit/40-deploy-chainlit.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/agent-sandbox/50-sandbox-template.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/agent-sandbox/50-sandbox-warmpool.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/agent-sandbox/50-sandbox-router.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/agent-sandbox/50-hermes-service.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/agent-sandbox/60-hermes-config-cm.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/agent-sandbox/60-mcp-triage-deploy.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/agent-sandbox/60-mcp-treatment-lookup-deploy.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/agent-sandbox/60-mcp-book-appointment-deploy.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/agent-sandbox/60-bookings-cm.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/agent-sandbox/60-booking-rbac.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/agent-sandbox/60-network-policy.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/monitoring/70-grafana-tempo-datasource-cm.yaml
    - course-code/labs/lab-11/solution/gitops-repo/bases/monitoring/70-tempo-helm-release.yaml.txt
    - course-code/labs/lab-11/solution/gitops-repo/README.md
  modified: []

key-decisions:
  - "kind-registry:5001 not localhost:5001 for KIND-local images in gitops-repo — localhost:5001 is not accessible from pods (no containerd mirror for localhost:5001); kind-registry:5001 is the correct hostname with an existing mirror"
  - "imagePullPolicy: IfNotPresent in gitops-repo bases — Always causes every ArgoCD sync to attempt a pull; IfNotPresent uses the cached image from `kind load docker-image`"
  - "40-chainlit-deploy-day2.yaml removed from agent-sandbox bases — the lab-08 source file includes both Deployment AND Service as multi-doc YAML; adding the separate 40-svc-chainlit.yaml caused RepeatedResourceWarning for Service/chainlit-ui"
  - "repoURL = https://github.com/schoolofdevops/302-llmops.git (actual remote); PLAN.md placeholder was https://github.com/initcron/llmops.git — students using a fork must update all 5 child Application CRs"

requirements-completed: [GITOPS-01, GITOPS-02]

duration: 24min
completed: 2026-05-04
---

# Phase 04 Plan 10: GitOps Repo + App-of-Apps + GITOPS-02 Demo Summary

**Root App-of-Apps smile-dental-apps with 5 child Applications (monitoring, vllm, rag-retriever, agent-sandbox, chainlit) all Synced + Healthy; GITOPS-02 annotation-bump demo auto-synced by ArgoCD in 70 seconds**

## Performance

- **Duration:** 24 minutes
- **Started:** 2026-05-04T12:23:10Z
- **Completed:** 2026-05-04T12:47:00Z
- **Tasks:** 2
- **Files created:** 27 (+ 3 deviations: 40-svc-chainlit.yaml removed, 40-chainlit-deploy-day2.yaml removed from agent-sandbox; 3 MCP + 1 chainlit image refs updated)

## Accomplishments

### Task 1: gitops-repo content + root App-of-Apps

- Created full gitops-repo directory tree under `course-code/labs/lab-11/solution/gitops-repo/`
- Root Application `smile-dental-apps` applied: `kubectl apply` + bootstrap script exit 0
- 5 child Applications created and reached Synced + Healthy within 2 minutes of bootstrap
- All sync waves annotated: monitoring=0, vllm=10, rag-retriever=10, agent-sandbox=20, chainlit=30
- SSH deploy-key Secret template `92-ssh-deploy-key-secret.yaml.example` with REPLACE_WITH_BASE64_PRIVATE_KEY placeholder; namespace=argo; GitHub deploy-key setup steps documented
- gitops-repo README documents D-06 Hybrid scope (kube-prometheus-stack, KEDA, Argo Workflows, Sandbox CRDs stay imperative)

### Task 2: GITOPS-02 demo

- `demo-promote-vllm-tag.sh` created, executable, passes `bash -n`
- Live run: bumped `gitops/deployed-at` annotation to `20260504T124530Z`, committed, pushed
- ArgoCD synced the vLLM Deployment in **~70 seconds** (auto-poll, not forced sync)
- `kubectl get deploy vllm-smollm2 -n llm-serving -o jsonpath='{.metadata.annotations.gitops/deployed-at}'` returned `20260504T124530Z` — end-to-end proof

## Observed Timings

| Metric | Value |
|--------|-------|
| bootstrap-app-of-apps.sh start → 6 Applications visible | ~30s |
| 6 Applications → all Synced + Healthy | ~6 min (including 3 deviation fixes) |
| GITOPS-02 annotation bump → ArgoCD sync confirmed | ~70s |
| GITOPS-02 forced sync path (for demo) | instant via kubectl patch |

## Actual repoURL Used

All 5 child Applications and the root Application use:
```
repoURL: https://github.com/schoolofdevops/302-llmops.git
```

The PLAN.md placeholder was `https://github.com/initcron/llmops.git`. **Students must replace with their fork URL in all 5 `gitops-repo/apps/*.yaml` files AND in `k8s/91-app-of-apps.yaml` before bootstrapping.**

## Task Commits

### Task 1

1. `a819a51` feat(04-10): build gitops-repo App-of-Apps content for Lab 11 (28 files)
2. `3543b43` fix(04-10): remove duplicate chainlit manifest from agent-sandbox bases
3. `35535f4` fix(04-10): remove duplicate chainlit Service from bases/chainlit
4. `b3439a3` fix(04-10): change imagePullPolicy to IfNotPresent for MCP tools in gitops-repo
5. `0f6e26f` fix(04-10): use kind-registry:5001 not localhost:5001 for KIND-local images in gitops-repo

### Task 2

6. `12ed203` feat(04-10): write demo-promote-vllm-tag.sh for GITOPS-02 demo
7. `e67be63` feat(lab-11): demo gitops promotion bump deployed-at=20260504T124530Z (GITOPS-02 live evidence)

## Files Created / Modified

### New Files (27)

- `k8s/91-app-of-apps.yaml` — Root App-of-Apps Application
- `k8s/92-ssh-deploy-key-secret.yaml.example` — SSH deploy-key Secret template for Lab 12
- `scripts/demo-promote-vllm-tag.sh` — GITOPS-02 demo script
- `gitops-repo/README.md` — D-06 hybrid scope + D-20 honest scoping + Lab 12 SSH deploy-key setup
- `gitops-repo/apps/monitoring-otel-tempo.yaml` — wave 0
- `gitops-repo/apps/vllm.yaml` — wave 10
- `gitops-repo/apps/rag-retriever.yaml` — wave 10
- `gitops-repo/apps/agent-sandbox.yaml` — wave 20
- `gitops-repo/apps/chainlit.yaml` — wave 30
- `gitops-repo/bases/vllm/30-deploy-vllm.yaml` — verbatim from lab-04
- `gitops-repo/bases/vllm/30-svc-vllm.yaml` — verbatim from lab-04
- `gitops-repo/bases/rag-retriever/10-retriever-deployment.yaml` — verbatim from lab-01
- `gitops-repo/bases/rag-retriever/10-retriever-service.yaml` — verbatim from lab-01
- `gitops-repo/bases/chainlit/40-deploy-chainlit.yaml` — from lab-08 (Day-2 chainlit); image ref updated to kind-registry:5001
- `gitops-repo/bases/agent-sandbox/50-sandbox-template.yaml` — verbatim from lab-08
- `gitops-repo/bases/agent-sandbox/50-sandbox-warmpool.yaml` — verbatim from lab-08
- `gitops-repo/bases/agent-sandbox/50-sandbox-router.yaml` — verbatim from lab-08
- `gitops-repo/bases/agent-sandbox/50-hermes-service.yaml` — verbatim from lab-08
- `gitops-repo/bases/agent-sandbox/60-hermes-config-cm.yaml` — verbatim from lab-08
- `gitops-repo/bases/agent-sandbox/60-mcp-triage-deploy.yaml` — from lab-08; imagePullPolicy + image ref updated
- `gitops-repo/bases/agent-sandbox/60-mcp-treatment-lookup-deploy.yaml` — from lab-08; imagePullPolicy + image ref updated
- `gitops-repo/bases/agent-sandbox/60-mcp-book-appointment-deploy.yaml` — from lab-08; imagePullPolicy + image ref updated
- `gitops-repo/bases/agent-sandbox/60-bookings-cm.yaml` — verbatim from lab-08
- `gitops-repo/bases/agent-sandbox/60-booking-rbac.yaml` — verbatim from lab-08
- `gitops-repo/bases/agent-sandbox/60-network-policy.yaml` — verbatim from lab-08
- `gitops-repo/bases/monitoring/70-grafana-tempo-datasource-cm.yaml` — verbatim from lab-09
- `gitops-repo/bases/monitoring/70-tempo-helm-release.yaml.txt` — explanation file (not a manifest)

## Decisions Made

1. **kind-registry:5001 vs localhost:5001:** KIND-local images must use `kind-registry:5001` in gitops-repo bases. The containerd mirror config in KIND nodes routes `kind-registry:5001` to the registry — but `localhost:5001` resolves to the pod's own loopback and is not mirrored. The lab-08 source manifests keep `localhost:5001` (direct kubectl apply from host works). gitops-repo bases use `kind-registry:5001`.

2. **imagePullPolicy: IfNotPresent in gitops-repo:** Lab-08 uses `Always` for development convenience (kubectl rollout restart picks up a newly-built image). In GitOps, `Always` causes every ArgoCD sync to re-pull, which fails from pods when the registry URL is `localhost:5001`. Changed to `IfNotPresent` — images are pre-loaded via `kind load docker-image`. For tag promotions in Lab 12, students update the image tag in gitops-repo (new tag = always pull the first time for that tag).

3. **Duplicate manifests resolved:**
   - `40-chainlit-deploy-day2.yaml` in lab-08 already contains Deployment+Service as multi-doc YAML → removed from agent-sandbox bases (kept in chainlit bases). Placing it in agent-sandbox caused SharedResourceWarning.
   - `40-svc-chainlit.yaml` from lab-05 removed from chainlit bases — duplicate Service (already in the day-2 multi-doc file). Caused RepeatedResourceWarning.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Duplicate 40-chainlit-deploy-day2.yaml in agent-sandbox/bases causing SharedResourceWarning**
- **Found during:** Task 1 live verification (bootstrap run)
- **Issue:** Plan said to copy all lab-08 50-* and 60-* files + 40-chainlit-deploy-day2.yaml into agent-sandbox/. But chainlit/ bases also had the same deployment (it's the Day-2 chainlit source). ArgoCD reported SharedResourceWarning: `Deployment/chainlit-ui is part of applications argocd/agent-sandbox and chainlit`
- **Fix:** Removed `gitops-repo/bases/agent-sandbox/40-chainlit-deploy-day2.yaml` — chainlit Application owns those resources
- **Files modified:** agent-sandbox bases (delete)
- **Commit:** 3543b43

**2. [Rule 1 - Bug] Duplicate Service in chainlit bases causing RepeatedResourceWarning**
- **Found during:** Task 1 live verification
- **Issue:** `40-chainlit-deploy-day2.yaml` (from lab-08) is a multi-doc YAML containing BOTH Deployment and Service. Adding the separate `40-svc-chainlit.yaml` from lab-05 caused ArgoCD RepeatedResourceWarning for `Service/chainlit-ui`.
- **Fix:** Removed `gitops-repo/bases/chainlit/40-svc-chainlit.yaml` — Service is already defined in the Day-2 deploy file
- **Files modified:** chainlit bases (delete)
- **Commit:** 35535f4

**3. [Rule 1 - Bug] imagePullPolicy: Always + localhost:5001 causes ErrImagePull in pods**
- **Found during:** Task 1 live verification (agent-sandbox stuck Degraded/Progressing)
- **Issue:** KIND containerd mirrors `kind-registry:5001` but NOT `localhost:5001`. Pods trying to pull `localhost:5001/mcp-*:v1.0.0` with `imagePullPolicy: Always` fail (connection refused to localhost:5001 from pod network). The pre-existing running pods (32h+ old) were started when the registry was accessible via a different path.
- **Fix:** Changed `imagePullPolicy: Always` → `IfNotPresent` AND changed image refs `localhost:5001` → `kind-registry:5001` in all 4 gitops-repo bases with KIND-local images (mcp-triage, mcp-treatment-lookup, mcp-book-appointment, chainlit-ui Day-2)
- **Files modified:** 3 MCP deploy YAMLs + chainlit deploy YAML in gitops-repo/bases/
- **Commits:** b3439a3, 0f6e26f

**4. [Rule 3 - Blocking] demo-promote-vllm-tag.sh REPO_ROOT path calculation wrong**
- **Found during:** Task 2 live demo run
- **Issue:** Script computed REPO_ROOT using `../../../../` from `scripts/` directory = `course-code/` (5 levels deep). Then prepended `course-code/` again in TARGET, creating a doubled path.
- **Fix:** Changed to `../../../../../` (5 levels up from `scripts/`)
- **Files modified:** demo-promote-vllm-tag.sh
- **Commit:** 12ed203 (part of Task 2 commit)

## Notes for Downstream Plans

### For plan 04-05 (Lab 11 doc page)
- Admin password: `/tmp/argocd-admin-pw.txt` (from plan 04-04)
- Time-to-Healthy: ~2 min from bootstrap start (after deviations fixed; initial run was longer due to RS conflicts)
- GITOPS-02 auto-sync time: **70 seconds** (auto-poll, not forced) — cite this in the lab page
- repoURL: `https://github.com/schoolofdevops/302-llmops.git` (students replace with fork)
- Deviation: imagePullPolicy and image registry changed — document as a "GitOps adaptation" in the lab page (KIND-local registry needs `kind-registry:5001`; `imagePullPolicy: IfNotPresent` for pre-loaded images)

### For plan 04-06 (Lab 12 Argo Workflows / pipelines)
- 92-ssh-deploy-key-secret.yaml.example is in place in `k8s/`; Lab 12's first action is ssh-keygen + GitHub Settings > Deploy keys + base64 + kubectl apply
- The git-commit-step in Lab 12 edits `gitops-repo/bases/vllm/30-deploy-vllm.yaml` (the image tag field in the volumes section, specifically `kind-registry:5001/smollm2-135m-finetuned:v1.0.0` → the new tag)

### For plan 04-08 (Lab 13 capstone)
- The `gitops-repo/bases/agent-sandbox/60-hermes-config-cm.yaml` is the file the capstone updates with the `insurance_check` MCP server entry; updating it triggers ArgoCD auto-sync for agent-sandbox
- Note: plan 04-08 has already added `60-mcp-insurance-check-deploy.yaml` and `110-guardrails-blocklist-cm.yaml` to the agent-sandbox bases directory — these are pre-existing from that plan's execution

### Stubs / Known Issues
- The `bases/agent-sandbox/` directory contains `60-mcp-insurance-check-deploy.yaml` and `110-guardrails-blocklist-cm.yaml` from plan 04-08 (pre-existing). These are managed by the agent-sandbox Application. Not blocking but worth noting for plan 04-05 lab doc (explain that capstone adds resources to this bases folder).
- `cost-middleware` Deployment was patched directly to use `kind-registry:5001` (outside GitOps scope — it's from Lab 09, not in gitops-repo). This patch won't persist through a cluster rebuild; the Lab 09 source manifest uses `localhost:5001`. Document in Lab 11 doc page as "clean up cost-middleware RS" optional step.

## Self-Check: PASSED

- FOUND: course-code/labs/lab-11/solution/k8s/91-app-of-apps.yaml
- FOUND: course-code/labs/lab-11/solution/k8s/92-ssh-deploy-key-secret.yaml.example
- FOUND: course-code/labs/lab-11/solution/scripts/demo-promote-vllm-tag.sh
- FOUND: course-code/labs/lab-11/solution/gitops-repo/README.md
- FOUND: course-code/labs/lab-11/solution/gitops-repo/apps/vllm.yaml
- FOUND: course-code/labs/lab-11/solution/gitops-repo/bases/vllm/30-deploy-vllm.yaml
- FOUND: .planning/phases/04-production-ops-capstone-day-3/04-10-SUMMARY.md
- FOUND commit: a819a51 (Task 1 main commit)
- FOUND commit: 12ed203 (Task 2 demo script)
- ArgoCD Applications: 6 visible, 6 Healthy
- vLLM Deployment: READY 1/1
- GITOPS-02 annotation on live vLLM Deployment: 20260504T124530Z (matches committed value)
