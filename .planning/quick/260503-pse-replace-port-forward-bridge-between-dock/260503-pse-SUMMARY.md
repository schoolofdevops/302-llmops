---
phase: 260503-pse-replace-port-forward-bridge-between-dock
plan: 01
subsystem: course-infrastructure
tags: [course-infra, kind, networking, lab-07, day-2-ux]
requires: []
provides:
  - "rag-retriever NodePort 31001 exposed declaratively via KIND extraPortMappings"
  - "Lab 07 mcp-treatment-lookup → rag-retriever bridge with no kubectl port-forward terminal"
affects:
  - "course-code/labs/lab-00 KIND configs (starter+solution): added 31001 entry, preserved 30100"
  - "course-code/labs/lab-01 retriever Service (starter+solution): nodePort moved 30100 → 31001"
  - "course-code/labs/lab-07 docker-compose: default RETRIEVER_URL → host.docker.internal:31001"
  - "course-code/labs/lab-06 generate-traffic-full.sh (solution): default RETRIEVER_PORT → 31001"
  - "course-content/docs/labs/lab-02-rag-retriever.md: verification curls + recap"
  - "course-content/docs/labs/lab-06-web-ui.md: traffic-script invocation, expected-output, recap"
  - "course-content/docs/labs/lab-07-agent-core.md: prereq, prose, callouts, recap, tear-down"
tech-stack:
  added: []
  patterns:
    - "Declarative cross-network bridge: KIND extraPortMappings + Service NodePort + docker-compose env default — no long-running kubectl port-forward process"
key-files:
  created: []
  modified:
    - "course-code/labs/lab-00/solution/setup/kind-config.yaml"
    - "course-code/labs/lab-00/starter/setup/kind-config.yaml"
    - "course-code/labs/lab-01/solution/k8s/10-retriever-service.yaml"
    - "course-code/labs/lab-01/starter/k8s/10-retriever-service.yaml"
    - "course-code/labs/lab-07/solution/docker-compose.yaml"
    - "course-code/labs/lab-06/solution/scripts/generate-traffic-full.sh"
    - "course-content/docs/labs/lab-02-rag-retriever.md"
    - "course-content/docs/labs/lab-06-web-ui.md"
    - "course-content/docs/labs/lab-07-agent-core.md"
decisions:
  - "REPURPOSE not RENAME: kept the existing 30100 KIND host port mapping in both kind-config.yaml files (reserved for future use); added 31001 as a new entry alongside it. Only the rag-retriever Service nodePort and the docs that name the retriever's external port moved to 31001."
  - "Documentation port unification: lab-02 verification (4 curls + recap), lab-06 traffic snippet (invocation + expected output + recap), and lab-07 (prereq, prose, callouts, recap, tear-down) all reference 31001 — single port number across the public docs."
metrics:
  duration: "~15min"
  completed: "2026-05-03"
---

# Quick Task 260503-pse: Replace port-forward bridge between Docker Compose and KIND retriever — Summary

**One-liner:** Replaced the fragile `kubectl port-forward svc/rag-retriever 8001:8001` Lab 07 prereq with a declarative NodePort 31001 + KIND `extraPortMappings` bridge, so Day-2 learners no longer need to keep a long-running terminal open.

## Objective Achieved

Lab 07's most common live-class friction point on Day 2 — "I lost my port-forward, treatment_lookup is empty, what now?" — is gone. The Day-1 RAG retriever is now reachable from the Docker Compose stack (`mcp-treatment-lookup`) via `host.docker.internal:31001`, exposed declaratively by:

1. **KIND**: `extraPortMappings` entry `containerPort: 31001 → hostPort: 31001` on the control-plane node (added alongside the preserved 30100 entry).
2. **Kubernetes**: `rag-retriever` Service `nodePort: 31001` in the `llm-app` namespace.
3. **Docker Compose**: `mcp-treatment-lookup` default env `RETRIEVER_URL=http://host.docker.internal:31001`.

No `kubectl port-forward` instruction remains anywhere in the live course content for the rag-retriever bridge.

## Tasks Completed

| Task | Name                                                                       | Commit  | Key files                                                                                                                                                                              |
| ---- | -------------------------------------------------------------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | Add NodePort 31001 to KIND configs, retriever Service, compose, traffic    | ad6e026 | lab-00 kind-config (starter+solution), lab-01 10-retriever-service.yaml (starter+solution), lab-07 docker-compose.yaml, lab-06 generate-traffic-full.sh (solution)                     |
| 2    | Update Lab 07 page — drop port-forward prereq, refresh callouts/table       | 4795597 | course-content/docs/labs/lab-07-agent-core.md                                                                                                                                          |
| 3    | Update Lab 02 + Lab 06 docs to NodePort 31001 + final repo-wide sweep      | f04a7fc | course-content/docs/labs/lab-02-rag-retriever.md, course-content/docs/labs/lab-06-web-ui.md                                                                                            |

## Verification Evidence

**Static config consistency (all `yq` queries returned the expected values):**

```text
# KIND port mapping (control-plane node, both starter and solution)
{ "containerPort": 31001, "hostPort": 31001, "listenAddress": "0.0.0.0", "protocol": "tcp" }

# rag-retriever Service nodePort (starter and solution): 31001

# docker-compose mcp-treatment-lookup RETRIEVER_URL default: "${RETRIEVER_URL:-http://host.docker.internal:31001}"
```

**Stale-reference sweep (in-scope):**

```bash
rg "30100|port-forward.*rag-retriever|host.docker.internal:8001" \
  --glob '!llmops-labuide/**' --glob '!.planning/**' \
  --glob '!course-content/docs/labs/lab-08-agent-sandbox.md' \
  --glob '!course-content/docs/labs/lab-09-observability.md' \
  --glob '!course-code/labs/lab-08/**' --glob '!course-code/labs/lab-09/**' \
  --glob '!course-code/labs/lab-00/**'
# → 0 matches (rg exit 1)
```

**Without the lab-00 exclusion** the sweep returns exactly 4 lines — the four `30100` lines for the preserved KIND port mapping (control-plane `containerPort: 30100` and `hostPort: 30100` in starter and solution), which is intentional per the locked repurposing decision.

## Deviations from Plan

### Out-of-scope artifacts noted

**1. [Rule 3 - Blocking missing file] `course-code/labs/lab-06/starter/scripts/generate-traffic-full.sh` does not exist**

- **Found during:** Task 1 (file enumeration before edit).
- **Issue:** The plan's Task 1 file list and Task 1d action both reference `course-code/labs/lab-06/starter/scripts/generate-traffic-full.sh`, but `course-code/labs/lab-06/starter/scripts/` only contains `install-monitoring.sh`. There is no starter version of the traffic generator script — only the solution version exists.
- **Fix:** Edited only the solution version (`course-code/labs/lab-06/solution/scripts/generate-traffic-full.sh`). Did not create a starter copy because (a) the plan does not require one to exist and (b) creating new starter content is out of scope for a quick task focused on porting an existing port. The lab-06 page (`course-content/docs/labs/lab-06-web-ui.md`) only ever invokes the solution path, so the starter directory is irrelevant to the migration.
- **Files modified:** None additional.
- **Commit:** ad6e026 (Task 1).

No other deviations. The locked repurposing decision was honored: 30100 remains in the lab-00 KIND configs alongside the new 31001 entry — neither file had its 30100 block touched.

## Authentication Gates

None — fully static config + docs change.

## Known Stubs

None. The Lab 07 prereq still includes a fallback instruction to re-run `bootstrap-kind.sh` if the cluster was created before the 31001 mapping was added; that is a documented recovery step, not a stub.

## Out-of-Scope Confirmation

- **`llmops-labuide/`**: untouched (legacy MkDocs guide, intentionally out of scope).
- **`.planning/`**: history preserved; only the new quick-task SUMMARY in `.planning/quick/260503-pse-…/` was written.
- **`course-code/labs/lab-08/**` and `course-code/labs/lab-09/**`**: untouched. The `kubectl port-forward` references in those labs (KServe `inferenceservice`, Tempo, cost-middleware) target different services and are not part of the rag-retriever bridge being replaced.
- **Lab 00 30100 KIND mapping**: preserved verbatim in both starter and solution per the locked repurposing decision.

## Self-Check: PASSED

**Files exist:**
- FOUND: course-code/labs/lab-00/solution/setup/kind-config.yaml
- FOUND: course-code/labs/lab-00/starter/setup/kind-config.yaml
- FOUND: course-code/labs/lab-01/solution/k8s/10-retriever-service.yaml
- FOUND: course-code/labs/lab-01/starter/k8s/10-retriever-service.yaml
- FOUND: course-code/labs/lab-07/solution/docker-compose.yaml
- FOUND: course-code/labs/lab-06/solution/scripts/generate-traffic-full.sh
- FOUND: course-content/docs/labs/lab-02-rag-retriever.md
- FOUND: course-content/docs/labs/lab-06-web-ui.md
- FOUND: course-content/docs/labs/lab-07-agent-core.md

**Commits exist on `main`:**
- FOUND: ad6e026 (Task 1 — config + manifest + compose + traffic script)
- FOUND: 4795597 (Task 2 — Lab 07 page)
- FOUND: f04a7fc (Task 3 — Lab 02 + Lab 06 pages)

**Verification block (plan):**
- yq probes for `extraPortMappings[containerPort==31001]` (×2), `Service.nodePort` (×2), and `docker-compose.RETRIEVER_URL` returned the expected values.
- Stale-reference sweep with the lab-00 KIND exclusion returned **zero matches** for `30100|port-forward.*rag-retriever|host.docker.internal:8001`.

(Optional live smoke test from the plan — `kubectl get svc rag-retriever … nodePort` + `curl localhost:31001/health` + `docker compose exec mcp-treatment-lookup` — was not executed because the cluster is not currently running. The plan explicitly marks the live smoke test as "not part of the automated verify because the cluster may not be running; the static checks are sufficient to merge the doc + config change.")
