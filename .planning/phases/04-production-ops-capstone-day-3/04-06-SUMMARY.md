---
phase: 04
plan: 06
subsystem: lab-12-eval-pipeline
tags: [argo-workflows, deepeval, faithfulness-metric, groq, tdd, quality-gate, eval-02]
dependency_graph:
  requires: [04-01]
  provides: [lab-12-solution, argo-workflows-cluster, deepeval-container, eval-02-gate]
  affects: [course-lab-guide-lab-12]
tech_stack:
  added:
    - deepeval==3.9.9 (FaithfulnessMetric, DeepEvalBaseLLM)
    - openai>=1.0.0 (Groq OpenAI-compat endpoint wrapper)
    - httpx>=0.28.0 (vLLM query)
    - pytest==8.3.3 (unit test suite)
    - argo-workflows helm chart 1.0.13 (server v4.0.5, NodePort 30800)
  patterns:
    - TDD RED-GREEN cycle for LLM judge integration code
    - deepeval_local package naming to avoid PyPI name collision
    - Argo DAG with output parameter quality gate (when: clause)
    - Sequential eval with sleep rate-limit guard (Groq 30 RPM free tier)
    - Shared PVC /workspace replaces MinIO/S3 (Pitfall 5)
    - Explicit command: in step template (Pitfall — emissary HTTP registry)
    - argo-workflow ServiceAccount with Role for Secret get (Pitfall 10)
    - sys.exit(0) always from eval step so Argo reads output parameter
key_files:
  created:
    - course-code/labs/lab-12/solution/deepeval_local/__init__.py
    - course-code/labs/lab-12/solution/deepeval_local/groq_judge.py
    - course-code/labs/lab-12/solution/deepeval_local/run_eval.py
    - course-code/labs/lab-12/solution/deepeval/Dockerfile
    - course-code/labs/lab-12/solution/deepeval/pytest.ini
    - course-code/labs/lab-12/solution/deepeval/requirements.txt
    - course-code/labs/lab-12/solution/deepeval/test_groq_judge.py
    - course-code/labs/lab-12/solution/deepeval/test_run_eval.py
    - course-code/labs/lab-12/solution/eval/eval-set.jsonl
    - course-code/labs/lab-12/solution/scripts/dry-run-eval.sh
    - course-code/labs/lab-12/solution/scripts/install-argo-workflows.sh
    - course-code/labs/lab-12/solution/scripts/trigger-pipeline.sh
    - course-code/labs/lab-12/solution/k8s/100-argo-workflows-rbac.yaml
    - course-code/labs/lab-12/solution/k8s/100-pvc-pipeline-workspace.yaml
    - course-code/labs/lab-12/solution/k8s/100-secret-llm-api-keys.yaml.example
    - course-code/labs/lab-12/solution/k8s/101-workflowtemplate-llm-pipeline.yaml
    - course-code/labs/lab-12/solution/k8s/102-workflow-llm-pipeline-run.yaml
    - course-code/labs/lab-12/solution/.gitignore
  modified: []
decisions:
  - "deepeval_local package name chosen to avoid shadowing installed PyPI deepeval package when local deepeval/ test folder is on sys.path"
  - "sys.exit(0) always from eval step — Argo emissary requires exit 0 to read output parameters for when: conditional; eval pass/fail conveyed via OUT_PATH file content"
  - "Explicit command: [python, -m, deepeval_local.run_eval] in step-eval template — Argo emissary executor cannot inspect HTTP-only kind-registry:5001 for image entrypoint"
  - "step-commit-tag uses python:3.11-slim not alpine — BusyBox lacks python3 for heredoc git annotation injection; apt-get installs git + openssh-client at runtime"
  - "addopts = -p no:deepeval in pytest.ini disables deepeval pytest plugin import error when running tests outside container"
  - "FAIL path demo (threshold=0.99): eval pass=false -> commit-tag Skipped -> no git push -> EVAL-02 quality gate proven"
metrics:
  duration: ~150min
  completed_date: "2026-05-04"
  tasks_completed: 2
  files_created: 18
---

# Phase 04 Plan 06: Lab 12 DeepEval Pipeline + Argo Workflows Summary

**One-liner:** DeepEvalBaseLLM Groq judge with FaithfulnessMetric + 6-step Argo DAG implementing EVAL-02 quality gate (`when: eval.pass == true`) verified via live FAIL-path workflow run.

## Tasks Completed

### Task 1: TDD DeepEval Container (TDD)

**Commit:** `97b8bbf`

**RED phase** — wrote 8 failing tests before any implementation:

- `test_groq_judge.py` (4 tests): init_reads_env_vars, generate_returns_content, generate_uses_temperature_0_1, get_model_name
- `test_run_eval.py` (4 tests): pass writes true, fail writes false, respects sleep, stub vLLM path used

**GREEN phase** — implemented to pass all 8 tests:

- `deepeval_local/groq_judge.py`: `DeepEvalBaseLLM` subclass wrapping Groq OpenAI-compat endpoint (`LLM_BASE_URL`, `GROQ_API_KEY`, `LLM_MODEL` env vars); `temperature=0.1`, `max_tokens=1024`; both sync `generate()` and async `a_generate()` implemented
- `deepeval_local/run_eval.py`: `FaithfulnessMetric` runner; sequential with `time.sleep(2.0)` between cases (Groq 30 RPM free-tier guard); writes `true`/`false` to OUT_PATH; `sys.exit(0)` always
- `eval/eval-set.jsonl`: 12 handcrafted Smile Dental Q&A cases covering root canal, hours, walk-in policy, Aetna/Cigna/MaxBupa insurance, Invisalign, crowns, cleanings, extractions
- `deepeval/Dockerfile`: builds `smile-dental-deepeval:v1.0.0` from solution/ build context; copies `deepeval_local/` and `eval/eval-set.jsonl`; ENTRYPOINT `python -m deepeval_local.run_eval`
- `scripts/dry-run-eval.sh`: 5-case dry-run validates Groq rate-limit math (RESEARCH.md Open Q4 closed)

**Test result:** 8/8 pass. Image built and `kind load docker-image` into llmops-kind cluster.

### Task 2: Argo Workflows + 6-Step DAG WorkflowTemplate

**Commit:** `164ac67`

**Argo Workflows install:**
- Helm chart `argo/argo-workflows` version 1.0.13 (server v4.0.5)
- Namespace: `argo`, NodePort: `30800`, auth mode: server
- `install-argo-workflows.sh`: idempotent with `helm status` guard

**K8s manifests applied to cluster:**
- `100-argo-workflows-rbac.yaml`: ServiceAccount `argo-workflow` + Role granting `get` on `llm-api-keys` and `git-deploy-key` Secrets (Pitfall 10 fix)
- `100-pvc-pipeline-workspace.yaml`: 5Gi ReadWriteOnce PVC `pipeline-workspace` — shared `/workspace` eliminates MinIO/S3 dependency (Pitfall 5)
- `100-secret-llm-api-keys.yaml.example`: template for copying Groq API key to `argo` namespace

**WorkflowTemplate `llm-pipeline`** (6-step DAG):

```
data-gen (noop) -> train (noop) -> merge (noop) -> package (noop) -> eval (real) -> commit-tag (real, conditional)
```

- Steps 1-4: `step-noop` with echo messages (lab demo short-circuit; Lab 02 artifacts reused)
- Step 5 (`step-eval`): `smile-dental-deepeval:v1.0.0` image; GROQ_API_KEY from Secret; explicit `command:` (emissary HTTP registry fix); writes `/tmp/eval-pass.txt`; output parameter `pass` reads from that path
- Step 6 (`commit-tag`): `when: "{{tasks.eval.outputs.parameters.pass}} == true"` implements EVAL-02 gate; uses `python:3.11-slim` + `apt-get git openssh-client`; SSH deploy key mount from `git-deploy-key` Secret; bumps `gitops/model-version` annotation then `git push`

**EVAL-02 Live Demo (FAIL path):**

Workflow `llm-pipeline-bnkg5` run with `threshold=0.99`:
- eval step: Succeeded (exit 0), `pass=false` (all 12 cases scored 0.0 — empty GROQ_API_KEY → 401 errors)
- commit-tag step: Skipped (`when: false`)
- Workflow overall: Succeeded
- Gate proven: no git push, vLLM unchanged

**PASS path** requires `git-deploy-key` Secret (from Lab 11 plan 04-04) — deferred pending parallel agent completion.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] deepeval PyPI package shadowed by local `deepeval/` folder**
- Found during: Task 1 (RED phase)
- Issue: Local `deepeval/__init__.py` made the test folder a Python package named `deepeval`, causing `from deepeval.models import DeepEvalBaseLLM` to fail with `ImportError`
- Fix: Removed `__init__.py` from `deepeval/` test folder so pytest treats it as a plain directory; added `addopts = -p no:deepeval` to `pytest.ini` to suppress deepeval's broken pytest plugin
- Files modified: `deepeval/pytest.ini` (created)

**2. [Rule 1 - Bug] `reload()` inside `patch()` context escapes the patch**
- Found during: Task 1 (GREEN phase — test_run_eval.py)
- Issue: Original pattern `with patch(...): reload(run_eval); run_eval.run(...)` failed because `reload()` re-imported the real `FaithfulnessMetric`, escaping the mock context
- Fix: Changed to direct module attribute substitution: `reload(mod); orig = mod.FaithfulnessMetric; mod.FaithfulnessMetric = StubClass; try: mod.run(...); finally: mod.FaithfulnessMetric = orig`
- Files modified: `deepeval/test_run_eval.py`

**3. [Rule 1 - Bug] Argo emissary cannot inspect HTTP-only kind-registry entrypoint**
- Found during: Task 2 (live WorkflowTemplate run)
- Issue: Error `failed to look-up entrypoint/cmd for image "kind-registry:5001/smile-dental-deepeval:v1.0.0"... http: server gave HTTP response to HTTPS client`
- Fix: Added `command: [python, -m, deepeval_local.run_eval]` explicitly to `step-eval` template
- Files modified: `k8s/101-workflowtemplate-llm-pipeline.yaml`

**4. [Rule 1 - Bug] eval step exits 1 on fail → Argo marks step Error → output parameter unreadable**
- Found during: Task 2 (FAIL path demo)
- Issue: `sys.exit(0 if ok else 1)` caused Argo to mark eval step as Error (not Succeeded) when threshold not met; output parameter was then unavailable for `when:` clause on commit-tag
- Fix: Changed to `sys.exit(0)` with comment explaining semantics; pass/fail conveyed via file content only
- Files modified: `deepeval_local/run_eval.py` (also noted in parallel agent commit c8835b5)

**5. [Rule 3 - Blocking] Argo Workflows Helm install timed out first attempt**
- Found during: Task 2 (install phase)
- Issue: CRD install job pulled `registry.k8s.io/kubectl:v1.36.0` slowly; 5m timeout hit; namespace stuck Terminating
- Fix: Force-deleted pods, removed namespace finalizers via raw API call, reinstalled with `--timeout 10m`; second attempt succeeded after image cached

## Known Stubs

**Stub 1:** `step-commit-tag` in `101-workflowtemplate-llm-pipeline.yaml` — the `commit-tag` step contains a placeholder `git@github.com:initcron/llmops.git` for the companion repo SSH URL. Students must change this to their own fork per the `TODO` comment in the template. This is intentional — correct repo URL is student-specific.

**Stub 2:** PASS path end-to-end not demonstrated — requires `git-deploy-key` Secret in `argo` namespace from Lab 11 (plan 04-04). The `when:` gate logic is proven via FAIL path. PASS path verification deferred to lab guide authoring (plan 04-08).

## Self-Check: PASSED

Created files verified:
- `/Users/gshah/courses/llmops/course-code/labs/lab-12/solution/deepeval_local/groq_judge.py` — FOUND
- `/Users/gshah/courses/llmops/course-code/labs/lab-12/solution/deepeval_local/run_eval.py` — FOUND
- `/Users/gshah/courses/llmops/course-code/labs/lab-12/solution/eval/eval-set.jsonl` — FOUND (12 lines)
- `/Users/gshah/courses/llmops/course-code/labs/lab-12/solution/k8s/101-workflowtemplate-llm-pipeline.yaml` — FOUND
- `/Users/gshah/courses/llmops/course-code/labs/lab-12/solution/k8s/100-argo-workflows-rbac.yaml` — FOUND
- `/Users/gshah/courses/llmops/course-code/labs/lab-12/solution/scripts/trigger-pipeline.sh` — FOUND

Commits verified:
- `97b8bbf` — FOUND (feat: TDD DeepEval container)
- `164ac67` — FOUND (feat: Argo Workflows + WorkflowTemplate)
- `bda639f` — FOUND (chore: .gitignore for lab-12)
