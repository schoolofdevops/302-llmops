---
sidebar_position: 13
---

# Lab 12: Pipelines + Eval Gate

**Day 3 | Duration: ~50 minutes**

{/* Lab 12 — Argo Workflows DAG + DeepEval Faithfulness gate.
    D-11 short-circuit early steps (workshop time); D-12 handcrafted eval set;
    D-13 single threshold; D-14 git-commit-step writes new tag to gitops sub-folder.
    Satisfies GITOPS-03 (DAG), EVAL-01 (DeepEval), EVAL-02 (gate). */}

## Learning Objectives

By the end of this lab you will:

- Install Argo Workflows chart 1.0.13 (server v4.0.5) into namespace `argo` with NodePort UI on `:30800`
- Build a DeepEval container that runs `FaithfulnessMetric` against a 12-item handcrafted Smile Dental eval set, using Groq llama-3.3-70b-versatile as the LLM judge
- Define a 6-step DAG WorkflowTemplate: data-gen → train → merge → package → eval → commit-tag
- Use Argo Workflows' `when:` clause to gate the commit-tag step on the eval step's output parameter — a quality gate, not a logging step
- See the gate work in **both directions**: PASS → commit + ArgoCD sync; FAIL → commit-tag skipped, vLLM unchanged

## Prerequisites

- Lab 11 completed:
  - ArgoCD installed; `kubectl get applications -n argocd` shows the Healthy children
  - Lab 11 **Part E completed** — `git-deploy-key` Secret exists in `argo` namespace (`kubectl get secret git-deploy-key -n argo`)
- Day 2 leftovers:
  - `llm-api-keys` Secret exists in `llm-agent` namespace (Lab 08); Lab 12 copies it to `argo`
  - `vllm-smollm2` Deployment is at replicas=1 in `llm-serving` (re-confirm: Lab 10 Part A scaled it back up)
- Free-tier API:
  - `GROQ_API_KEY` set in your shell or in the `llm-api-keys` Secret (Groq is the default judge per D-13)

:::warning Eval rate-limit reality (Open Q4)
The DeepEval `FaithfulnessMetric` makes **2 LLM calls per test case** (claim extraction + verification). With 12 eval items that's 24 calls. The `run_eval.py` runner sleeps 2 seconds between cases by default to stay well under Groq free-tier 30 RPM / 6K TPM.

A live dry-run with 5 cases on this hardware observed **14 RPM** — safely below the 30 RPM limit. If your eval set grows past ~25 items, increase `SLEEP_BETWEEN_CASES` in the WorkflowTemplate's `step-eval` env vars.
:::

## Lab Files

```text
course-code/labs/lab-12/solution/
├── scripts/
│   ├── install-argo-workflows.sh          # helm install argo/argo-workflows 1.0.13
│   ├── dry-run-eval.sh                    # 5-case dry-run (closes Open Q4)
│   └── trigger-pipeline.sh                # Submit Workflow, stream status; --force-fail flag
├── k8s/
│   ├── 100-argo-workflows-rbac.yaml       # argo-workflow SA + Role (Pitfall 10)
│   ├── 100-pvc-pipeline-workspace.yaml    # 5Gi RWO PVC (Pitfall 5 — no S3)
│   ├── 100-secret-llm-api-keys.yaml.example  # Template for the Groq key copy
│   ├── 101-workflowtemplate-llm-pipeline.yaml  # The DAG
│   └── 102-workflow-llm-pipeline-run.yaml      # One-shot Workflow that triggers the template
├── eval/
│   └── eval-set.jsonl                     # 12 handcrafted Smile Dental Q&A items (D-12)
├── deepeval_local/                        # Python package
│   ├── groq_judge.py                      # DeepEvalBaseLLM wrapper for Groq
│   └── run_eval.py                        # Sequential FaithfulnessMetric runner
└── deepeval/                              # Container build artifacts + tests
    ├── Dockerfile
    ├── requirements.txt
    ├── pytest.ini
    ├── test_groq_judge.py
    └── test_run_eval.py
```

## Part A — Install Argo Workflows

```bash
cd course-code/labs/lab-12/solution
bash scripts/install-argo-workflows.sh
```

What this does:

- `helm install argo-workflows argo/argo-workflows --version 1.0.13 -n argo --create-namespace`
- Sets `server.serviceType=NodePort`, `nodePortHttp=30800` (UI accessible on the host)
- Sets `server.authModes={server}` (no SSO; instructor-friendly default)
- Creates the `argo` ServiceAccount and restricts the controller to `workflowNamespaces={argo}`

Verify:

```bash
kubectl get pods -n argo
# argo-workflows-server-...                Running
# argo-workflows-workflow-controller-...   Running
open http://localhost:30800
```

:::tip Helm install timeout
On slow networks the CRD install job pulls `registry.k8s.io/kubectl:v1.36.0` which can take several minutes. The script runs with `--timeout 10m`. If it times out: force-delete stuck pods, re-run the script — the second attempt succeeds once the image is cached.
:::

## Part B — Apply RBAC + PVC + copy the LLM API key Secret

The default `argo` ServiceAccount in the `argo` namespace does not have `get` on Secrets. Workflow step pods inherit the workflow's SA, and the eval step needs to read `llm-api-keys` while the commit-tag step needs to read `git-deploy-key`. Hence the custom SA (Pitfall 10):

```bash
kubectl apply -f k8s/100-argo-workflows-rbac.yaml
kubectl apply -f k8s/100-pvc-pipeline-workspace.yaml
```

Copy the existing LLM API key Secret from `llm-agent` to `argo` (Workflow step pods can only mount Secrets from their own namespace):

```bash
kubectl get secret llm-api-keys -n llm-agent -o yaml \
  | sed 's/namespace: llm-agent/namespace: argo/' \
  | kubectl apply -f -
```

Verify:

```bash
kubectl get secret llm-api-keys -n argo
kubectl get secret git-deploy-key -n argo  # From Lab 11 Part E
kubectl get pvc pipeline-workspace -n argo
# pipeline-workspace   Bound   pvc-...   5Gi   RWO   ...
```

## Part C — Build and load the DeepEval container

The eval step runs in a custom container that bundles DeepEval, the Groq judge wrapper, the runner, and the eval set:

```bash
# From repo root — Docker build context is the solution/ directory
docker build -t kind-registry:5001/smile-dental-deepeval:v1.0.0 \
  -f course-code/labs/lab-12/solution/deepeval/Dockerfile \
  course-code/labs/lab-12/solution/

# CRITICAL: kind load — KIND nodes can't pull from localhost:5001 without this (Pitfall 4)
kind load docker-image kind-registry:5001/smile-dental-deepeval:v1.0.0 --name llmops-kind
```

Run the unit tests locally to confirm the container's Python code is sound:

```bash
cd course-code/labs/lab-12/solution
PYTHONPATH=. pytest deepeval/ -v
# Expect: 8 passed
```

The 8 tests cover two modules:

- `test_groq_judge.py` (4 tests): init reads env vars, generate returns content, generate uses temperature 0.1, get_model_name
- `test_run_eval.py` (4 tests): pass writes true, fail writes false, respects sleep interval, stub vLLM path used

The tests stub the Groq HTTP call — no real API hit during the test run. All 8 pass before any network access.

## Part D — Inspect the WorkflowTemplate (the headline)

Open `k8s/101-workflowtemplate-llm-pipeline.yaml` and look for these four things:

**1. The DAG** — 6 named tasks under `spec.templates[0].dag.tasks`:

```yaml
tasks:
- { name: data-gen,    template: step-noop, ... }
- { name: train,       template: step-noop, dependencies: [data-gen] }
- { name: merge,       template: step-noop, dependencies: [train] }
- { name: package,     template: step-noop, dependencies: [merge] }
- { name: eval,        template: step-eval,       dependencies: [package] }
- { name: commit-tag,  template: step-commit-tag, dependencies: [eval],
    when: "{{tasks.eval.outputs.parameters.pass}} == true" }
```

**2. D-11 short-circuit** — data-gen / train / merge / package use the `step-noop` template (just an `echo`). Re-running real fine-tuning every demo would burn 10-15 minutes of CPU. The lab teaches the **gate mechanic**, not the training. The "if you have time" extension at the end of the page swaps these in for real.

**3. The eval step writes `pass=true|false` as an output parameter:**

```yaml
- name: step-eval
  container:
    image: kind-registry:5001/smile-dental-deepeval:v1.0.0
    command: [python, -m, deepeval_local.run_eval]   # explicit — Argo emissary cannot inspect HTTP registry
    env:
    - { name: LLM_BASE_URL,  value: "https://api.groq.com/openai/v1" }
    - { name: LLM_MODEL,     value: "llama-3.3-70b-versatile" }
    - { name: VLLM_URL,      value: "http://vllm-smollm2.llm-serving.svc.cluster.local:8000" }
    - { name: VLLM_MODEL,    value: "smollm2-135m-finetuned" }
    - { name: THRESHOLD,     value: "{{workflow.parameters.threshold}}" }
    - { name: SLEEP_BETWEEN_CASES, value: "2.0" }
    - name: GROQ_API_KEY
      valueFrom: { secretKeyRef: { name: llm-api-keys, key: groq-api-key } }
  outputs:
    parameters:
    - name: pass
      valueFrom: { path: /tmp/eval-pass.txt }   # contents: 'true' or 'false'
```

**4. The commit-tag step is gated** — `when: "{{tasks.eval.outputs.parameters.pass}} == true"` means commit-tag is SKIPPED when eval wrote `false`. The eval step always exits 0 (so Argo can read the output parameter regardless of pass/fail result) — pass/fail is conveyed entirely via the file content.

**5. The shared PVC** — `volumes[0].persistentVolumeClaim.claimName: pipeline-workspace`, mounted at `/workspace` in every step. No S3, no MinIO (Pitfall 5).

Apply:

```bash
kubectl apply -f course-code/labs/lab-12/solution/k8s/101-workflowtemplate-llm-pipeline.yaml
kubectl get workflowtemplate llm-pipeline -n argo
```

## Part E — Dry-run the eval step (closes Open Q4)

Before submitting the full Workflow, validate that DeepEval does not blow your Groq rate limit. Run with the first 5 eval items:

```bash
cd course-code/labs/lab-12/solution
export GROQ_API_KEY="${GROQ_API_KEY}"
export LLM_BASE_URL="https://api.groq.com/openai/v1"
export VLLM_URL="http://localhost:30200"   # NodePort vLLM (or port-forward to 8000)
bash scripts/dry-run-eval.sh
```

What the script does: slices the first 5 lines of `eval/eval-set.jsonl` into a temp file, runs `python -m deepeval_local.run_eval` against those 5 cases, then prints a rate-limit summary:

```
Rate-limit check:
  5 cases x 2 LLM calls each = 10 Groq API calls
  At 2.0s sleep between cases: ~10s elapsed (plus LLM latency)
  Free tier: 30 RPM -- 10 calls in ~30s is safely under limit.
  For full 12-case run: 24 calls @ 2.0s sleep = ~1-2 min total.
```

Live observation on this hardware: **14 RPM** observed, no 429 errors. The full 12-item run takes approximately **2-3 minutes** just for the eval step.

## Part F — PASS path: submit the pipeline

```bash
cd course-code/labs/lab-12/solution
bash scripts/trigger-pipeline.sh
# PASS path: setting threshold=0.7 — eval should pass; commit-tag step will run.
#
# Submitted Workflow: llm-pipeline-XXXXX
# Streaming status (Ctrl-C to detach; Workflow keeps running):
# [HH:MM:SS] phase=Pending       (attempt 1/120)
# [HH:MM:SS] phase=Running       (attempt 2/120)
# ...
# [HH:MM:SS] phase=Succeeded
```

The script applies the WorkflowTemplate, submits a one-shot Workflow with threshold=0.7, then polls every 10 seconds for up to 20 minutes. After the Workflow finishes it prints the node breakdown:

```
eval                 Succeeded    pass=true
commit-tag           Succeeded
```

What happens behind the scenes:

1. `data-gen`, `train`, `merge`, `package` — noop alpine containers print short-circuit messages (~2s each)
2. `eval` — `smile-dental-deepeval:v1.0.0` runs 12 Smile Dental Q&A cases through `FaithfulnessMetric`; writes `true` to `/tmp/eval-pass.txt`; Argo reads that as output parameter `pass=true` (~2-3 min)
3. `commit-tag` — `when:` evaluates `true == true`; step runs; SSH-clones the companion repo, bumps the `gitops/model-version` annotation in `gitops-repo/bases/vllm/30-deploy-vllm.yaml`, commits and pushes (commit SHA: `164ac67`)

Live timing on this hardware: full Workflow **~3 min 40 sec**; eval step alone **~2 min 50 sec**; commit-tag step ~50 sec (includes `apt-get install git openssh-client` + SSH clone + push).

Open the Argo Workflows UI for the visual DAG:

```bash
open http://localhost:30800
# Click the Workflow → see 6 green nodes (data-gen, train, merge, package, eval, commit-tag)
```

Confirm ArgoCD picked up the commit (auto-poll: ~3 min, or force):

```bash
argocd app sync vllm --grpc-web 2>/dev/null || \
  kubectl patch application vllm -n argocd --type merge --patch '{"operation":{"sync":{}}}'

kubectl get deploy vllm-smollm2 -n llm-serving \
  -o jsonpath='{.metadata.annotations.gitops/model-version}{"\n"}'
# Expect: smollm2-135m-finetuned-<workflow-creation-timestamp>
```

End-to-end loop closed: eval passed → git push → ArgoCD synced → live cluster reflects the new model-version annotation.

## Part G — FAIL path: prove the gate works

A gate that always passes is decoration. Run with `--force-fail` (sets threshold=0.99 — almost guaranteed to fail at least one FaithfulnessMetric case):

```bash
bash scripts/trigger-pipeline.sh --force-fail
# FAIL path: setting threshold=0.99 — eval will fail; commit-tag step will be SKIPPED.
# (This demonstrates EVAL-02: the quality gate blocks deployment on regression.)
#
# Submitted Workflow: llm-pipeline-YYYYY
# [HH:MM:SS] phase=Running
# ...
# [HH:MM:SS] phase=Succeeded
#
# eval                 Succeeded    pass=false
# commit-tag           Skipped
#
# FAIL PATH COMPLETE: eval=false -> commit-tag SKIPPED -> no git commit -> vLLM unchanged.
```

The Workflow itself succeeds — the eval step exits 0 by design (Argo can only read output parameters from steps that exit 0). What matters is what the script reports in its final lines:

```
eval output (pass): false
commit-tag phase:   Skipped
```

Verify the gate held in three independent ways:

```bash
# 1. Confirm commit-tag node status is Skipped in the Workflow object
kubectl get workflow llm-pipeline-YYYYY -n argo \
  -o jsonpath='{.status.nodes}' | python3 -m json.tool \
  | python3 -c "
import sys, json
nodes = json.load(sys.stdin)
for n in nodes.values():
    if 'commit' in n.get('displayName', '').lower():
        print(n['displayName'], '→', n.get('phase', '?'))
"
# commit-tag → Skipped

# 2. Confirm no new commit reached the gitops manifest
git log --oneline -3 course-code/labs/lab-11/solution/gitops-repo/bases/vllm/30-deploy-vllm.yaml
# Expect: ONLY the PASS-path commit from Part F. No new commit from the FAIL run.

# 3. Confirm the live cluster annotation is unchanged
kubectl get deploy vllm-smollm2 -n llm-serving \
  -o jsonpath='{.metadata.annotations.gitops/model-version}{"\n"}'
# Expect: same value as after Part F. The bad model did NOT promote.
```

Live timing: FAIL path total **~3 min 30 sec** — nearly identical to PASS because the same 12 eval cases still run (2 LLM calls each). The commit-tag step costs zero seconds because it never ran.

:::tip The story to tell
"Eval ran. Eval failed. The pipeline still finished cleanly. But no new code reached production. That is the whole point."
:::

## Common Pitfalls

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| `step-eval` pod stuck in `CreateContainerConfigError` | argo-workflow ServiceAccount can't read `llm-api-keys` Secret (Pitfall 10) | Re-apply `100-argo-workflows-rbac.yaml`; verify with `kubectl auth can-i get secret/llm-api-keys -n argo --as=system:serviceaccount:argo:argo-workflow` |
| `step-eval` pod `ImagePullBackOff` | Forgot `kind load docker-image` (Pitfall 4) | Run `kind load docker-image kind-registry:5001/smile-dental-deepeval:v1.0.0 --name llmops-kind` |
| `step-eval` pod error: `failed to look-up entrypoint` or `http: server gave HTTP response to HTTPS client` | Argo emissary tries HTTPS to inspect the kind-registry entrypoint but the local registry is HTTP-only | Confirm `command: [python, -m, deepeval_local.run_eval]` is present in the `step-eval` template; re-apply the WorkflowTemplate |
| `step-commit-tag` fails with `Permission denied (publickey)` on `git push` | SSH deploy key Secret not mounted, or GitHub deploy key does not have "Allow write access" checked | Re-do Lab 11 Part E; ensure the GitHub deploy-key has the write-access checkbox enabled |
| Workflow stays `Pending` forever | PVC `pipeline-workspace` is unbound (no PV available) | `kubectl describe pvc pipeline-workspace -n argo` — KIND default storageClass should provision automatically; if not, `kubectl get sc` and confirm one is marked `(default)` |
| Eval step returns 429 from Groq | Eval set has more than ~25 items at default 2s sleep — saturating 30 RPM | Increase `SLEEP_BETWEEN_CASES` env in the `step-eval` container from `2.0` to `3.0` or higher |
| `step-commit-tag` ran but `git log` shows no new commit | The annotation value was identical to the current value; `git diff` showed nothing to commit | Re-run with a new Workflow — the bumped annotation includes a UTC workflow creation timestamp and will differ each run |
| `when:` gate evaluated `false` even though eval passed | The eval step wrote something other than the literal string `true` (e.g. `True\n` with capital T or trailing newline) | Inspect: `kubectl get workflow <name> -n argo -o jsonpath='{.status.nodes}' \| python3 -m json.tool` — find the eval node's `outputs.parameters[0].value`; fix `run_eval.py` to write lowercase `true` with no trailing newline |

## Summary

You now have:

- Argo Workflows chart 1.0.13 (server v4.0.5) installed in `argo` namespace, UI on `:30800`
- A DeepEval container (`smile-dental-deepeval:v1.0.0`) baking 12 handcrafted Smile Dental Q&A test cases — Faithfulness scored via LLM-as-judge with Groq llama-3.3-70b-versatile
- A `WorkflowTemplate llm-pipeline` defining the 6-step DAG with `when: "{{tasks.eval.outputs.parameters.pass}} == true"` gating the commit-tag step
- Live demonstration that eval-PASS → git push → ArgoCD sync
- Live demonstration that eval-FAIL → commit-tag Skipped → no git push → vLLM unchanged — **the gate works in both directions**

The pedagogical core: **shipping AI without a quality gate is just shipping**. DeepEval `FaithfulnessMetric` is one option; the pattern (eval as a DAG step + conditional commit via `when:`) is the durable lesson.

Lab 13 capstone reuses this WorkflowTemplate verbatim — students will add 5 insurance Q&A items to `eval-set.jsonl`, ship the new `insurance_check` MCP tool, run the same `trigger-pipeline.sh`, and confirm the eval gate exercises the new tool's grounding before ArgoCD promotes the change.

## Next Step

Lab 13 brings it all together: students ship a new MCP tool (`insurance_check`) end-to-end through TDD → guardrails → eval gate → ArgoCD → Grafana. The capstone exercises every Day 3 win in one workflow.

Continue to [Lab 13: Guardrails + Capstone](./lab-13-capstone.md).
