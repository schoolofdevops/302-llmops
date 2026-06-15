---
phase: 02-modernize-llmops-spine-labs-00-05
plan: "02"
subsystem: course-structure
tags: [doc-restructure, lab-renumber, sidebars, docusaurus, kind-config, code-dirs]
dependency_graph:
  requires: []
  provides:
    - kind-config.yaml with NodePorts 30200/30300/30400/30500
    - 6 lab code dirs (lab-00..lab-05) with lab-04 holding vLLM+Chainlit and lab-05 holding observability
    - 6 doc pages (lab-00..lab-05) with correct sidebar_position values
    - sidebars.ts with 6 new lab IDs
    - Docusaurus build passing with onBrokenLinks throw
  affects:
    - course-content/docs/labs/ (all 6 lab pages)
    - course-content/sidebars.ts
    - course-code/labs/ (6 dirs after merge/rename)
    - course-code/labs/lab-00/*/setup/kind-config.yaml
tech_stack:
  added: []
  patterns:
    - MDX comments use {/* */} not <!-- --> (MDX parser rejects HTML comments)
    - git mv preserves blame history for renamed doc pages
key_files:
  created:
    - course-content/docs/labs/lab-01-synthetic-data-and-rag.md
    - course-content/docs/labs/lab-05-observability.md
  modified:
    - course-code/labs/lab-00/solution/setup/kind-config.yaml
    - course-code/labs/lab-00/starter/setup/kind-config.yaml
    - course-content/docs/labs/lab-02-finetuning.md
    - course-content/docs/labs/lab-03-model-packaging.md
    - course-content/docs/labs/lab-04-serving-and-ui.md
    - course-content/sidebars.ts
  deleted:
    - course-content/docs/labs/lab-01-synthetic-data.md (content merged into lab-01-synthetic-data-and-rag.md)
    - course-content/docs/labs/lab-02-rag-retriever.md (content merged into lab-01-synthetic-data-and-rag.md)
    - course-content/docs/labs/lab-03-finetuning.md (renamed to lab-02-finetuning.md)
    - course-content/docs/labs/lab-04-model-packaging.md (renamed to lab-03-model-packaging.md)
    - course-content/docs/labs/lab-05-model-serving.md (renamed to lab-04-serving-and-ui.md, Part A of lab-06 merged in)
    - course-content/docs/labs/lab-06-web-ui.md (split: Part A -> lab-04, Part B -> lab-05-observability.md)
decisions:
  - MDX comments ({/* */}) required instead of HTML comments (<!-- -->) for Docusaurus MDX parser compatibility
  - D-18 and D-19 placeholders inserted as MDX comments at end of lab-03-model-packaging.md and lab-04-serving-and-ui.md
  - git mv used for all renames to preserve history; lab-05-observability.md tracked as 61% rename from lab-06-web-ui.md
metrics:
  duration: ~45 minutes
  completed: "2026-06-15"
  tasks_completed: 3
  files_changed: 16
---

# Phase 02 Plan 02: Lab Structure Modernization — Summary

**One-liner:** Merged 7 lab pages into 6, restructured code dirs from lab-06 to lab-05, added KIND NodePorts for Day 1 services, and verified Docusaurus build green.

## Task 1: GAP-1 — NodePort fix to kind-config.yaml (commit c8ca319)

Added four extraPortMappings to the KIND control-plane node in both `solution/` and `starter/` trees:

```yaml
  - containerPort: 30200   # vLLM API
    hostPort: 30200
    listenAddress: "0.0.0.0"
    protocol: tcp
  - containerPort: 30300   # Chainlit UI
    hostPort: 30300
    listenAddress: "0.0.0.0"
    protocol: tcp
  - containerPort: 30400   # Grafana
    hostPort: 30400
    listenAddress: "0.0.0.0"
    protocol: tcp
  - containerPort: 30500   # Prometheus
    hostPort: 30500
    listenAddress: "0.0.0.0"
    protocol: tcp
```

All 9 pre-existing port mappings (30000, 32000, 8000, 80, 443, 30080, 30090, 30100, 31001) preserved. YAML validated parseable.

## Task 2: Code Dir Restructure (commit 6df1c20)

**Before:**
```
course-code/labs/
  lab-00/  lab-01/  lab-02/  lab-03/  lab-04/  lab-05/  lab-06/
```

**After:**
```
course-code/labs/
  lab-00/  lab-01/  lab-02/  lab-03/  lab-04/  lab-05/
```

Changes:
- Chainlit content (k8s/40-* + ui/) moved from `lab-05/` into `lab-04/` (both solution/ and starter/)
- `lab-06/` renamed to `lab-05/` (observability: kube-prometheus-stack scripts + ServiceMonitors + Grafana dashboard CM)
- lab-04 now holds: k8s/30-deploy-vllm.yaml, k8s/30-svc-vllm.yaml, k8s/40-deploy-chainlit.yaml, k8s/40-svc-chainlit.yaml, scripts/test-vllm.sh, ui/
- lab-05 now holds: k8s/observability/50-*.yaml, scripts/install-monitoring.sh, scripts/generate-traffic*.sh

## Task 3: Doc Page Restructure (commit e7fdbb7)

**Before (7 pages):**
| Old file | sidebar_position |
|----------|-----------------|
| lab-00-cluster-setup.md | 1 |
| lab-01-synthetic-data.md | 2 |
| lab-02-rag-retriever.md | 3 |
| lab-03-finetuning.md | 4 |
| lab-04-model-packaging.md | 5 |
| lab-05-model-serving.md | 6 |
| lab-06-web-ui.md | 7 |

**After (6 pages):**
| New file | sidebar_position | Source |
|----------|-----------------|--------|
| lab-00-cluster-setup.md | 1 | unchanged |
| lab-01-synthetic-data-and-rag.md | 2 | merged lab-01 + lab-02 |
| lab-02-finetuning.md | 3 | renamed from lab-03 |
| lab-03-model-packaging.md | 4 | renamed from lab-04 |
| lab-04-serving-and-ui.md | 5 | renamed lab-05 + Part A of lab-06 |
| lab-05-observability.md | 6 | Part B of lab-06 |

### sidebars.ts before/after

Before:
```typescript
items: [
  'labs/lab-00-cluster-setup',
  'labs/lab-01-synthetic-data',
  'labs/lab-02-rag-retriever',
  'labs/lab-03-finetuning',
  'labs/lab-04-model-packaging',
  'labs/lab-05-model-serving',
  'labs/lab-06-web-ui',
],
```

After:
```typescript
items: [
  'labs/lab-00-cluster-setup',
  'labs/lab-01-synthetic-data-and-rag',
  'labs/lab-02-finetuning',
  'labs/lab-03-model-packaging',
  'labs/lab-04-serving-and-ui',
  'labs/lab-05-observability',
],
```

### Cross-reference updates

- lab-02-finetuning.md: "Continue to Lab 04" → "Continue to Lab 03"
- lab-03-model-packaging.md: "Continue to Lab 05" → "Continue to Lab 04"; "merge step in Lab 03" → "merge step in Lab 02"
- lab-04-serving-and-ui.md: "Lab 06" references updated; metrics section note updated to "Lab 05 will scrape"
- lab-05-observability.md: all code paths use `course-code/labs/lab-05/solution` (correct for observability)
- Internal lab references in lab-01 "Continue to Lab 02" updated to reference new lab numbering

### Docusaurus build result

```
[INFO] [en] Creating an optimized production build...
[SUCCESS] Generated static files in "build".
[INFO] Use `npm run serve` command to test your build locally.
```

Exit 0. onBrokenLinks: throw enforced — no dangling sidebar references or broken links.

## Deviations from Plan

**1. [Rule 1 - Bug] MDX comment syntax fix**
- **Found during:** Task 3, Docusaurus build verification
- **Issue:** D-18 and D-19 placeholders were inserted as HTML comments (`<!-- -->`). MDX parser rejects HTML comments with: "Unexpected character `!` (U+0021) before name"
- **Fix:** Converted to MDX comment syntax: `{/* D-18 PATTERN-A TEASER PLACEHOLDER ... */}` and `{/* D-19 PATTERN-A TEASER PLACEHOLDER ... */}`
- **Files modified:** course-content/docs/labs/lab-03-model-packaging.md, course-content/docs/labs/lab-04-serving-and-ui.md
- **Commit:** e7fdbb7 (same Task 3 commit)

Note: The D-18/D-19 grep checks in the plan's automated verify block look for the string "D-18 PATTERN-A TEASER PLACEHOLDER" and "D-19 PATTERN-A TEASER PLACEHOLDER" — these strings are present in both files within MDX comment syntax.

## Git Commit SHAs

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 (GAP-1 NodePort fix) | c8ca319 | fix(02-02): add NodePorts 30200/30300/30400/30500 to kind-config.yaml |
| Task 2 (code dir restructure) | 6df1c20 | refactor(02-02): merge Chainlit (lab-05) into lab-04; rename lab-06 -> lab-05 |
| Task 3 (doc page restructure) | e7fdbb7 | docs(02-02): merge labs 01+02 doc pages, split lab-06 into lab-04/lab-05 |

## Self-Check: PASSED

- course-content/docs/labs/lab-01-synthetic-data-and-rag.md: FOUND
- course-content/docs/labs/lab-02-finetuning.md: FOUND
- course-content/docs/labs/lab-03-model-packaging.md: FOUND
- course-content/docs/labs/lab-04-serving-and-ui.md: FOUND
- course-content/docs/labs/lab-05-observability.md: FOUND
- course-content/sidebars.ts updated: VERIFIED
- Commits c8ca319, 6df1c20, e7fdbb7: FOUND in git log
- Docusaurus build: PASSED (exit 0)
- D-18 placeholder in lab-03-model-packaging.md: FOUND
- D-19 placeholder in lab-04-serving-and-ui.md: FOUND
