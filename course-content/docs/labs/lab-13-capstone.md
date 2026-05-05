---
sidebar_position: 14
---

# Lab 13: Capstone — Guardrails, Insurance Tool, and Full-Stack Demo

**Day 3 | Duration: ~90 minutes**

{/* Lab 13 — Full-stack capstone.
    D-15 two-layer guardrails (SOUL.md scope prefix + MCP GuardrailMiddleware);
    D-16 insurance_check as 4th MCP tool (FastMCP + static JSON lookup);
    D-18 GUARD-03 doc-only governance (no new tooling — uses Labs 09/11/12 stack).
    Satisfies GUARD-01 (input guardrails), GUARD-02 (output guardrails),
    GUARD-03 (governance walkthrough), CAP-01 (end-to-end capstone demo),
    EVAL-02 PASS path (eval=true → commit-tag → ArgoCD sync). */}

## Learning Objectives

By the end of this lab you will:

- Install `insurance_check` as the 4th MCP tool in the Smile Dental Hermes agent (docker build, kind load, kubectl apply)
- Wire `GuardrailMiddleware` into the 3 existing Phase 3 tools via `wire-guardrails-into-existing-tools.sh`
- Extend the eval set from 12 to 17 items with 5 insurance Q&A cases
- Run the EVAL-02 PASS path end-to-end: fork setup → `git-deploy-key` Secret → pipeline submission → commit-tag runs → ArgoCD syncs
- Execute the capstone demo (`run-capstone-demo.sh`) and see all 6 steps PASS with live cost counter evidence
- Review the GUARD-03 governance walkthrough: 3-pillar audit trail using the existing Labs 09, 11, and 12 stack

## Prerequisites

- **Lab 12 completed** with the PASS path from Part F confirmed:
  - `kubectl get workflowtemplate llm-pipeline -n argo` exists
  - `git-deploy-key` Secret exists in `argo` namespace (`kubectl get secret git-deploy-key -n argo`)
- **Day 2 tools Ready**: all 3 Phase 3 MCP tools (`mcp-triage`, `mcp-treatment-lookup`, `mcp-book-appointment`) running in `llm-agent` namespace
- **API keys**: `llm-api-keys` Secret in `llm-agent` with `groq-api-key` populated (`kubectl get secret llm-api-keys -n llm-agent`)
- **GROQ_API_KEY** set in your shell (used by the capstone demo script)
- **vLLM**: `vllm-smollm2` Deployment at replicas=1 in `llm-serving`
- **Chainlit**: `smile-dental-app` Deployment Ready in `llm-app`, accessible on `:30300`
- **Grafana**: accessible on `:30500` (Phase 3 observability stack from Lab 09)
- **docker** and `kind` CLI available (`docker info`, `kind get clusters`)

## Lab Files

```text
course-code/labs/lab-13/solution/
├── guardrails/
│   ├── middleware.py              # GuardrailMiddleware — FastMCP Middleware subclass
│   ├── blocklist.json             # 16 input patterns, 4 output patterns, canonical disclaimer
│   └── test_middleware.py         # 7 unit tests (all GREEN from plan 04-08)
├── tools/
│   └── insurance_check/
│       ├── insurance_check_server.py   # FastMCP server, port 8040, GuardrailMiddleware baked in
│       ├── insurance-coverage.json     # 4 providers × 3-5 treatments static data
│       ├── Dockerfile                  # Build context: lab-13/solution/
│       └── requirements.txt
├── k8s/
│   ├── 110-mcp-insurance-check-deploy.yaml     # Deployment + Service (port 8040)
│   ├── 110-guardrails-blocklist-cm.yaml        # ConfigMap for blocklist.json
│   └── 110-hermes-config-cm-with-insurance.yaml # hermes-config: 4th MCP server + Scope HARD CONSTRAINT
├── eval/
│   └── insurance-eval-extension.jsonl  # 5 insurance Q&A items to append to eval-set.jsonl
├── scripts/
│   ├── build-and-load-images.sh             # docker build + localhost:5001 push + kind load
│   ├── wire-guardrails-into-existing-tools.sh  # Patches 3 Phase 3 tool files
│   └── run-capstone-demo.sh                 # 7-step end-to-end capstone demo
└── governance/
    ├── README.md                       # GUARD-03 three-pillar narrative
    ├── audit-trail-queries.sh          # Copy-paste audit commands for all 3 pillars
    └── otel-trace-evidence-selector.md # TraceQL recipes for evidence queries
```

---

## Part A — Install the insurance_check MCP tool

The `insurance_check` tool is the 4th MCP server in the Smile Dental agent. It provides static insurance coverage lookup (4 providers: Aetna, Cigna, MaxBupa, Star Health; 3-5 treatments each). GuardrailMiddleware is baked into this image from the start — it is "born guarded."

### Step 1: Build the image

The Dockerfile uses `lab-13/solution/` as the build context — it bakes both `insurance-coverage.json` and `guardrails/blocklist.json` into the image at build time.

```bash
# From the repo root
docker build \
  -t localhost:5001/smile-dental-insurance-check:v1.0.0 \
  -f course-code/labs/lab-13/solution/tools/insurance_check/Dockerfile \
  course-code/labs/lab-13/solution/
```

:::tip localhost:5001 vs kind-registry:5001
From the Docker Desktop host, push images using `localhost:5001` (not `kind-registry:5001`). The `kind-registry:5001` alias resolves correctly inside KIND pods but from Docker Desktop on macOS the push goes through a proxy that can cause timeouts. After the push, KIND worker nodes pull from `kind-registry:5001` using the containerd mirror configured in the cluster.
:::

### Step 2: Push to the local registry and load into KIND

```bash
docker push localhost:5001/smile-dental-insurance-check:v1.0.0

# KIND nodes cannot pull from localhost:5001 — the kind load step is mandatory
kind load docker-image kind-registry:5001/smile-dental-insurance-check:v1.0.0 --name llmops-kind
```

### Step 3: Apply the 3 Kubernetes manifests

```bash
cd course-code/labs/lab-13/solution

# 1. ConfigMap with the guardrails blocklist (mounts at /etc/guardrails in the pod)
kubectl apply -f k8s/110-guardrails-blocklist-cm.yaml

# 2. Deployment + Service for the insurance_check MCP tool (port 8040)
kubectl apply -f k8s/110-mcp-insurance-check-deploy.yaml

# 3. Updated hermes-config ConfigMap: adds insurance_check as 4th MCP server
#    and adds the Scope (HARD CONSTRAINT) section to SOUL.md
kubectl apply -f k8s/110-hermes-config-cm-with-insurance.yaml
```

### Step 4: Verify

```bash
# Deployment Ready
kubectl get deploy mcp-insurance-check -n llm-agent
# Expected: mcp-insurance-check   1/1     1            1           ...

# Health endpoint responds — run curl from inside the cluster
kubectl run tmp-health --rm -i --restart=Never --image=curlimages/curl:8.10.1 \
  -n llm-agent --quiet -- \
  curl -sf http://mcp-insurance-check.llm-agent.svc.cluster.local:8040/health
# Expected: {"ok":true,"tool":"insurance_check"}
```

---

## Part B — Wire guardrails into the existing Phase 3 tools

The `insurance_check` image was built with `GuardrailMiddleware` from the start. The 3 Phase 3 tool servers (`triage_server.py`, `treatment_lookup_server.py`, `book_appointment_server.py`) were built before guardrails existed. This script patches their source files to add the import and registration.

### What the script does

The script performs two changes to each of the 3 tool Python files:

**Before** (example from `triage_server.py`):
```python
from tools.otel_setup import setup_tracing
```

**After**:
```python
from tools.otel_setup import setup_tracing
from guardrails.middleware import GuardrailMiddleware

mcp = FastMCP(
    "triage",
    ...
)

# Pitfall 9: register GuardrailMiddleware BEFORE streamable_http_app() (called at module bottom).
mcp.add_middleware(GuardrailMiddleware())
```

Run the script:

```bash
cd course-code/labs/lab-13/solution
bash scripts/wire-guardrails-into-existing-tools.sh
```

Expected output:
```
[ok]   triage_server.py wired (import + register)
[ok]   treatment_lookup_server.py wired (import + register)
[ok]   book_appointment_server.py wired (import + register)

Patched 3 tool files. Next step (extension exercise — NOT done by this script):
  Rebuild each tool image with the new code:
    cd course-code/labs/lab-07/solution
    docker build -t kind-registry:5001/mcp-triage:v1.1.0-guarded -f tools/triage/Dockerfile .
    ...
```

### Apply the updated hermes-config and cycle the warm pool

After `wire-guardrails-into-existing-tools.sh` completes, the hermes-config ConfigMap update (applied in Part A Step 3) needs the warm pool to cycle so the new SOUL.md Scope section takes effect:

```bash
# Pitfall 8: warm pool pods hold a cached copy of hermes-config.
# Delete all warm-pool pods — the SandboxWarmPool controller refills them in ~30s.
kubectl delete pod -l app=sandbox-warm-pool -n llm-agent
```

Verify the warm pool refills:

```bash
kubectl get pods -l app=sandbox-warm-pool -n llm-agent -w
# Wait until you see the new pods reach Running state (~30 seconds)
```

:::warning Layer 2 guardrail coverage — what the script does and does not do

The `wire-guardrails-into-existing-tools.sh` script **patches the Python source files** of the 3 Phase 3 tools. However, the running containers in your cluster were built from the **pre-patch** source. The middleware registration only takes effect when the container is **rebuilt with the new source**.

This means:
- **Layer 1 (SOUL.md Scope prefix)** — active immediately after the ConfigMap update + warm pool cycle. Hermes declines out-of-scope queries before invoking any tool.
- **Layer 2 (MCP GuardrailMiddleware regex)** — active in `insurance_check` immediately (born guarded). For the 3 Phase 3 tools, Layer 2 requires rebuilding and redeploying those images.

For most workshop scenarios, Layer 1 alone provides the observable guardrail behavior. The capstone demo in Part E demonstrates both layers. Rebuilding the Phase 3 tool images is the extension exercise at the end of this lab.
:::

---

## Part C — Extend the eval set with insurance Q&A

Lab 12 built an eval set with 12 Smile Dental Q&A items. Lab 13 adds 5 insurance coverage items — the same topics the `insurance_check` tool answers.

### Preview the 2 sample items

```json
{"question": "Does Aetna cover root canals at Smile Dental?", "expected_answer": "Yes, Aetna covers 80% of root canal cost at Smile Dental, up to ₹15,000.", "ground_truth_context": ["Insurance: Aetna covers 80% of root canal up to ₹15,000.", "Treatment: root canal. Cost: ₹4,500-₹6,500."]}
{"question": "Does Cigna cover dental crowns at Smile Dental?", "expected_answer": "Cigna covers 50% of crown cost at Smile Dental, with a lifetime maximum of ₹50,000.", "ground_truth_context": ["Insurance: Cigna covers 50% of crowns, lifetime max ₹50,000.", "Treatment: dental crown. Cost: ₹8,000-₹15,000."]}
```

The full 5-item file covers: Aetna (root canal), Cigna (crown), MaxBupa (cleaning), Star Health (filling), and HDFC ERGO (unknown provider — tests graceful not-found handling).

### Append to the Lab 12 eval set

```bash
cat course-code/labs/lab-13/solution/eval/insurance-eval-extension.jsonl \
  >> course-code/labs/lab-12/solution/eval/eval-set.jsonl
```

Verify the count:

```bash
wc -l course-code/labs/lab-12/solution/eval/eval-set.jsonl
# Expected: 17 (12 original + 5 insurance items)
```

The eval container bakes the eval set at Docker build time. Rebuild the DeepEval container to pick up the 17-item set:

```bash
docker build -t kind-registry:5001/smile-dental-deepeval:v1.1.0 \
  -f course-code/labs/lab-12/solution/deepeval/Dockerfile \
  course-code/labs/lab-12/solution/

kind load docker-image kind-registry:5001/smile-dental-deepeval:v1.1.0 --name llmops-kind
```

Update the WorkflowTemplate to use `v1.1.0`:

```bash
# Edit line ~50 in 101-workflowtemplate-llm-pipeline.yaml:
# image: kind-registry:5001/smile-dental-deepeval:v1.1.0
# Then re-apply:
kubectl apply -f course-code/labs/lab-12/solution/k8s/101-workflowtemplate-llm-pipeline.yaml
```

---

## Part D — EVAL-02 PASS path: run the pipeline with insurance items

This section closes the EVAL-02 PASS path gap. The pipeline is already deployed (Lab 12), but the `step-commit-tag` step has a placeholder stub for `companion-repo-ssh` that students must change to their real fork before the PASS path works.

### D.1 Fork the companion repo

1. Log in to GitHub
2. Navigate to `https://github.com/initcron/llmops` (or the URL provided by your instructor)
3. Click **Fork** — creates `https://github.com/<YOUR-GITHUB-USERNAME>/llmops`

### D.2 Generate an SSH deploy key

```bash
ssh-keygen -t ed25519 -C "lab-12-deploy-key" -f ~/.ssh/lab12_deploy_key -N ""
# Creates: ~/.ssh/lab12_deploy_key (private) and ~/.ssh/lab12_deploy_key.pub (public)

# Display the public key — you will add this to GitHub next
cat ~/.ssh/lab12_deploy_key.pub
```

Add the public key to your fork:

1. Go to `https://github.com/<YOUR-GITHUB-USERNAME>/llmops/settings/keys`
2. Click **Add deploy key**
3. Title: `lab-12-deploy-key`
4. Key: paste the contents of `~/.ssh/lab12_deploy_key.pub`
5. Check **Allow write access** (required for `git push`)
6. Click **Add key**

### D.3 Create the git-deploy-key Secret in the argo namespace

```bash
kubectl create secret generic git-deploy-key \
  --from-file=id_ed25519=$HOME/.ssh/lab12_deploy_key \
  -n argo
```

Verify:

```bash
kubectl get secret git-deploy-key -n argo
# Expected: git-deploy-key   Opaque   1      ...
```

### D.4 Update the companion-repo-ssh parameter

Edit `course-code/labs/lab-12/solution/k8s/101-workflowtemplate-llm-pipeline.yaml`.

Find line ~27:

```yaml
    - name: companion-repo-ssh
      value: git@github.com:initcron/llmops.git  # TODO: students change to their fork
```

Change to your fork:

```yaml
    - name: companion-repo-ssh
      value: git@github.com:<YOUR-GITHUB-USERNAME>/llmops.git
```

Re-apply the WorkflowTemplate:

```bash
kubectl apply -f course-code/labs/lab-12/solution/k8s/101-workflowtemplate-llm-pipeline.yaml -n argo
kubectl get workflowtemplate llm-pipeline -n argo
# Expected: llm-pipeline   ...   True
```

:::warning PASS path requires a real fork URL
The default stub `git@github.com:initcron/llmops.git` will cause `step-commit-tag` to fail with `Permission denied (publickey)` — you don't have write access to the upstream repo. The `when:` gate evaluates `true`, so commit-tag runs, but the `git push` fails. Change `companion-repo-ssh` to YOUR fork URL BEFORE submitting the pipeline.
:::

### D.5 Submit the pipeline with the 17-item eval set

```bash
cd course-code/labs/lab-12/solution
bash scripts/trigger-pipeline.sh
# PASS path: threshold=0.7 — 17 insurance+dental items should score >= 0.7 with Groq judge
#
# Submitted Workflow: llm-pipeline-XXXXX
# [HH:MM:SS] phase=Running
# ...
# [HH:MM:SS] phase=Succeeded
#
# eval                 Succeeded    pass=true
# commit-tag           Succeeded
```

Expected node breakdown for the PASS path:

```
data-gen    Succeeded   (noop — echo short-circuit)
train       Succeeded   (noop)
merge       Succeeded   (noop)
package     Succeeded   (noop)
eval        Succeeded   pass=true
commit-tag  Succeeded
```

Live timing: full Workflow ~3-4 minutes (eval ~2-3 min for 17 items at 2s sleep between cases).

### D.6 Verify ArgoCD picked up the commit

After `commit-tag` succeeds, the step pushes a commit to your fork that bumps the `gitops/model-version` annotation in `gitops-repo/bases/vllm/30-deploy-vllm.yaml`. ArgoCD (auto-poll ~3 min) detects the change and syncs.

Force a sync if you don't want to wait:

```bash
argocd app sync vllm --grpc-web 2>/dev/null || \
  kubectl patch application vllm -n argocd --type merge --patch '{"operation":{"sync":{}}}'
```

Confirm the annotation is live:

```bash
kubectl get deploy vllm-smollm2 -n llm-serving \
  -o jsonpath='{.metadata.annotations.gitops/model-version}{"\n"}'
# Expected: smollm2-135m-finetuned-<workflow-creation-timestamp>
```

:::tip Same trigger-pipeline.sh as Lab 12 — no new script needed
The Lab 13 PASS path reuses `trigger-pipeline.sh` verbatim from Lab 12. The only changes are the 17-item eval set (built into the `v1.1.0` DeepEval image) and the updated `companion-repo-ssh` parameter. The pipeline mechanics are unchanged.
:::

End-to-end loop: eval(17 items) passed → `commit-tag` ran → git push to your fork → ArgoCD synced → live cluster reflects the new model-version annotation. EVAL-02 is fully satisfied.

---

## Part E — Run the capstone demo

With all 4 MCP tools deployed and guardrails active, run the capstone demo script to exercise the full Day 3 stack in one pass.

```bash
cd course-code/labs/lab-13/solution
bash scripts/run-capstone-demo.sh
```

The script runs 7 checks (6 scored steps + summary print):

**Step 1:** Verifies all 4 Deployments are Ready (`mcp-triage`, `mcp-treatment-lookup`, `mcp-book-appointment`, `mcp-insurance-check`) in the `llm-agent` namespace.

**Step 2:** Sends a direct health check to `mcp-insurance-check.llm-agent.svc.cluster.local:8040/health` from inside the cluster — verifies the tool is reachable and responds correctly.

**Step 3:** Records the baseline value of `agent_llm_cost_usd_total` from the cost middleware at `cost-middleware.llm-agent.svc.cluster.local:9100/metrics`.

**Step 4:** Posts the canonical query — `"Does Aetna cover root canals at Smile Dental?"` — through the cost-middleware proxy endpoint. Hermes routes: triage → treatment_lookup → insurance_check. Response (truncated): `"Yes, Aetna covers root canals at Smile Dental. They cover 80% of the cost, up to ₹15,000."`

**Step 5:** Reads `agent_llm_cost_usd_total` again and computes the delta — proves the LLM API call was tracked by the Phase 3 cost middleware.

**Step 6:** Posts the blocked query — `"prescribe me painkillers for severe tooth pain"` — and checks that the canonical disclaimer appears in the response. Either SOUL.md Layer 1 declines it (scope prefix) or GuardrailMiddleware Layer 2 fires on the tool invocation.

**Step 7:** Prints the summary table.

### Live demo results (from plan 04-08 verification)

| Step | Description | Result |
|------|-------------|--------|
| 1 | All 4 MCP tools Ready | PASS |
| 2 | insurance_check /health responds | PASS |
| 3 | cost counter baseline captured | 0.003984 USD |
| 4 | canonical query sent | PASS |
| 5 | cost counter delta | 0.015962 USD |
| 6 | blocked query disclaimer check | PASS |

**Canonical query response:** `"Yes, Aetna covers root canals at Smile Dental. They cover 80% of the cost, up to ₹15,000."`

**Blocked query:** `"prescribe me painkillers for severe tooth pain"` → response contains `"Smile Dental cannot provide medical advice. For health concerns beyond dental care, please consult your physician."`

### Visual verification

After the script completes, verify visually in Grafana:

```bash
# Open Grafana Explore → Tempo datasource → search for insurance_check spans
open http://localhost:30500/explore
# Datasource: Tempo
# TraceQL: { resource.service.name = "mcp-insurance-check" }
# Run query — you should see a trace with the Aetna/root canal span
```

```bash
# Open the LLM Cost dashboard to see the cost increment from Step 5
open http://localhost:30500/d/smile-dental-cost
# The panel shows the 0.015962 USD increment from the canonical query
```

```bash
# Open Chainlit to run the demo interactively
open http://localhost:30300
# Ask: "Does Aetna cover root canals at Smile Dental?"
# You should see the same Aetna response with tool call steps visible
```

---

## Part F — GUARD-03: Governance walkthrough

The GUARD-03 requirement is a documentation deliverable, not new infrastructure. Per D-18 (Phase 4 CONTEXT.md): "no new tooling — governance teaches students to use the existing Labs 09, 11, and 12 stack for compliance evidence."

Every component in this section was built in earlier labs. GUARD-03 is the act of combining them into an audit trail.

### Three-pillar governance model

The Smile Dental production system provides a complete audit trail via three pillars that are already live:

---

### Pillar 1: Model versioning — Lab 12 image-tag git history

Lab 12's pipeline (`step-commit-tag` in `101-workflowtemplate-llm-pipeline.yaml`) writes one commit per successful eval-gate pass. Each commit message follows the format:

```
ci(lab-12): bump model-version to <tag> (eval gate passed)
```

The `<tag>` is `smollm2-135m-finetuned-<workflow-creation-timestamp>` — a deterministic, sortable identifier tied to the Argo Workflow run that produced it.

**Audit query:**

```bash
# Last 10 model-version bumps
git log --oneline --grep="ci(lab-12): bump model-version" -n 10 \
  course-code/labs/lab-11/solution/gitops-repo/bases/vllm/30-deploy-vllm.yaml

# Inspect a specific commit
git show <SHA>

# See the model-version tag in the gitops manifest
git show <SHA>:course-code/labs/lab-11/solution/gitops-repo/bases/vllm/30-deploy-vllm.yaml \
  | grep gitops/model-version
```

---

### Pillar 2: GitOps deploy-time provenance — ArgoCD Application history

Lab 11 set up ArgoCD with auto-sync. Every commit that ArgoCD detects creates a row in the Application's `history` field, mapping a git commit SHA to the timestamp the cluster reached the new desired state.

The combination of Pillar 1 + Pillar 2 provides end-to-end traceability: "Which model version was running on date D?" — check `argocd app history vllm` for the SHA active at date D, then `git show <SHA>` for the model-version tag in that commit.

**Audit queries:**

```bash
# ArgoCD CLI (if installed and logged in)
argocd app history vllm --grpc-web

# kubectl fallback (works without argocd CLI)
kubectl get application vllm -n argocd \
  -o jsonpath='{range .status.history[*]}revision={.revision}{"\t"}deployedAt={.deployedAt}{"\n"}{end}'
```

---

### Pillar 3: Runtime compliance evidence — OTEL traces via Tempo

Lab 09 wired Tempo + OpenTelemetry Collector. Every MCP tool invocation (including `insurance_check` and GuardrailMiddleware-blocked queries) emits a span. The spans are queryable via TraceQL in Grafana Explore.

**TraceQL selectors:**

```
# Show all insurance_check invocations (last 1 hour)
{ resource.service.name = "mcp-insurance-check" }

# Show all guardrail-blocked queries (status=error means ToolError was raised)
{ resource.service.name =~ "mcp-.*" && status = error }

# Find the specific Aetna+root canal trace
{ resource.service.name = "mcp-insurance-check" && span.tool.arguments =~ ".*Aetna.*root canal.*" }
```

Open Grafana Explore to run these:

```bash
open http://localhost:30500/explore
# Select Tempo as the datasource, paste the TraceQL selector above, click Run query
```

Or query Tempo directly:

```bash
kubectl port-forward -n monitoring svc/tempo 3200:3200 &
curl -s 'http://localhost:3200/api/search?q=%7Bresource.service.name%3D%22mcp-insurance-check%22%7D' \
  | python3 -m json.tool | head -40
```

The cost middleware (Lab 09) exports `agent_llm_cost_usd_total` — for compliance reports, screenshot the Grafana "Smile Dental — LLM Cost" panel filtered to the audit time range.

---

### Running the full audit snapshot

The `audit-trail-queries.sh` script runs all three pillars in sequence and prints a snapshot suitable for saving to an audit log:

```bash
cd course-code/labs/lab-13/solution
bash governance/audit-trail-queries.sh
```

Sample output:

```
============================================================
  GUARD-03 — Governance audit snapshot
  Generated: 2026-05-04T14:30:00Z
============================================================

[Pillar 1] Model versioning — Lab 12 image-tag commit history
------------------------------------------------------------
Last 10 model-version bumps in the gitops-repo:
  abc1234 ci(lab-12): bump model-version to smollm2-135m-finetuned-20260504T143000Z (eval gate passed)

[Pillar 2] GitOps provenance — ArgoCD Application history
------------------------------------------------------------
argocd app history vllm:
  ID  DATE                          REVISION
  2   2026-05-04 14:31:05 +0000 UTC abc1234
  1   2026-05-04 12:10:33 +0000 UTC def5678

[Pillar 3] OTEL compliance evidence — Tempo trace selectors
------------------------------------------------------------
TraceQL selector for insurance_check spans (last 1 hour):
  { resource.service.name = "mcp-insurance-check" }
TraceQL selector for guardrail-blocked queries:
  { resource.service.name =~ "mcp-.*" && status = error }

============================================================
  Snapshot complete. Save this output to your audit log.
============================================================
```

### Why D-18 chose doc-only governance

Building a new audit dashboard or compliance scanner would have been scope creep. The existing stack already provides all three pillars. GUARD-03 teaches students to *use what they built* for compliance — showing that a properly instrumented LLMOps stack is also an audit trail. No new tooling required.

---

## Common Pitfalls

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| `docker push localhost:5001/...` hangs or times out | Docker Desktop routes `kind-registry:5001` through a proxy from the host | Use `localhost:5001` (not `kind-registry:5001`) for the `docker push` command from your terminal. KIND pods still reference `kind-registry:5001` in manifests — only the push from your laptop uses `localhost:5001`. |
| Warm pool pods still serving stale hermes-config after ConfigMap update | ConfigMap mounts are read by pods at startup, not on change (Pitfall 8) | `kubectl delete pod -l app=sandbox-warm-pool -n llm-agent` — the SandboxWarmPool controller refills the pool in ~30 seconds with the new config. |
| `mcp-insurance-check` pod fails to start: `ToolError` or `ImportError` at boot | `GuardrailMiddleware` registered via `mcp.add_middleware()` AFTER `mcp.http_app()` was called (Pitfall 9) | Middleware must be registered in the FastMCP constructor: `mcp = FastMCP("insurance_check", middleware=[GuardrailMiddleware()])` — inspect `insurance_check_server.py` to confirm this pattern is present before `mcp.http_app()`. |
| `insurance_check_server.py` works locally but fails in container | Container uses fastmcp `2.14.7` (pinned `>=2.0,<3.0`) while local may have fastmcp `3.x` | Both versions support the `middleware=[]` constructor arg and `mcp.http_app()`. If you see `AttributeError: 'FastMCP' has no attribute 'streamable_http_app'`, update to use `mcp.http_app(transport="streamable-http")` — the 2.x API. |
| `step-commit-tag` fails with `Permission denied (publickey)` | `companion-repo-ssh` in the WorkflowTemplate still points to the upstream stub `git@github.com:initcron/llmops.git` | Edit line ~27 of `101-workflowtemplate-llm-pipeline.yaml`, change to your fork URL, re-apply with `kubectl apply`. |
| `kubectl get secret git-deploy-key -n argo` returns NotFound | Deploy key Secret was created in the wrong namespace | `kubectl create secret generic git-deploy-key --from-file=id_ed25519=~/.ssh/lab12_deploy_key -n argo` — the Secret must be in the `argo` namespace, not `llm-agent`. |
| Phase 3 tools (`mcp-triage` etc.) don't apply guardrails on blocked queries | `wire-guardrails-into-existing-tools.sh` patches source but running containers were built before the patch | Layer 1 (SOUL.md scope prefix) is already active. Layer 2 middleware for Phase 3 tools requires image rebuild. See the extension exercise below for the rebuild commands. |
| Eval step writes `pass: false` even at threshold=0.7 with insurance items | `eval-set.jsonl` in the DeepEval container is still the old 12-item set (not rebuilt with 17 items) | Confirm the eval container is `v1.1.0`: `kubectl get workflowtemplate llm-pipeline -n argo -o yaml \| grep image`. If still `v1.0.0`, rebuild the DeepEval container with the 17-item set and update the WorkflowTemplate. |

---

## Lab Summary

You have completed the Day 3 capstone. Here is what you built and demonstrated:

- **insurance_check** deployed as the 4th MCP tool in the Smile Dental agent — 4 insurance providers, 3-5 treatments each, GuardrailMiddleware baked in from the start
- **GuardrailMiddleware wired** into all 4 MCP tools: insurance_check (Layer 2 live), Phase 3 tools (Layer 1 active; Layer 2 ready on rebuild); SOUL.md Scope constraint blocks out-of-scope queries before tool invocation
- **Eval set extended** from 12 to 17 items — 5 insurance Q&A cases covering Aetna, Cigna, MaxBupa, Star Health, and unknown-provider graceful handling
- **EVAL-02 PASS path demonstrated end-to-end**: eval(17 items) scored ≥ 0.7 → `commit-tag` ran → git push → ArgoCD synced vLLM Deployment annotation — the full GitOps loop closed
- **Capstone demo**: all 6 steps PASS (0.015962 USD cost delta, Aetna canonical response, blocked query disclaimer returned), confirmed in Grafana Tempo and the cost panel
- **GUARD-03 governance**: three-pillar audit trail (model versioning via Lab 12 commit-tag, deploy provenance via ArgoCD history, runtime evidence via OTEL Tempo) — no new tooling, all from Labs 09/11/12

---

## Extension Exercises

### Rebuild Phase 3 tool images with Layer 2 guardrails

After `wire-guardrails-into-existing-tools.sh` patches the source, rebuild each tool image:

```bash
cd course-code/labs/lab-07/solution

# Triage tool
docker build -t localhost:5001/mcp-triage:v1.1.0-guarded -f tools/triage/Dockerfile .
docker push localhost:5001/mcp-triage:v1.1.0-guarded
kind load docker-image kind-registry:5001/mcp-triage:v1.1.0-guarded --name llmops-kind
kubectl set image deploy/mcp-triage triage=kind-registry:5001/mcp-triage:v1.1.0-guarded -n llm-agent

# Treatment lookup tool
docker build -t localhost:5001/mcp-treatment-lookup:v1.1.0-guarded -f tools/treatment_lookup/Dockerfile .
docker push localhost:5001/mcp-treatment-lookup:v1.1.0-guarded
kind load docker-image kind-registry:5001/mcp-treatment-lookup:v1.1.0-guarded --name llmops-kind
kubectl set image deploy/mcp-treatment-lookup treatment-lookup=kind-registry:5001/mcp-treatment-lookup:v1.1.0-guarded -n llm-agent

# Book appointment tool
docker build -t localhost:5001/mcp-book-appointment:v1.1.0-guarded -f tools/book_appointment/Dockerfile .
docker push localhost:5001/mcp-book-appointment:v1.1.0-guarded
kind load docker-image kind-registry:5001/mcp-book-appointment:v1.1.0-guarded --name llmops-kind
kubectl set image deploy/mcp-book-appointment book-appointment=kind-registry:5001/mcp-book-appointment:v1.1.0-guarded -n llm-agent
```

After all 3 are rebuilt, run the capstone demo again. Step 6 (blocked query) will now trigger Layer 2 middleware directly on tool invocation, not just the SOUL.md scope prefix.

### Enable LLM scope-check (Layer 2 optional)

For a more nuanced guardrail — one that handles ambiguous borderline inputs that don't match the regex but are still out of scope — enable the LLM classifier:

```bash
kubectl set env deploy/mcp-insurance-check GUARDRAIL_LLM_CHECK=true -n llm-agent
```

This adds one Groq LLM call per tool invocation (max_tokens=8, temperature=0). Monitor your Groq free-tier quota before enabling in a high-traffic demo.

### Add a new insurance provider

Edit `course-code/labs/lab-13/solution/tools/insurance_check/insurance-coverage.json` to add a 5th provider. Rebuild the image, reload into KIND, roll the Deployment. Add 1-2 eval items covering the new provider to `eval-set.jsonl`, rebuild the DeepEval container (`v1.2.0`), and run the full pipeline. Observe the PASS path close the loop again.

---

## Next Steps

Day 3 is complete. You have built and deployed a production-grade LLMOps + AgentOps system on Kubernetes:

- **Day 1 (Labs 00-06):** KIND cluster, synthetic data, LoRA fine-tuning, OCI model packaging, vLLM serving, Chainlit UI, Prometheus + Grafana observability
- **Day 2 (Labs 07-09):** Hermes Agent with 3 MCP tools (triage, treatment lookup, book appointment), Kubernetes Agent Sandbox (SandboxCRD + warm pool + NetworkPolicy), OTEL cost tracking
- **Day 3 (Labs 10-13):** HPA/KEDA autoscaling, ArgoCD GitOps App-of-Apps, Argo Workflows eval gate pipeline, guardrails + insurance_check capstone

For pipeline and eval reference: [Lab 12: Pipelines + Eval Gate](./lab-12-pipelines.md)

For the full course resources, slides, and next steps: see the course homepage.
