# Phase 4: Production Ops + Capstone (Day 3) - Research

**Researched:** 2026-05-03
**Domain:** KEDA autoscaling on Prometheus metrics; ArgoCD App-of-Apps GitOps; Argo Workflows DAG with eval gate; FastMCP middleware guardrails; capstone integration of a new MCP tool through the entire pipeline
**Confidence:** HIGH on KEDA + ArgoCD + Argo Workflows install/CRDs (verified against current Helm chart releases and quick-start docs); HIGH on FastMCP middleware (confirmed in gofastmcp.com docs); MEDIUM on DeepEval-with-Groq custom-judge pattern (standard pattern but needs runtime verification on free-tier rate limits); MEDIUM on resource budget (live cluster currently unresponsive — KIND restart required before plan execution)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Lab 10 — Autoscaling
- **D-01:** Autoscaling target = **vLLM Deployment** (SmolLM2 serving). Single service, CPU-bound. RAG retriever and Chainlit do NOT scale in this lab. "Chat API" in REQUIREMENTS = vLLM OpenAI-compatible HTTP endpoint.
- **D-02:** Autoscaling primitive = **KEDA on `vllm:num_requests_running`** Prometheus trigger. Plain HPA on CPU rejected for vLLM. SCALE-01 (HPA on CPU) satisfied by a token HPA on RAG retriever as brief contrast.
- **D-03:** Loadgen = **`hey`** as a K8s Job, targeting vLLM `/v1/completions`. SCALE-03 satisfied.
- **D-04:** Demo win = **live pod count + RPS climbing in Grafana**, split-screen.
- **D-05:** **vLLM scale-back-up** is the first action of Lab 10 (`kubectl scale deploy vllm-smollm2 --replicas=1 -n llm-serving`), symmetric to Phase 3 D-19/D-20.

#### Lab 11 — GitOps
- **D-06:** GitOps scope = **Hybrid (App-of-Apps with meaningful subset)**. Onboards: vLLM Deployment, RAG retriever, Chainlit, agent Sandbox + SandboxWarmPool, monitoring stack (Tempo + OTEL collector — NOT kube-prometheus-stack). Argo Workflows controller and one-shot loadgen Job stay imperative.
- **D-07:** GitOps repo = **`course-code/labs/lab-11/solution/gitops-repo/`** sub-folder in companion repo. Single clone, single auth context.
- **D-08:** Bootstrap point = **Lab 11 itself, post-Lab 10**. Imperative first, declarative second.
- **D-09:** Promotion mechanic = **manual git commit → ArgoCD auto-sync** (3-min poll OR webhook — researcher picks). argocd-image-updater is rejected.
- **D-10:** Promotion target = **vLLM Deployment**. Real workload, not demo-echo.

#### Lab 12 — Pipeline + Eval Gate
- **D-11:** Pipeline DAG = **full** — `data-gen → train → merge → package → eval → commit-tag`. Re-runs Day 1 Labs 01–04 logic. Training reuses Lab 02's 50-step CPU LoRA (~5–10 min). Total ~15–20 min.
- **D-12:** Eval test set = **handcrafted ~10–20 dental Q&A pairs** at `course-code/labs/lab-12/solution/eval/eval-set.jsonl`. Each item: `{question, expected_answer, ground_truth_context}`.
- **D-13:** Eval metric = **faithfulness only** (DeepEval `FaithfulnessMetric`). Single threshold, single decision.
- **D-14:** Gate mechanic = **DeepEval as Argo Workflows step + git-cli commit step**. `build-image → deepeval-step (LLM-as-judge via Groq/Gemini, queries temp vLLM pod inside workflow) → if pass: git-commit-step writes new image tag → ArgoCD auto-syncs vLLM`. Conditional branch on eval result. EVAL-02 satisfied literally.

#### Lab 13 — Guardrails
- **D-15:** Guard layer = **MCP tool middleware + Hermes system prompt prefix** (two-layer). Layer 1: Hermes system prompt scope declaration. Layer 2: programmatic middleware on each MCP tool checks args before tool execution; small post-process step on agent response runs output filter.
- **D-16:** Input guardrail = **hybrid: regex fast-path + LLM-as-judge on uncertain**. Regex/keyword block-list (`prescribe`, `dose`, `diagnose me`, `medication for`, `MRI`) → fast block. If pass: tiny LLM scope-check via existing Groq/Gemini key.
- **D-17:** Output guardrail = **pattern check + disclaimer injection** (NOT LLM-as-judge — saves quota). Regex match for medical-advice phrases (`"I recommend you take"`, `"the diagnosis is"`, drug names from `course-code/labs/lab-13/solution/guardrails/blocklist.json`). On match, prepend canonical disclaimer.
- **D-18:** GUARD-03 = **documentation page + walkthrough section**, no new code. Ties Lab 12 image tag commits, ArgoCD Application history, OTEL traces (Lab 09).

#### Lab 13 — Capstone (CAP-01)
- **D-19:** Capstone = **guided `insurance_check` MCP tool, shipped end-to-end**. Spec: `insurance_check(provider: str, treatment: str) -> {covered: bool, estimated_coverage_pct: int, notes: str}`. Backed by static JSON map (3-4 providers × 5-6 treatments). Path: TDD → add to Hermes config → commit through GitOps sub-folder → extend `eval-set.jsonl` with insurance Q&A → Argo Workflows DAG runs eval → on pass, ArgoCD deploys → verify in Grafana via OTEL trace + cost panel.

#### Cross-Lab Resource Strategy
- **D-20:** **Honest scoping note for success criterion #2.** Hybrid scope (D-06) means ArgoCD manages a meaningful subset, not literally all components. Lab 11 page documents this explicitly.
- **D-21:** Resource budget assumption = full Day 3 stack fits 12-16GB Docker Desktop. Plan must include "scale agent Sandbox to 1 replica before starting" check at Lab 10 start.

### Claude's Discretion
- KEDA Helm chart version + install method; KEDA min/max replica bounds for vLLM; ScaledObject `pollingInterval` + `cooldownPeriod` values
- HPA values for the contrast moment on RAG retriever (CPU target %, min/max)
- ArgoCD Helm chart version + install command + values; App-of-Apps directory layout inside `gitops-repo/`; AppProject scoping
- Argo Workflows install method (Helm), namespace, RBAC for git-commit-step's SSH key Secret
- ArgoCD 3-min poll vs configuring a GitHub webhook for instant sync
- Exact 10-20 Q&A in `eval-set.jsonl` (researcher drafts, surfaced for user review during plan)
- Faithfulness threshold value (researcher recommends; default to ~0.7 if no other signal)
- Choice of LLM judge for DeepEval step (Groq llama-3.3-70b-versatile is the default)
- Specific regex/keyword list for input-side block-list and output-side blocklist
- Exact prompt engineering for the input scope-classifier LLM call
- `insurance_check` static data: provider list, treatment-coverage map values
- Container build / image registry strategy for the `insurance_check` tool image (reuses Phase 3 MCP tool pattern from Lab 07)
- Exact 5 dental Q&A items added to `eval-set.jsonl` for the capstone (insurance-related questions)

### Deferred Ideas (OUT OF SCOPE)
- Retroactive ArgoCD onboarding of all Day 1+2 components (kube-prometheus-stack, all Day 1 Jobs)
- `argocd-image-updater`
- Synthetic eval set generated each run
- Multi-metric DeepEval gate
- LLM-as-judge output guardrail
- Open-ended capstone
- Multi-track capstone
- Argo Workflows DAG light/heavy split
- GitHub webhook for instant ArgoCD sync (default 3-min poll)
- Separate gitops repo (multi-repo pattern)
- Local-only gitea Git server
- NeMo Guardrails / Guardrails-AI
- Network-policy-based agent isolation (kindnet doesn't enforce)
- Cost-tracking dashboard improvements
- Real calendar/EHR integration for booking
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCALE-01 | HPA on Chat API (CPU-based) | Per D-02, satisfied by a token HPA on RAG retriever (CPU 60% target, min 1, max 2) as brief contrast moment in Lab 10. Requires metrics-server install (not present on KIND by default — see Wave 0). |
| SCALE-02 | KEDA ScaledObject for Prometheus-driven scaling (RPS-based) | KEDA `keda.sh/v1alpha1` ScaledObject with prometheus trigger on `vllm:num_requests_running` against kube-prometheus-stack. Chart kedacore/keda 2.19.0, controller image v2.19.x. |
| SCALE-03 | Load generator job to demonstrate scaling | `williamyeh/hey:latest` (last updated ~7y ago but stable scratch/Go binary) OR build-locally `rakyll/hey` Dockerfile (entrypoint `/hey`). K8s Job pattern. |
| GITOPS-01 | ArgoCD deployed and managing all components via App-of-Apps | argo-cd Helm chart 9.5.11, deploys ArgoCD v3.3.9. App-of-Apps root Application + child Applications per onboarded component. Hybrid scope per D-06 (documented as honest scoping note D-20). |
| GITOPS-02 | Model promotion by updating ImageVolume tag in Git | Image tag lives in `gitops-repo/apps/vllm/30-deploy-vllm.yaml` (or values file). Student edits, commits; ArgoCD detects within 3 min (default `timeout.reconciliation` = 180s) and re-syncs. |
| GITOPS-03 | Argo Workflows DAG automating LLM pipeline | argo-workflows Helm chart 1.0.13 deploys Argo Workflows v4.0.5. WorkflowTemplate or one-shot Workflow CR. DAG steps with shared PVC for artifact passing (no S3 needed). |
| EVAL-01 | DeepEval test suite for RAG quality | deepeval 3.9.9 (pip), `from deepeval.metrics import FaithfulnessMetric`. Custom DeepEvalBaseLLM wrapping Groq OpenAI-compat endpoint. ~10-20 Smile Dental Q&A pairs. |
| EVAL-02 | Eval integrated into Argo Workflows as quality gate | DeepEval runs as DAG step; exit code 0/1 OR output parameter consumed by `when:` clause on git-commit-step. Failure halts pipeline; no new image tag commits. |
| GUARD-01 | Input validation and prompt safety filtering | FastMCP middleware (`from fastmcp.server.middleware import Middleware`) wrapping each `@mcp.tool()`. Hybrid: regex blocklist + small LLM scope-check. SOUL.md prefix as Layer 1 prompt declaration. |
| GUARD-02 | Output guardrails — block hallucinated medical advice | Post-process middleware `on_call_tool` after-phase OR Chainlit response post-processor. Regex match against blocklist.json + canonical disclaimer prepend/replace. |
| GUARD-03 | Governance overview — model versioning, audit trail, OTEL | Documentation-only (Lab 13 page final section). Ties Lab 12 commit history (model versions), ArgoCD Application history (deploy provenance), OTEL traces (runtime evidence). |
| CAP-01 | End-to-end exercise tying all components | `insurance_check` MCP tool: TDD with pytest → add to `hermes-config/config.yaml` mcp_servers + SOUL.md → commit to gitops-repo → eval-set.jsonl extension with insurance Q&A → Argo Workflows DAG passes eval → ArgoCD syncs new tag → Chainlit query "Does Aetna cover root canals?" → Hermes triages → treatment_lookup → insurance_check → OTEL trace shows 3 tool spans → Grafana cost panel ticks. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

These are global directives from `~/.claude/CLAUDE.md` (Coding Discipline section) plus project conventions extracted from `course-code/CLAUDE.md` (project context). The planner MUST verify each task complies before approval.

- **TDD mandatory** — no production code without a failing test first. Bug fix? Failing test reproducing bug, then fix. Skip only for: throwaway prototypes, generated code, config files. Applies to: `insurance_check` MCP tool, guardrail middleware, DeepEval test runner, ScaledObject reconciliation tests if any.
- **Verification before completion claims** — run tests + show output before claiming pass; run build + show exit code; verify after subagent work via VCS diff. Plan tasks must include evidence-gathering steps.
- **Systematic Debugging** — Phase 1 (read errors, reproduce, trace data flow). 3-Fix Rule: after 3 failed attempts, STOP and question the architecture.
- **Code Review** — after major features, before merge. Dispatch code-reviewer subagent with SHAs, plan, description.
- **GSD workflow enforcement** — no direct repo edits outside a GSD command (`/gsd:quick`, `/gsd:debug`, `/gsd:execute-phase`).
- **Use `fd` for file finding, `rg` for text search, `ast-grep` for code structure, `jq` for JSON, `yq` for YAML.**
- **Smile Dental** branding (not Atharva) globally; generic infrastructure namespaces (`llm-serving`, `llm-app`, `monitoring`, `argocd`, `argo-workflows`, `keda`).
- **Lab dir convention** — `course-code/labs/lab-NN/{starter,solution}/{k8s,scripts,...}` with zero-padded `lab-10`, `lab-11`, `lab-12`, `lab-13`.
- **Numbered K8s manifest files per range** — Day 3 takes 80-autoscaling (Lab 10), 90-gitops-bootstrap (Lab 11), 100-pipelines (Lab 12), 110-guardrails (Lab 13).
- **`uv pip install --system` for student-facing pip commands** (Phase 02.1 D-01); inside K8s init containers stay on `pip` (uv not available there).
- **MDX JSX comments** (`{/* */}`) not HTML comments (`<!-- -->`) in Docusaurus pages.
- **One Docusaurus page per lab** with structure: Goal → Prerequisites → Parts A-G → Common Pitfalls → Summary. Phase 3 finding: ~600 lines per page upper bound; longer pages overwhelm in workshop.
- **Cross-platform support** — every bash command runs on macOS + Git Bash on Windows. No fcntl, no Linux-only syscalls. Use `filelock` for cross-platform locking.
- **Live cluster verification mandatory** (PROJECT.md) — every plan ends with a live KIND verification step before being marked complete.
- **CPU-only, 16GB-laptop KIND constraint** — every new component must fit alongside existing stack within 12-16GB Docker Desktop allocation.

## Summary

Phase 4 productionizes the running Day 1+2 stack with four labs (10-13) covering autoscaling, GitOps, pipelines+eval, and guardrails+capstone. The technical stack is well-established and stable: KEDA 2.19, ArgoCD 9.5.11/v3.3.9, Argo Workflows 1.0.13/v4.0.5, DeepEval 3.9.9, FastMCP middleware (Phase 3 already pins fastmcp via `mcp[cli]` 1.27.0). Every external dependency has a CPU-friendly install path that fits a 12-16 GB Docker Desktop allocation, with one important caveat: the cluster is currently overloaded (API timeouts on `kubectl get nodes`) — the plan must rebuild KIND fresh and stage Phase 4 components in order before adding Lab 12's transient vLLM pod.

The single biggest decision the plan needs to make crisply is **artifact passing in Argo Workflows**. The default upstream pattern uses an artifact repository (S3/MinIO), which we don't want to add. The right pattern for a workshop on KIND is a shared PVC mounted into every DAG step (`/workspace`), so steps can write/read files without configuring an artifact driver. This keeps Lab 12 setup minimal.

The second-biggest decision is the **DeepEval LLM judge**. Groq's `llama-3.3-70b-versatile` (already pinned in Phase 3 as `LLM_MODEL`) is the right judge — students already have the API key, and free-tier 30 RPM × 6K TPM comfortably handles 10-20 eval items with one judge call each (the FaithfulnessMetric makes 2 LLM calls per item: one to extract claims, one to verify against context — so 20-40 calls total per eval run, well under rate limits but worth noting in the lab page).

**Primary recommendation:** Adopt the version pins in §Standard Stack verbatim. Sequence Lab 12's DAG with a shared PVC at `/workspace`, conditional `when:` gating on a DeepEval-emitted output parameter (`pass=true` / `pass=false`), and a final git-commit-step that mounts an SSH-key Secret. Use FastMCP middleware (`on_call_tool`) for input/output guardrails — confirmed available API. Put the scope declaration prefix in **SOUL.md** Layer 1 (Hermes prompt-assembly docs explicitly identify SOUL.md as Layer 1 of the system prompt; the existing project SOUL.md is already there).

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| KEDA Helm chart `kedacore/keda` | 2.19.0 (chart and controller) | Prometheus-driven autoscaling for vLLM | Current stable; Helm chart === appVersion in KEDA's release scheme. Drop-in PrometheusScaler. |
| ArgoCD Helm chart `argo/argo-cd` | 9.5.11 (chart) → ArgoCD v3.3.9 | GitOps engine | Latest stable as of 2026-05-01 release. Supports K8s 1.32+ (matches our pins). |
| Argo Workflows Helm chart `argo/argo-workflows` | 1.0.13 (chart) → Argo Workflows v4.0.5 | DAG pipeline engine for data → train → eval → commit | Latest stable as of 2026-04-23. v4 line is the default new-install track; v3.7.14 is parallel maintenance. |
| `deepeval` (pip) | 3.9.9 | RAG quality metrics — `FaithfulnessMetric` | 50+ research-backed metrics, supports custom LLM judge via `DeepEvalBaseLLM` wrapper. Last release 2026-04-28. Python ≥3.9. |
| `williamyeh/hey:latest` (Docker Hub) | last updated ~7y but stable | HTTP load generator (rakyll/hey wrapped in Docker) | Image is from a Go binary built with `scratch` base; entrypoint `/hey`. Works as one-shot K8s Job. Alternative: build local image from `rakyll/hey` Dockerfile if preferred. |
| `metrics-server` (kubectl manifest) | latest from kubernetes-sigs | HPA CPU metrics | NOT installed by default on KIND. Required for SCALE-01 (HPA on RAG retriever CPU). Install with `--kubelet-insecure-tls` flag for KIND. |
| `fastmcp` (already in mcp[cli] 1.27.0) | 1.27.x | MCP server middleware for guardrails | `Middleware` class with `on_call_tool` async hook supports pre/post-execution. `ToolError` raises rejection. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `argocd` CLI (Homebrew) | matches server (3.3.x) | Optional: bootstrap login + app create from CLI for instructor demos | Already installed at `/opt/homebrew/bin/argocd` on this machine. Lab uses `kubectl apply -f` for Application CRs to avoid extra CLI install. |
| `argo` CLI | matches server (4.0.x) | Optional: `argo submit` from CLI | Lab uses `kubectl create -f workflow.yaml` to avoid extra install. |
| `python:3.11-slim` (image) | latest | Base image for DAG step containers (data-gen, eval, train) | Already used in Lab 01-04. uv installs over pip in DAG steps. |
| `alpine/git:latest` | latest | git clone + commit + push step in DAG | Tiny, includes ssh client for SSH-key-based push. |
| `ghcr.io/groq/groq-python` (NOT used) | — | — | We call Groq via plain `openai` Python SDK with `base_url="https://api.groq.com/openai/v1"` (Phase 3 pattern). |
| `openai` (pip) | latest 1.x | OpenAI-compat client used inside DeepEval custom judge wrapper | DeepEval's `DeepEvalBaseLLM.generate()` wraps `OpenAI(base_url=..., api_key=...)`. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `williamyeh/hey:latest` | Build local image from `rakyll/hey/Dockerfile` and push to `kind-registry:5001` | Local build adds a setup step but removes "image last updated 7 years ago" anxiety. Recommend: use williamyeh/hey for v1 (works fine, scratch-based binary doesn't rot), document local-build as fallback in lab page if students can't pull from Docker Hub. |
| Argo Workflows `quick-start-minimal.yaml` (kubectl) | `argo/argo-workflows` Helm chart 1.0.13 | Helm chart is the recommended path (community-maintained, configurable). quick-start-minimal.yaml is for "getting started quickly" only and not customizable. We use Helm. |
| ArgoCD `kubectl apply -f manifests/install.yaml` | `argo/argo-cd` Helm chart 9.5.11 | Helm chart enables values-based config (NodePort, dex disable, server insecure). Plain manifest is fine but harder to override. We use Helm. |
| KEDA HTTP add-on (KEDA HTTP Scaler) | Prometheus scaler on `vllm:num_requests_running` | HTTP add-on requires installing keda-http-add-on chart + reconfiguring vLLM behind its proxy. Prometheus scaler reuses the existing kube-prometheus-stack with one CRD. Locked to Prometheus per D-02. |
| MinIO + S3 artifact passing in Argo Workflows | **Shared PVC mounted into every DAG step** at `/workspace` | MinIO adds 1 deployment + a Secret for access keys. PVC is one ReadWriteOnce volume bound to one node — fine for KIND single-node. Recommend PVC for workshop simplicity. |
| GitHub webhook for instant ArgoCD sync | Default 3-min polling | Webhook requires public ingress to KIND (ngrok or Cloudflare tunnel) — too much setup. 3-min polling is "show students the lag, then refresh manually with `argocd app sync` for the demo". Per D-09 Claude's discretion → we pick polling. |
| Output regex guardrail via Chainlit message handler | FastMCP `on_call_tool` middleware (after-phase) | FastMCP middleware fires inside the MCP tool process — works regardless of UI. Chainlit-only enforcement bypasses on direct Sandbox calls. Locked to MCP middleware per D-15 ("no Chainlit-only enforcement"). |

**Installation:**

```bash
# All Phase 4 helm-installable components in one shot
helm repo add kedacore https://kedacore.github.io/charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Lab 10
helm install keda kedacore/keda --version 2.19.0 \
  --namespace keda --create-namespace
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Patch metrics-server for KIND (kubelet self-signed certs):
kubectl patch deployment metrics-server -n kube-system --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Lab 11
helm install argocd argo/argo-cd --version 9.5.11 \
  --namespace argocd --create-namespace \
  --set configs.params."server\.insecure"=true \
  --set server.service.type=NodePort \
  --set server.service.nodePortHttp=30700 \
  --set dex.enabled=false \
  --set notifications.enabled=false \
  --set applicationSet.enabled=false

# Lab 12
helm install argo-workflows argo/argo-workflows --version 1.0.13 \
  --namespace argo --create-namespace \
  --set server.serviceType=NodePort \
  --set server.serviceNodePort=30800 \
  --set server.authModes='{server}' \
  --set workflow.serviceAccount.create=true \
  --set controller.workflowNamespaces='{argo}'

# Lab 13 — Python deps installed inside guardrail / DeepEval / insurance_check tool images
uv pip install --system deepeval==3.9.9 openai
```

**Version verification:** Run `npm view ...` equivalent for each:
```bash
helm search repo kedacore/keda --version 2.19.0       # confirm chart exists
helm search repo argo/argo-cd --version 9.5.11
helm search repo argo/argo-workflows --version 1.0.13
pip index versions deepeval | head -3                  # confirm 3.9.9 available
docker pull williamyeh/hey:latest                       # confirm image still pullable
```

Verified versions and publish dates as of research date 2026-05-03:
- KEDA 2.19.0 (chart Chart.yaml on artifacthub.io confirms 2.19.0)
- argo-cd 9.5.11, ArgoCD v3.3.9 (released 2026-05-01)
- argo-workflows 1.0.13, Argo Workflows v4.0.5 (released 2026-04-23)
- deepeval 3.9.9 (released 2026-04-28)
- williamyeh/hey:latest (Docker Hub, last updated ~7y but scratch-based Go binary; stable)

## Architecture Patterns

### Recommended Project Structure

Day 3 follows the Phase 1 lab dir convention (`labs/lab-NN/{starter,solution}/{k8s,scripts}`). Manifest numbering follows the established pattern (Phase 2: 10/30/40/50; Phase 3: 50/60/70). Day 3 ranges:

```
course-code/labs/
├── lab-10/                          # Autoscaling
│   ├── starter/
│   └── solution/
│       ├── k8s/
│       │   ├── 80-keda-scaledobject-vllm.yaml
│       │   ├── 80-hpa-rag-retriever.yaml
│       │   ├── 81-loadgen-job-hey.yaml
│       │   └── 82-grafana-dashboard-autoscaling-cm.yaml
│       └── scripts/
│           ├── install-keda.sh
│           ├── install-metrics-server.sh
│           └── run-loadgen.sh
├── lab-11/                          # GitOps
│   ├── starter/
│   └── solution/
│       ├── k8s/
│       │   ├── 90-argocd-namespace.yaml
│       │   ├── 90-argocd-helm-values.yaml      # commented values for `helm install ... -f`
│       │   ├── 91-app-of-apps.yaml             # root Application
│       │   └── 92-ssh-deploy-key-secret.yaml.example  # template, students fill in
│       ├── gitops-repo/                         # The actual git-tracked manifests
│       │   ├── apps/                            # Child Application CRs
│       │   │   ├── vllm.yaml
│       │   │   ├── rag-retriever.yaml
│       │   │   ├── chainlit.yaml
│       │   │   ├── agent-sandbox.yaml
│       │   │   └── monitoring-otel-tempo.yaml
│       │   └── bases/                           # The actual K8s manifests each child Application points to
│       │       ├── vllm/                        # Copies of lab-04/solution/k8s/30-deploy-vllm.yaml + 30-svc-vllm.yaml
│       │       ├── rag-retriever/               # Copies of lab-01/solution/k8s/*
│       │       ├── chainlit/                    # Copies of lab-05/solution/k8s/* (use the lab-09 day-2 variant)
│       │       ├── agent-sandbox/               # Copies of lab-08/solution/k8s/50-* and 60-*
│       │       └── monitoring/                  # Copies of lab-09/solution/k8s/70-* (Tempo + OTEL collector)
│       └── scripts/
│           ├── install-argocd.sh
│           └── argocd-login.sh
├── lab-12/                          # Pipeline + eval gate
│   ├── starter/
│   └── solution/
│       ├── k8s/
│       │   ├── 100-argo-workflows-rbac.yaml             # ServiceAccount + Role for git-commit-step (read API key Secret + workflow PVC)
│       │   ├── 100-pvc-pipeline-workspace.yaml          # Shared PVC for inter-step artifacts
│       │   ├── 100-secret-git-deploy-key.yaml.example   # Template for the SSH key Secret
│       │   ├── 100-secret-llm-api-keys.yaml.example     # Template for Groq/Gemini key Secret (already in llm-agent ns from Phase 3 — copy to argo)
│       │   ├── 101-workflowtemplate-llm-pipeline.yaml   # The DAG WorkflowTemplate
│       │   └── 102-workflow-llm-pipeline-run.yaml       # One-shot Workflow that triggers the template
│       ├── eval/
│       │   └── eval-set.jsonl                           # ~10-20 handcrafted Q&A pairs
│       ├── deepeval/
│       │   ├── Dockerfile
│       │   ├── requirements.txt
│       │   ├── run_eval.py                              # Loads eval-set.jsonl, runs FaithfulnessMetric, writes /tmp/pass.txt
│       │   ├── groq_judge.py                            # DeepEvalBaseLLM custom wrapper for Groq
│       │   └── test_run_eval.py
│       └── scripts/
│           ├── install-argo-workflows.sh
│           └── trigger-pipeline.sh
└── lab-13/                          # Guardrails + capstone
    ├── starter/
    └── solution/
        ├── k8s/
        │   ├── 110-mcp-insurance-check-deploy.yaml
        │   └── 110-hermes-config-cm-with-insurance.yaml      # Updated ConfigMap with insurance_check + scope-prefixed SOUL.md
        ├── guardrails/
        │   ├── __init__.py
        │   ├── middleware.py                                  # FastMCP Middleware subclass
        │   ├── blocklist.json                                 # Input regex patterns + output regex patterns + drug list
        │   ├── scope_check.py                                 # LLM scope classifier (1 call per uncertain query)
        │   ├── disclaimer.py                                  # Canonical disclaimer text + injection helper
        │   └── test_middleware.py                             # TDD test suite
        └── tools/
            └── insurance_check/
                ├── __init__.py
                ├── insurance_check_server.py                  # FastMCP server, mirrors triage_server.py pattern
                ├── insurance-coverage.json                    # 3-4 providers × 5-6 treatments static map
                ├── Dockerfile
                ├── requirements.txt
                └── test_insurance_check_server.py             # TDD RED-first
```

### Pattern 1: KEDA ScaledObject for vLLM (Prometheus trigger)

**What:** Scale vLLM Deployment based on the gauge `vllm:num_requests_waiting` (queue depth). When waiting > 0 sustained, add replicas.

**When to use:** Whenever the underlying workload exposes a saturation metric in Prometheus that maps better than CPU. vLLM CPU stays high regardless of load; queue depth is the actual saturation signal (per the Lab 06 dashboard description).

**Example:**
```yaml
# Source: keda.sh/docs/latest/scalers/prometheus/ + Lab 06 dashboard PromQL (vllm:num_requests_waiting)
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: vllm-smollm2
  namespace: llm-serving
spec:
  scaleTargetRef:
    name: vllm-smollm2          # Deployment name (matches lab-04/solution/k8s/30-deploy-vllm.yaml)
  pollingInterval: 15           # Check Prometheus every 15s
  cooldownPeriod: 300           # Wait 5 min after triggers stop before scaling down (vLLM cold start is 60-180s)
  minReplicaCount: 1            # Per CONTEXT discretion: NOT 0 (vLLM cold start is bad UX)
  maxReplicaCount: 3            # Per CONTEXT discretion: 3 fits 12-16GB Docker Desktop
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
      threshold: '1'             # If sustained 1+ requests waiting, add a replica
      query: vllm:num_requests_waiting
```

Note: the kube-prometheus-stack release name in this project is `kps` (per lab-06/solution/k8s/observability/50-servicemonitor-vllm.yaml `release: kps` selector). The Service name follows the kube-prometheus-stack chart convention `<release>-kube-prometheus-stack-prometheus` — researcher could not verify the exact Service name without a live cluster (cluster API is currently unresponsive). Plan must verify: `kubectl get svc -n monitoring -l app.kubernetes.io/name=prometheus` and use the returned name.

### Pattern 2: HPA on CPU for RAG retriever (SCALE-01 contrast)

**What:** A token HPA on the RAG retriever Deployment so SCALE-01 ("HPA on Chat API based on CPU") is satisfied with one resource.

**When to use:** Demonstrate the contrast between CPU-based HPA (works for stateless web services) and Prometheus-based KEDA (right for LLM serving). Lab 10 page narrates: "HPA on CPU is fine for the retriever — it's stateless and CPU-bound. It's the wrong tool for vLLM. Here's why."

**Example:**
```yaml
# Source: kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: rag-retriever
  namespace: llm-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: rag-retriever
  minReplicas: 1
  maxReplicas: 2          # Conservative for KIND footprint
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
```

**Prerequisite: metrics-server installed with `--kubelet-insecure-tls`.**

### Pattern 3: hey loadgen as one-shot Job

**What:** Run `hey` against vLLM `/v1/completions` with a fixed prompt; let the job produce sustained load for ~3 min so KEDA can react.

**When to use:** Lab 10 demo loadgen.

**Example:**
```yaml
# Source: github.com/rakyll/hey + williamyeh/hey Docker image (entrypoint /hey)
apiVersion: batch/v1
kind: Job
metadata:
  name: vllm-loadgen
  namespace: llm-serving
spec:
  ttlSecondsAfterFinished: 600
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: hey
        image: williamyeh/hey:latest        # Already at /hey; entrypoint is /hey
        args:
        - "-z"
        - "180s"                            # Run for 3 minutes
        - "-c"
        - "4"                               # 4 concurrent workers (matches max-num-seqs=1 × small queue depth)
        - "-q"
        - "2"                               # 2 RPS per worker = 8 RPS total — overshoots vLLM CPU, builds queue
        - "-m"
        - "POST"
        - "-H"
        - "Content-Type: application/json"
        - "-d"
        - '{"model":"smollm2-135m-finetuned","prompt":"What treatments does Smile Dental offer?","max_tokens":32}'
        - "http://vllm-smollm2.llm-serving.svc.cluster.local:8000/v1/completions"
```

Note: the served model name in lab-04 is `smollm2-135m-finetuned` (from `--served-model-name` flag in 30-deploy-vllm.yaml). NOT `smollm2`. Plan must use the correct name.

### Pattern 4: ArgoCD App-of-Apps with auto-sync + self-heal

**What:** A root Application that manages an `apps/` directory of child Applications. Each child Application points at its own `bases/<name>/` directory in the same gitops-repo subfolder.

**When to use:** Lab 11. Pedagogical clarity > flexibility (no Helm/Kustomize layering — plain YAML throughout).

**Example (root):**
```yaml
# Source: argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: smile-dental-apps
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/<org>/<companion-repo>.git
    path: course-code/labs/lab-11/solution/gitops-repo/apps
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Example (child — vLLM):**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vllm
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "10"   # Sync after monitoring (lower wave = earlier)
spec:
  project: default
  source:
    repoURL: https://github.com/<org>/<companion-repo>.git
    path: course-code/labs/lab-11/solution/gitops-repo/bases/vllm
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: llm-serving
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Sync wave order recommendation:
- Wave 0: monitoring (Tempo + OTEL collector) — must exist before agents trying to export traces
- Wave 10: vLLM, RAG retriever
- Wave 20: agent-sandbox (depends on monitoring + RAG)
- Wave 30: chainlit (front door, depends on everything else)

### Pattern 5: Argo Workflows DAG with shared PVC + conditional gate

**What:** A WorkflowTemplate with DAG steps that share a `/workspace` PVC for artifact passing. The eval step writes `/workspace/eval-pass.txt` (`true` or `false`) and exposes it as an output parameter. The git-commit-step has `when: "{{tasks.eval.outputs.parameters.pass}} == true"`.

**When to use:** Lab 12. Avoids configuring an artifact repository (S3/MinIO).

**Example skeleton:**
```yaml
# Source: argo-workflows.readthedocs.io/en/latest/walk-through/dag/ + walk-through/conditionals/
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: llm-pipeline
  namespace: argo
spec:
  entrypoint: pipeline
  serviceAccountName: argo-workflow            # Has RBAC to mount Secrets, patch ConfigMaps
  volumes:
  - name: workspace
    persistentVolumeClaim:
      claimName: pipeline-workspace
  - name: ssh-key
    secret:
      secretName: git-deploy-key
      defaultMode: 0400
  templates:
  - name: pipeline
    dag:
      tasks:
      - name: data-gen
        template: step-data-gen
      - name: train
        template: step-train
        dependencies: [data-gen]
      - name: merge
        template: step-merge
        dependencies: [train]
      - name: package
        template: step-package
        dependencies: [merge]
      - name: eval
        template: step-eval
        dependencies: [package]
      - name: commit-tag
        template: step-commit-tag
        dependencies: [eval]
        when: "{{tasks.eval.outputs.parameters.pass}} == true"

  - name: step-data-gen
    container:
      image: python:3.11-slim
      command: [sh, -c]
      args:
      - |
        uv pip install --system fastembed faiss-cpu numpy &&
        python /app/build_index.py &&    # Re-uses lab-01 logic
        cp -r /data/* /workspace/data/
      volumeMounts:
      - name: workspace
        mountPath: /workspace
      # ... (mount lab-01 code via ConfigMap)

  - name: step-eval
    container:
      image: kind-registry:5001/smile-dental-deepeval:v1.0.0
      command: [sh, -c]
      args:
      - python /app/run_eval.py --threshold 0.7 > /tmp/result.txt && cat /tmp/result.txt
      env:
      - name: GROQ_API_KEY
        valueFrom: { secretKeyRef: { name: llm-api-keys, key: groq-api-key } }
      - name: VLLM_URL                  # The transient vLLM in this DAG run
        value: http://localhost:8000    # Sidecar pattern OR a separate task that exposes a Service
      volumeMounts:
      - name: workspace
        mountPath: /workspace
    outputs:
      parameters:
      - name: pass
        valueFrom:
          path: /tmp/eval-pass.txt      # run_eval.py writes "true" or "false"

  - name: step-commit-tag
    container:
      image: alpine/git:latest
      command: [sh, -c]
      args:
      - |
        mkdir -p /root/.ssh && cp /etc/ssh-key/id_rsa /root/.ssh/ && chmod 600 /root/.ssh/id_rsa &&
        ssh-keyscan github.com >> /root/.ssh/known_hosts &&
        git config --global user.email "argo@smile-dental-course.local" &&
        git config --global user.name  "Argo Workflows" &&
        git clone git@github.com:<org>/<companion-repo>.git /repo &&
        cd /repo &&
        # Edit the image tag
        TAG=$(cat /workspace/new-image-tag.txt) &&
        sed -i "s|smollm2-135m-finetuned:.*|smollm2-135m-finetuned:${TAG}|" \
          course-code/labs/lab-11/solution/gitops-repo/bases/vllm/30-deploy-vllm.yaml &&
        git add . && git commit -m "ci: bump model tag to ${TAG}" && git push
      volumeMounts:
      - name: workspace
        mountPath: /workspace
      - name: ssh-key
        mountPath: /etc/ssh-key
        readOnly: true
```

### Pattern 6: Transient vLLM inside the DAG for eval

**What:** Lab 12 eval needs to query a vLLM instance loaded with the just-built model image. Two options were considered (per CONTEXT cross-cutting question 6):

- **(a) Launch a transient vLLM Job inside the workflow** that mounts the just-built ImageVolume with the new tag, wait for /health, then run DeepEval against it from the eval step.
- **(b) Deploy via ArgoCD into a "staging" namespace.**

**Recommendation:** **Option (a) — transient sidecar/Job pattern.** Simpler for workshop time budget; doesn't introduce a "staging" namespace concept. The eval step is itself a multi-container pod: `vllm` container as a sidecar (loads new model via ImageVolume) + `deepeval` container as the main (waits for vllm:8000/health, runs eval, writes pass.txt).

**Example:**
```yaml
- name: step-eval
  container:
    image: kind-registry:5001/smile-dental-deepeval:v1.0.0
    command: [sh, -c]
    args:
    - |
      # Wait for sidecar vllm to be ready
      until curl -sf http://localhost:8000/health; do sleep 5; done &&
      python /app/run_eval.py --vllm-url http://localhost:8000 --eval-set /workspace/eval-set.jsonl --threshold 0.7
    env:
    - name: GROQ_API_KEY
      valueFrom: { secretKeyRef: { name: llm-api-keys, key: groq-api-key } }
    volumeMounts:
    - name: workspace
      mountPath: /workspace
  sidecars:
  - name: vllm-eval
    image: schoolofdevops/vllm-cpu-nonuma:0.9.1
    args: [--model=/models/model, --host=0.0.0.0, --port=8000,
           --max-model-len=4096, --served-model-name=smollm2-eval,
           --dtype=float32, --disable-frontend-multiprocessing, --max-num-seqs=1]
    env:
    - { name: VLLM_TARGET_DEVICE, value: cpu }
    - { name: VLLM_CPU_KVCACHE_SPACE, value: "2" }
    volumeMounts:
    - name: model-image-volume
      mountPath: /models
      readOnly: true
  outputs:
    parameters:
    - name: pass
      valueFrom: { path: /tmp/eval-pass.txt }
```

Note: ImageVolume mounting inside the eval step needs a `volumes:` entry pointing at the freshly-built tag, which the package step writes to `/workspace/new-image-tag.txt`. Alternative simpler pattern: skip the ImageVolume and have the package step output the merged-model-folder to `/workspace/model/`, and have the vllm sidecar `--model=/workspace/model` instead. **Recommend the latter** (simpler, no ImageVolume gymnastics).

### Pattern 7: FastMCP middleware for guardrails (input + output)

**What:** Subclass `Middleware`, override `on_call_tool`, run pre-check on `context.message.arguments`, raise `ToolError` to reject. After `await call_next(context)`, run post-check on the result.

**When to use:** Lab 13 (D-15 two-layer guard). One middleware class registered on each MCP server (or a shared module imported by all three).

**Example:**
```python
# Source: gofastmcp.com/servers/middleware
from fastmcp.server.middleware import Middleware, MiddlewareContext
from fastmcp.exceptions import ToolError
import re, json, httpx, os

with open("/etc/guardrails/blocklist.json") as f:
    BLOCKLIST = json.load(f)

INPUT_REGEX = re.compile("|".join(BLOCKLIST["input_patterns"]), re.IGNORECASE)
OUTPUT_REGEX = re.compile("|".join(BLOCKLIST["output_patterns"]), re.IGNORECASE)
DISCLAIMER = ("Smile Dental cannot provide medical advice. "
              "For health concerns beyond dental care, please consult your physician.")

class GuardrailMiddleware(Middleware):
    async def on_call_tool(self, context: MiddlewareContext, call_next):
        # --- INPUT GUARDRAIL ---
        args_blob = json.dumps(context.message.arguments)
        if INPUT_REGEX.search(args_blob):
            raise ToolError(DISCLAIMER)            # Hard-block
        # (Optional) LLM scope-check on uncertain queries — gated by env flag to save quota
        if os.environ.get("GUARDRAIL_LLM_CHECK", "false").lower() == "true":
            scope_ok = await self._llm_scope_check(args_blob)
            if not scope_ok:
                raise ToolError(DISCLAIMER)

        # --- TOOL EXECUTION ---
        result = await call_next(context)

        # --- OUTPUT GUARDRAIL ---
        result_text = str(result)
        if OUTPUT_REGEX.search(result_text):
            # Replace OR prepend disclaimer
            return f"{DISCLAIMER}\n\n[Original response redacted: contained out-of-scope medical advice.]"
        return result

    async def _llm_scope_check(self, query: str) -> bool:
        async with httpx.AsyncClient(timeout=5) as c:
            r = await c.post(f"{os.environ['LLM_BASE_URL']}/chat/completions",
                headers={"Authorization": f"Bearer {os.environ['LLM_API_KEY']}"},
                json={"model": os.environ['LLM_MODEL'],
                      "messages": [{"role": "user",
                                    "content": f"Is this a question about a dental clinic? Answer only 'yes' or 'no'. Query: {query}"}],
                      "max_tokens": 8, "temperature": 0})
        return "yes" in r.json()["choices"][0]["message"]["content"].lower()
```

Register on each MCP server:
```python
# In insurance_check_server.py (and triage/treatment_lookup/book_appointment)
from guardrails.middleware import GuardrailMiddleware
mcp.add_middleware(GuardrailMiddleware())
```

### Pattern 8: Hermes scope declaration in SOUL.md (Layer 1 system prompt)

**What:** Hermes prompt-assembly explicitly identifies SOUL.md as Layer 1 of the system prompt. The existing project SOUL.md (`course-code/labs/lab-07/solution/hermes-config/SOUL.md`) already declares the agent's role and workflow; we extend it with a hard scope statement.

**When to use:** Lab 13 D-15 Layer 1 ("Hermes system prompt declares scope").

**Recommended addition to existing SOUL.md (prepend or append):**
```markdown
# Scope (HARD CONSTRAINT)

You ONLY answer questions about Smile Dental Clinic services: dental treatments, hours, policies, insurance coverage for dental procedures, and appointments.

For ANY question outside this scope (general medical advice, prescriptions, dosages, diagnoses of non-dental conditions, mental health, veterinary, legal, financial, or any other topic) you MUST decline politely with this exact text:

"Smile Dental cannot provide medical advice. For health concerns beyond dental care, please consult your physician."

Do not attempt to be helpful by answering off-scope questions. Decline and redirect.
```

Note: there is conflicting upstream guidance about whether SOUL.md or AGENTS.md is the right place for scope restrictions. The Hermes prompt-assembly doc unambiguously identifies **SOUL.md as Layer 1 (identity)** and **AGENTS.md as Layer 8 (project context)**. A scope restriction is identity-level (not project-level) — it's WHO Hermes is, not WHAT project it's working on. Recommend SOUL.md. Per D-15, the scope declaration must be in the system prompt prefix; SOUL.md is the canonical Layer-1 location.

### Anti-Patterns to Avoid

- **HPA on CPU for vLLM** — vLLM stays high-CPU even when idle; CPU-based HPA thrashes (D-02 reasoning). Always use a queue-depth signal (`vllm:num_requests_waiting`) via KEDA.
- **KEDA with `minReplicaCount: 0` for CPU vLLM** — vLLM cold start is 60-180s on CPU; users hit timeout. `minReplicaCount: 1` mandatory.
- **MinIO/S3 for Argo Workflows artifact passing on KIND** — adds a deployment + secret + access keys for no learning benefit. Use a shared PVC.
- **GitHub webhook for ArgoCD sync on KIND** — requires public ingress (ngrok/Cloudflare tunnel). Default 3-min polling is fine for a workshop demo (and instructor can `argocd app sync <name>` to force).
- **argocd-image-updater** — adds a controller and config complexity. Locked OUT per D-09. Manual git commit is the demo.
- **Network-policy-based agent isolation as a guardrail** — kindnet has no NetworkPolicy enforcement (Phase 3 D-7 finding). Code-based guardrails only.
- **LLM-as-judge for output filtering** — would 2x the LLM call cost per turn and exhaust free-tier quota. D-17 picked regex+disclaimer.
- **Onboarding kube-prometheus-stack into ArgoCD** — chart is huge; would explode Lab 11 footprint. D-06 keeps Prom/Grafana Helm-managed.
- **Scope declaration in `config.yaml` (looking for a `system_prompt_prefix:` field)** — Hermes has NO such field per prompt-assembly docs. Use SOUL.md or AGENTS.md.
- **Mounting an ImageVolume that doesn't exist yet in the eval step** — race condition between package-step push and eval-step pod scheduling. Use the simpler pattern: package step writes the merged model folder to the shared PVC, eval-step's vllm sidecar reads it from the PVC mount.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Custom autoscaler that watches Prometheus and patches Deployment.spec.replicas | A Python operator that polls Prom and `kubectl scale`s | KEDA ScaledObject | Edge cases: leader election, race with HPA, cooldowns, hysteresis, RBAC. KEDA solves all of these. |
| Custom GitOps reconciler reading manifests from git | `git pull` cron + `kubectl apply -f` | ArgoCD Application + auto-sync + self-heal | Self-heal for drift, prune for deletes, sync waves for ordering, history for audit. Shell loop misses every one. |
| Custom DAG runner with bash + cron | Sequential bash script with state files | Argo Workflows DAG | Restartability, parallel branches, conditional steps, artifact passing, retry policy, observable UI. |
| Custom RAG eval scoring | A Python script that string-matches expected answer | DeepEval `FaithfulnessMetric` (LLM-as-judge against retrieval context) | Real eval needs claim extraction + verification against retrieved chunks. String matching catches 5% of regressions. |
| Custom MCP middleware framework | Wrap each tool function manually with a decorator | FastMCP `Middleware` class with `on_call_tool` | Already in the package. Hooks into the server lifecycle correctly (before transport, before tool dispatch, after response). |
| Custom HTTP load generator | Python `asyncio + httpx` script | `hey` / `williamyeh/hey:latest` Job | Rate limiting, concurrency, percentile reporting, ramp-up — already done. Single binary. |
| Custom Prometheus client polling | Direct httpx scrape of /metrics | kube-prometheus-stack ServiceMonitor (already running from Phase 2) + KEDA's Prometheus scaler | Service discovery, label rewriting, scrape config — solved. |
| Custom git operations container with system git + ssh-agent | Build a Docker image with git, ssh, gnupg | `alpine/git:latest` | Tiny, includes ssh-keyscan, ready for Argo Workflows step. |
| Custom Hermes prompt prefix system | Patch hermes-agent code to inject a system prompt prefix | SOUL.md (Layer 1) | Hermes already loads SOUL.md as Layer 1 of the system prompt. Use the documented seam. |

**Key insight:** Phase 4 is the most "tooling-heavy" phase of the course. Every problem domain (autoscaling, GitOps, pipelines, evals, guardrails) has a mature, dedicated tool that handles edge cases the workshop wouldn't even discover. Hand-rolling here teaches anti-patterns. The course's value-add is composition: students learn to wire KEDA + ArgoCD + Argo Workflows + DeepEval + FastMCP middleware together into a coherent production story, not to build any one of them.

## Runtime State Inventory

> Phase 4 is greenfield (4 new labs); no rename/refactor. **Section omitted per template guidance.** All runtime state introduced is fresh (KEDA controller pods, ArgoCD apps, Argo Workflows controller, eval Pod transient state, new Hermes config ConfigMap, insurance-coverage.json).

That said, two pre-existing runtime-state items the plan must touch:

| Category | Item | Action Required |
|----------|------|------------------|
| Live service config | Existing `hermes-config` ConfigMap in `llm-agent` namespace (Phase 3, lab-08, `60-hermes-config-cm.yaml`) | Lab 13 updates this ConfigMap to add the `insurance_check` MCP server entry under `mcp_servers:` and to update SOUL.md with scope declaration. After ConfigMap update, the SandboxWarmPool's pods need to be replaced (cycled via `kubectl delete pod -l app=hermes-agent -n llm-agent` so warm pool refills with the new ConfigMap content). |
| Stored data | Existing `bookings` ConfigMap data (Phase 3, lab-08, `60-bookings-cm.yaml`) | NOT modified by Phase 4. Survives untouched. Documented for awareness. |
| OS-registered state | None (no Task Scheduler / launchd / pm2 dependencies) | None |
| Secrets/env vars | New Secrets to create in `argo` namespace: `git-deploy-key` (SSH private key for git-commit-step push), `llm-api-keys` (copy of Phase 3's same-name Secret from `llm-agent`, used by DeepEval step's Groq judge) | Plan must include Secret creation steps with `.example` templates committed to git (real values in untracked files). |
| Build artifacts | `kind-registry:5001/smile-dental-deepeval:v1.0.0` and `kind-registry:5001/smile-dental-insurance-check:v1.0.0` images | Build with `docker build && docker tag && docker push kind-registry:5001/...` AND `kind load docker-image` per Phase 3 D-? finding ("kind load docker-image required for new images — KIND worker nodes cannot resolve localhost:5001"). |

## Common Pitfalls

### Pitfall 1: KIND cluster currently overloaded — API timeouts on basic kubectl
**What goes wrong:** Live cluster check during research returned `Error from server (Timeout): the server was unable to return a response in the time allotted` for `kubectl get nodes`, `get deployment`, etc. After ~30 seconds, the API server stops responding; metrics API also unavailable.
**Why it happens:** Day 2 stack is still running with Hermes SandboxWarmPool replicas=2, vLLM scaled to 0 (per Phase 3 D-19) but everything else loaded — the cluster is at the edge of the Docker Desktop allocation.
**How to avoid:** Plan must include a **fresh-KIND prerequisite step** at the start of Phase 4 execution: run `cleanup-phase3.sh`, restart Docker Desktop with at least 14 GB allocation (preferably 16 GB), `kind create cluster --config ...`, then re-bootstrap Day 1+2 minimum services (Prom/Grafana, RAG retriever, Chainlit, agent Sandbox WarmPool replicas=1, vLLM replicas=1) before adding KEDA + ArgoCD + Argo Workflows + transient eval pod.
**Warning signs:** `kubectl top nodes` shows >85% memory; `kubectl get events -n kube-system` shows OOMKilled.

### Pitfall 2: KEDA `serverAddress` wrong for kube-prometheus-stack
**What goes wrong:** ScaledObject reports "no metric returned"; KEDA controller logs `connection refused` or `404 Not Found`.
**Why it happens:** The kube-prometheus-stack's Prometheus Service name depends on the Helm release name. The project uses `kps` as the release name (per Lab 06 ServiceMonitor `release: kps` selector) — so the Prometheus Service is `kps-kube-prometheus-stack-prometheus` not the default `prometheus-kube-prometheus-stack-prometheus`.
**How to avoid:** Plan task verifies the actual Service name with `kubectl get svc -n monitoring -l app.kubernetes.io/name=prometheus -o name` and uses the returned name in the ScaledObject. Document the resolved name in the Lab 10 page.
**Warning signs:** `kubectl get scaledobject -n llm-serving` shows `READY=False` and `STATUS=Error`; KEDA operator logs reference Prometheus connection errors.

### Pitfall 3: vLLM `--served-model-name` mismatch in loadgen and KEDA query
**What goes wrong:** `hey` returns 404; KEDA query returns no series.
**Why it happens:** Lab 04's vLLM Deployment uses `--served-model-name=smollm2-135m-finetuned` (NOT `smollm2`). The model name in the JSON body must match this exactly, and any PromQL with `model_name` label must match.
**How to avoid:** Use `model: "smollm2-135m-finetuned"` in hey's `-d` payload. KEDA query `vllm:num_requests_waiting` aggregates across all model_names so it works as written, but if you label-filter use `model_name="smollm2-135m-finetuned"`.
**Warning signs:** vLLM logs show `KeyError: model 'smollm2'`.

### Pitfall 4: KIND nodes can't pull `kind-registry:5001/...` if `kind load` not done
**What goes wrong:** Pods stuck in `ImagePullBackOff` with `failed to resolve reference` for any new image (DeepEval, insurance_check, possibly even the rebuilt model OCI image from Lab 12).
**Why it happens:** Phase 3 D-? finding: `kind load docker-image` required for new images. KIND worker nodes cannot resolve `localhost:5001` — they need the image side-loaded. (The `kind-registry:5001` Service hostname works for in-cluster pulls only when the registry container is wired to the KIND network with a name alias; this was set up by `bootstrap-kind.sh` per Phase 1.)
**How to avoid:** Document the build-and-load sequence for every new image in lab pages: `docker build -t kind-registry:5001/smile-dental-X:v1.0.0 . && docker push kind-registry:5001/smile-dental-X:v1.0.0 && kind load docker-image kind-registry:5001/smile-dental-X:v1.0.0 --name llmops-kind`.
**Warning signs:** `kubectl describe pod` shows `Failed to pull image: rpc error: code = Unknown desc = failed to resolve reference`.

### Pitfall 5: Argo Workflows artifact passing fails because no artifact repo configured
**What goes wrong:** Workflow fails at the first step with "no default artifact repository configured" or "S3 backend not available."
**Why it happens:** Default artifact passing in Argo Workflows requires an artifact repository (S3, MinIO, GCS). Without one, the `outputs.artifacts:` field will fail.
**How to avoid:** **Don't use `outputs.artifacts:` at all.** Use a shared PVC mounted into every step at `/workspace`, and have steps write/read files there directly. Output parameters (`outputs.parameters:` from a file path) work without an artifact repo and are sufficient for the eval pass/fail signal.
**Warning signs:** Workflow CR status shows `Failed - failed to upload artifact`.

### Pitfall 6: DeepEval Groq judge hits free-tier rate limit (30 RPM / 6K TPM)
**What goes wrong:** Eval step fails part-way with HTTP 429 from Groq.
**Why it happens:** FaithfulnessMetric makes 2 LLM calls per test case (claim extraction + verification). 20 test cases = 40 calls. Free tier is 30 RPM — eval batch can spike past 30 if cases run in parallel.
**How to avoid:** Run cases sequentially (default in DeepEval `evaluate()` is sequential). Add a 2-second sleep between cases to stay well under 30 RPM. Use `temperature=0.1` to keep judge stable. Document expected eval duration: ~60-90 seconds for 20 cases.
**Warning signs:** `openai.RateLimitError` in the eval step logs; partial pass.txt content.

### Pitfall 7: ArgoCD sync of vLLM Deployment fails because monitoring namespace not yet ready
**What goes wrong:** vLLM Application syncs but its associated ServiceMonitor (in monitoring namespace) doesn't exist; Prometheus stops scraping; KEDA ScaledObject reads stale metrics.
**Why it happens:** When ArgoCD bulk-syncs the App-of-Apps, sync order matters. If vLLM syncs before kube-prometheus-stack CRDs are ready (in our case kube-prometheus-stack is Helm-managed and stays up — but if a fresh student is rebuilding the cluster they may apply the App-of-Apps before kube-prometheus-stack finishes).
**How to avoid:** Use `argocd.argoproj.io/sync-wave` annotations on child Applications. Wave 0 = monitoring-related apps, wave 10 = workloads, wave 20 = agent, wave 30 = chainlit. Document in Lab 11 page.
**Warning signs:** Deployment runs but no metrics scraped; Grafana panels empty after sync.

### Pitfall 8: Hermes SandboxWarmPool doesn't pick up updated ConfigMap until pods cycle
**What goes wrong:** Lab 13 capstone: student updates `hermes-config` ConfigMap with `insurance_check` MCP server, ArgoCD syncs the new ConfigMap, but warm-pooled Hermes pods still use the old config.
**Why it happens:** ConfigMap mounts are propagated to pods, BUT the Hermes init container only copies ConfigMap content on pod startup (per Phase 3 D-? "emptyDir + initContainer(busybox) for HERMES_HOME — ConfigMap mounts are read-only; hermes entrypoint.sh writes to /opt/data"). Already-running pods don't re-read.
**How to avoid:** After ConfigMap update, plan task does `kubectl delete pod -l app=hermes-agent -n llm-agent`. The SandboxWarmPool refills with new pods that read the updated ConfigMap. Alternatively, use a checksum annotation on the SandboxTemplate spec.template.metadata.annotations to force pod restart on ConfigMap change.
**Warning signs:** Chainlit query "Does Aetna cover root canals?" returns "I don't have an `insurance_check` tool available" or similar.

### Pitfall 9: FastMCP middleware order matters and `add_middleware` returns None
**What goes wrong:** Middleware registered but never fires.
**Why it happens:** `mcp.add_middleware(GuardrailMiddleware())` must be called BEFORE `mcp.streamable_http_app()` is invoked. The pattern in existing tools (book_appointment_server.py:107) creates the app at module-bottom — middleware registration must precede that call.
**How to avoid:** Register middleware right after `FastMCP(...)` instantiation, before `setup_tracing()` and before any `streamable_http_app()` call.
**Warning signs:** Block-list patterns hit but tool still executes.

### Pitfall 10: Argo Workflows ServiceAccount RBAC missing for Secret access
**What goes wrong:** git-commit-step container starts but can't read the SSH-key Secret; or eval step can't read the Groq API key Secret.
**Why it happens:** Default `argo` ServiceAccount in `argo` namespace doesn't have `get` on Secrets. Workflow step Pods inherit the workflow's ServiceAccount.
**How to avoid:** Create a dedicated `argo-workflow` ServiceAccount in `argo` namespace with a Role granting `get` on Secrets `llm-api-keys` and `git-deploy-key`, then RoleBinding. Specify `serviceAccountName: argo-workflow` in the WorkflowTemplate spec.
**Warning signs:** Step pods stuck in `CreateContainerConfigError`.

## Code Examples

### KEDA ScaledObject — Lab 10
```yaml
# Source: keda.sh/docs/latest/scalers/prometheus/
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: vllm-smollm2
  namespace: llm-serving
spec:
  scaleTargetRef:
    name: vllm-smollm2
  pollingInterval: 15
  cooldownPeriod: 300
  minReplicaCount: 1
  maxReplicaCount: 3
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
      threshold: '1'
      query: vllm:num_requests_waiting
```

### HPA on RAG Retriever — Lab 10 (SCALE-01 contrast)
```yaml
# Source: kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: rag-retriever
  namespace: llm-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: rag-retriever
  minReplicas: 1
  maxReplicas: 2
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
```

### `hey` Load Job — Lab 10
```yaml
apiVersion: batch/v1
kind: Job
metadata: { name: vllm-loadgen, namespace: llm-serving }
spec:
  ttlSecondsAfterFinished: 600
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: hey
        image: williamyeh/hey:latest
        args:
        - "-z"; - "180s"; - "-c"; - "4"; - "-q"; - "2"
        - "-m"; - "POST"
        - "-H"; - "Content-Type: application/json"
        - "-d"
        - '{"model":"smollm2-135m-finetuned","prompt":"What treatments does Smile Dental offer?","max_tokens":32}'
        - "http://vllm-smollm2.llm-serving.svc.cluster.local:8000/v1/completions"
```
*(YAML spec note: the `args:` list above uses `;` for compactness in this research doc — generated lab YAML uses one `-` per array item.)*

### ArgoCD App-of-Apps Root — Lab 11
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: smile-dental-apps
  namespace: argocd
  finalizers: [resources-finalizer.argocd.argoproj.io]
spec:
  project: default
  source:
    repoURL: https://github.com/<org>/<companion-repo>.git
    path: course-code/labs/lab-11/solution/gitops-repo/apps
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated: { prune: true, selfHeal: true }
```

### DeepEval custom Groq judge — Lab 12
```python
# Source: deepeval.com/guides/guides-using-custom-llms
from openai import OpenAI
from deepeval.models import DeepEvalBaseLLM
from deepeval.metrics import FaithfulnessMetric
from deepeval.test_case import LLMTestCase
import os

class GroqJudge(DeepEvalBaseLLM):
    def __init__(self):
        self.client = OpenAI(
            base_url=os.environ["LLM_BASE_URL"],   # https://api.groq.com/openai/v1
            api_key=os.environ["GROQ_API_KEY"],
        )
        self.model_name = os.environ.get("LLM_MODEL", "llama-3.3-70b-versatile")
    def load_model(self): return self.client
    def generate(self, prompt: str) -> str:
        r = self.client.chat.completions.create(
            model=self.model_name,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.1, max_tokens=1024)
        return r.choices[0].message.content
    async def a_generate(self, prompt: str) -> str: return self.generate(prompt)
    def get_model_name(self): return self.model_name

judge = GroqJudge()
metric = FaithfulnessMetric(model=judge, threshold=0.7, include_reason=True)
test_case = LLMTestCase(
    input="What is the cost of a root canal at Smile Dental?",
    actual_output="A root canal at Smile Dental costs ₹4,500 to ₹6,500.",
    retrieval_context=["root canal: ₹4500-6500", "molar root canal: ₹6000+"])
metric.measure(test_case)
print(metric.score, metric.success, metric.reason)
```

### Argo Workflows DAG with conditional gate — Lab 12
```yaml
# Source: argo-workflows.readthedocs.io/en/latest/walk-through/conditionals/
# + walk-through/output-parameters/ + walk-through/dag/
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata: { name: llm-pipeline, namespace: argo }
spec:
  entrypoint: pipeline
  serviceAccountName: argo-workflow
  volumes:
  - name: workspace
    persistentVolumeClaim: { claimName: pipeline-workspace }
  - name: ssh-key
    secret: { secretName: git-deploy-key, defaultMode: 0400 }
  templates:
  - name: pipeline
    dag:
      tasks:
      - { name: data-gen, template: step-data-gen }
      - { name: train,    template: step-train,    dependencies: [data-gen] }
      - { name: merge,    template: step-merge,    dependencies: [train] }
      - { name: package,  template: step-package,  dependencies: [merge] }
      - { name: eval,     template: step-eval,     dependencies: [package] }
      - { name: commit-tag, template: step-commit-tag, dependencies: [eval],
          when: "{{tasks.eval.outputs.parameters.pass}} == true" }
  # Step templates omitted; see Pattern 5 + Pattern 6 above.
```

### FastMCP Guardrail Middleware — Lab 13
```python
# Source: gofastmcp.com/servers/middleware
from fastmcp.server.middleware import Middleware, MiddlewareContext
from fastmcp.exceptions import ToolError
import re, json, os

with open(os.environ.get("BLOCKLIST_PATH", "/etc/guardrails/blocklist.json")) as f:
    BLOCKLIST = json.load(f)

INPUT_RE = re.compile("|".join(BLOCKLIST["input_patterns"]), re.IGNORECASE)
OUTPUT_RE = re.compile("|".join(BLOCKLIST["output_patterns"]), re.IGNORECASE)
DISCLAIMER = ("Smile Dental cannot provide medical advice. "
              "For health concerns beyond dental care, please consult your physician.")

class GuardrailMiddleware(Middleware):
    async def on_call_tool(self, context: MiddlewareContext, call_next):
        if INPUT_RE.search(json.dumps(context.message.arguments)):
            raise ToolError(DISCLAIMER)
        result = await call_next(context)
        if OUTPUT_RE.search(str(result)):
            return f"{DISCLAIMER}\n\n[Original response redacted: contained out-of-scope content.]"
        return result
```

### insurance_check MCP tool — Lab 13 capstone
```python
# Mirrors course-code/labs/lab-07/solution/tools/treatment_lookup/treatment_lookup_server.py
import json, os
from mcp.server.fastmcp import FastMCP
from mcp.server.streamable_http import TransportSecuritySettings
from tools.otel_setup import setup_tracing
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from guardrails.middleware import GuardrailMiddleware

mcp = FastMCP(
    "insurance_check",
    json_response=True,
    transport_security=TransportSecuritySettings(enable_dns_rebinding_protection=False),
)
mcp.add_middleware(GuardrailMiddleware())
setup_tracing(service_name=os.environ.get("OTEL_SERVICE_NAME", "mcp-insurance-check"))

with open(os.environ.get("COVERAGE_PATH", "/data/insurance-coverage.json")) as f:
    COVERAGE: dict = json.load(f)

@mcp.tool()
def insurance_check(provider: str, treatment: str) -> dict:
    """Check whether a Smile Dental treatment is covered by an insurance provider.

    Args:
        provider: Insurance provider name (e.g., "Aetna", "Cigna", "MaxBupa", "Star Health").
        treatment: Dental treatment name (e.g., "root canal", "cleaning", "crown").
    Returns:
        {covered: bool, estimated_coverage_pct: int, notes: str}
    """
    p = COVERAGE.get(provider.strip().lower())
    if not p:
        return {"covered": False, "estimated_coverage_pct": 0,
                "notes": f"{provider} is not in our supported provider list."}
    t = p.get(treatment.strip().lower())
    if not t:
        return {"covered": False, "estimated_coverage_pct": 0,
                "notes": f"{treatment} is not covered by {provider}."}
    return {"covered": True, "estimated_coverage_pct": t["pct"], "notes": t["notes"]}

@mcp.custom_route("/health", methods=["GET"])
async def health(_request):
    from starlette.responses import JSONResponse
    return JSONResponse({"ok": True, "tool": "insurance_check"})

if __name__ == "__main__":
    import uvicorn
    _app = mcp.streamable_http_app()
    FastAPIInstrumentor.instrument_app(_app)
    uvicorn.run(_app, host="0.0.0.0", port=int(os.environ.get("PORT", "8040")))
```

### insurance-coverage.json — Lab 13 capstone
```json
{
  "aetna": {
    "root canal":  {"pct": 80, "notes": "Aetna covers 80% of root canal cost up to ₹15,000."},
    "cleaning":    {"pct": 100, "notes": "Aetna covers all preventive cleanings (2 per year)."},
    "crown":       {"pct": 50, "notes": "Aetna covers 50% of crown cost up to ₹20,000."},
    "extraction":  {"pct": 80, "notes": "Aetna covers 80% of extractions."},
    "filling":     {"pct": 100, "notes": "Aetna covers 100% of standard fillings."}
  },
  "cigna": {
    "root canal":  {"pct": 75, "notes": "Cigna covers 75% after ₹2,000 deductible."},
    "cleaning":    {"pct": 100, "notes": "Cigna covers all preventive cleanings."},
    "crown":       {"pct": 50, "notes": "Cigna covers 50%, lifetime max ₹50,000."}
  },
  "maxbupa": {
    "root canal":  {"pct": 60, "notes": "MaxBupa covers 60% under hospitalization rider only."},
    "cleaning":    {"pct": 0,  "notes": "MaxBupa does not cover preventive cleanings."},
    "extraction":  {"pct": 70, "notes": "MaxBupa covers 70% of surgical extractions."}
  },
  "star health": {
    "root canal":  {"pct": 50, "notes": "Star Health covers 50% under accident-only dental rider."},
    "filling":     {"pct": 80, "notes": "Star Health covers 80% of fillings if accident-related."}
  }
}
```

### eval-set.jsonl — Lab 12 (sample 4 of ~15-20 items; researcher draft)
```jsonl
{"question": "How much does a root canal cost at Smile Dental?", "expected_answer": "A root canal at Smile Dental costs between ₹4,500 and ₹6,500 depending on tooth location.", "ground_truth_context": ["Treatment: root canal. Cost: ₹4,500-₹6,500. Duration: 60-90 min."]}
{"question": "What are Smile Dental's hours on Sunday?", "expected_answer": "Smile Dental is open 10 AM to 4 PM on Sundays for emergencies only.", "ground_truth_context": ["Hours: Mon-Sat 9 AM-7 PM. Sunday 10 AM-4 PM emergencies only."]}
{"question": "Do I need an appointment for a routine cleaning?", "expected_answer": "Yes, routine cleanings are by appointment. Walk-ins are accepted only for severe pain.", "ground_truth_context": ["Walk-in policy: severe pain only. All other visits by appointment."]}
{"question": "Does Aetna cover root canals at Smile Dental?", "expected_answer": "Yes, Aetna typically covers 80% of root canal cost up to ₹15,000 at Smile Dental.", "ground_truth_context": ["Insurance: Aetna covers 80% of root canal up to ₹15,000."]}
```

### blocklist.json — Lab 13 (researcher draft starter set)
```json
{
  "input_patterns": [
    "\\bprescribe\\b", "\\bdose of\\b", "\\bdosage\\b", "\\bmilligrams\\b",
    "\\bdiagnose me\\b", "\\bmedication for\\b", "\\bMRI\\b", "\\bCT scan\\b",
    "\\bantibiotic\\b", "\\bibuprofen\\b", "\\bamoxicillin\\b",
    "what should I take for", "is it safe to take", "how much .* should I",
    "my (dog|cat|child|baby) has",
    "(suicide|self.harm|kill myself|end my life)"
  ],
  "output_patterns": [
    "I recommend you take \\d+",
    "the diagnosis is",
    "you should take \\d+ ?(mg|grams|tablets)",
    "\\b(ibuprofen|amoxicillin|paracetamol|aspirin) \\d+\\s?mg\\b"
  ],
  "drug_list": ["ibuprofen", "amoxicillin", "paracetamol", "aspirin",
                "tramadol", "codeine", "oxycodone", "morphine"]
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| HPA on CPU/memory for everything | Custom-metric autoscaling via KEDA + Prometheus scaler | KEDA reached v2 in 2021; standard for queue-depth-driven workloads (LLM serving especially) | Course teaches the right tool for vLLM (queue depth) AND keeps HPA-on-CPU as the contrast example for stateless web apps. |
| Argo Workflows artifacts via S3/GCS by default | For local/KIND demos: shared PVC with `/workspace` mount | Always an option, increasingly common pattern for local dev | One less component (MinIO). Tradeoff: PVC is single-node ReadWriteOnce — fine for KIND single-node. |
| Helm-only GitOps | App-of-Apps with mixed-source children | ArgoCD 2.x onwards | Single root Application bootstraps everything; child Applications can mix Helm/Kustomize/raw YAML. We use raw YAML for pedagogy. |
| LLM eval = manual review | DeepEval / Promptfoo / RAGAS — automated metrics with LLM-as-judge | DeepEval released 2024; G-Eval and faithfulness metrics now standard | Course teaches modern eval-gate pattern; failing builds = no deploy. |
| FastMCP <2.0 didn't have middleware | FastMCP 2.x adds `Middleware` class with `on_call_tool`, `on_request`, etc. | FastMCP 2.x | First-class hook for guardrails. No need for custom decorator wrapping. |
| ArgoCD "all components in one App-of-Apps" | Sync-wave annotations to order child Applications | ArgoCD 2.x | Critical for our case: monitoring before workloads, infrastructure before agents. |
| `vllm:gpu_cache_usage_perc` metric (vLLM ≤0.10) | `vllm:kv_cache_usage_perc` (vLLM 0.13+) | Renamed during the V1 metrics refactor | **NOT relevant for this course — we pin vLLM 0.9.1 which still uses `vllm:gpu_cache_usage_perc`** (per Lab 06 dashboard `vllm:gpu_cache_usage_perc` legend). KEDA queries `vllm:num_requests_waiting` and `vllm:num_requests_running` which are stable across versions. |

**Deprecated/outdated:**
- ArgoCD Helm chart 5.x/6.x/7.x: missing `configs.params.server.insecure` setting; pre-9.x had different values structure.
- Argo Workflows v2.x/v3.x DAG syntax mostly stable, but auth modes changed in v3.x → v4.x. Current chart pins v4.0.5 with `--auth-mode=server` (per quick-start).
- DeepEval ≤2.x had different `BaseLLM` class name (was `BaseEvaluationModel`). 3.x uses `DeepEvalBaseLLM`.

## Open Questions

1. **Exact kube-prometheus-stack Prometheus Service name (cluster currently unresponsive)**
   - What we know: project uses `kps` as Helm release name (Lab 06 ServiceMonitor `release: kps` confirms). Conventional pattern: `<release>-kube-prometheus-stack-prometheus`.
   - What's unclear: kube-prometheus-stack chart sometimes truncates at `kps-kube-prometheus-prometheus` depending on chart version.
   - Recommendation: Plan task verifies with `kubectl get svc -n monitoring -l app.kubernetes.io/name=prometheus -o name` BEFORE writing the ScaledObject. Update the manifest with the actual Service name. Document the resolved name in the Lab 10 page.

2. **Whether vLLM 0.9.1 emits `vllm:num_requests_waiting` correctly**
   - What we know: All recent vLLM docs (0.6+, 0.8.5, stable, latest dev preview) list both `vllm:num_requests_running` AND `vllm:num_requests_waiting`. Lab 06 dashboard already uses both.
   - What's unclear: nothing — both confirmed in production_metrics list across versions.
   - Recommendation: Confirmed during plan execution by `curl http://vllm-smollm2.llm-serving.svc.cluster.local:8000/metrics | grep vllm:num_requests_waiting` after vLLM is scaled back to 1 replica.

3. **`williamyeh/hey:latest` reliability long-term**
   - What we know: Image hasn't been updated in ~7 years but the `rakyll/hey` Go binary is stable (HTTP load gen — no protocol churn). scratch base image, no shared libs to rot.
   - What's unclear: whether Docker Hub policy might eventually delete unmaintained images (Docker Hub now has aggressive cleanup policies for unused free-tier repos).
   - Recommendation: Document in Lab 10 page a fallback: build local image from `https://github.com/rakyll/hey/blob/master/Dockerfile`, push to `kind-registry:5001/hey:v1.0.0`, `kind load docker-image`. COURSE_VERSIONS.md notes both options.

4. **DeepEval rate limit math under Groq free tier (30 RPM, 6K TPM)**
   - What we know: FaithfulnessMetric makes 2 LLM calls per test case. 20 cases × 2 = 40 calls. Sequential execution at ~1 call per 2 seconds = 20 calls per minute, well under 30 RPM. TPM is the trickier limit — claim extraction prompts can be long if retrieval_context is large.
   - What's unclear: actual TPM consumption per test case (claim extraction prompt size depends on retrieval_context length).
   - Recommendation: Plan task does a dry-run of the eval step with 5 cases first; measure latency and tokens used; extrapolate. Add a `time.sleep(2.0)` between cases if TPM headroom is tight. Document Gemini 2.5 Flash as fallback (10 RPM is tighter, but 1M context = no TPM concern).

5. **ArgoCD onboarding of agent Sandbox: does it need the Sandbox CRD installed first?**
   - What we know: Agent Sandbox CRDs are installed in Phase 3 Lab 08. They persist through Lab 11. ArgoCD just needs to apply Sandbox CRs; CRDs are pre-existing.
   - What's unclear: nothing — CRDs aren't garbage-collected by ArgoCD prune unless explicitly tracked.
   - Recommendation: gitops-repo `bases/agent-sandbox/` ONLY contains the Sandbox CRs (SandboxTemplate, SandboxWarmPool, NetworkPolicy, the MCP tool Deployments, ConfigMaps), NOT the Agent Sandbox CRDs themselves (those came from Phase 3 imperative install). Document this separation in Lab 11 page.

6. **PVC ReadWriteOnce limitation when DAG steps run on different nodes**
   - What we know: KIND clusters in this course are single-node (or node + worker — config controls this). The Phase 1 default `kind-config.yaml` should be confirmed.
   - What's unclear: if a multi-node KIND config is used, ReadWriteOnce PVC will pin all DAG steps to one node (pod scheduling will fail otherwise).
   - Recommendation: Confirm KIND config has a single worker node OR pin all DAG step pods to the same node via `nodeSelector` (already pattern in Lab 04 — `nodeName: llmops-kind-worker`). Add this to the WorkflowTemplate steps explicitly.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `helm` | KEDA, ArgoCD, Argo Workflows installs | ✓ | 3.18.4 | — |
| `kubectl` | All K8s ops | ✓ | 1.32.3 (client) | — |
| `kind` | Cluster restart if needed | ✓ | 0.27.0 | — |
| `docker` | Image builds (DeepEval, insurance_check), `williamyeh/hey` pull | ✓ | 28.4.0 | — |
| `argocd` CLI | Optional: instructor demos (`argocd app sync`, `argocd login`) | ✓ | At `/opt/homebrew/bin/argocd`; version not probed | Lab uses `kubectl apply -f` for Application CRs — CLI not strictly required |
| `argo` CLI | Optional: `argo submit` from CLI for instructor demos | ✗ | — | Lab uses `kubectl create -f workflow.yaml` — CLI not strictly required |
| KIND cluster `kind-llmops-kind` | All Lab 10-13 work | ⚠️ Running but UNRESPONSIVE | API timeouts on `kubectl get nodes` | Plan must include "rebuild KIND fresh" prerequisite step at Phase 4 start |
| `metrics-server` | HPA on RAG retriever (SCALE-01) | ✗ | Not installed | Install via `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml` + patch `--kubelet-insecure-tls` |
| Docker Desktop memory ≥14 GB | Full Day 3 stack | Unknown | — | If allocation < 14 GB, plan must surface a "go to Docker Desktop > Resources, set to 16 GB" prerequisite before Phase 4 |
| Groq API key (free tier) | Lab 12 DeepEval judge + Lab 13 LLM scope-check | Already set in env from Phase 3 | — | Gemini 2.5 Flash via Google API key as fallback (per Phase 3 D-04) |
| GitHub repo deploy key (write access) | Lab 12 git-commit-step | ✗ Not yet created | — | Plan task includes `ssh-keygen + GitHub Settings > Deploy keys (Allow write access)` step. Lab 11 creates the K8s Secret skeleton; Lab 12 fills in the value. |
| `kind-registry:5001` | Image push for new images | Should be running from Phase 1 bootstrap | — | If down: `bootstrap-kind.sh` re-creates it |
| FastMCP 2.x with `Middleware` class | Lab 13 guardrails | Already installed via `mcp[cli]` 1.27.0 (Phase 3 pin) | 1.27.0 | — |

**Missing dependencies with no fallback:**
- None — all required deps either available or installable in Phase 4 itself.

**Missing dependencies with fallback:**
- `metrics-server` — install in Lab 10 setup task
- `argo` CLI — use `kubectl` instead (negligible UX difference for workshop)
- KIND cluster responsive state — rebuild from scratch as Phase 4 prerequisite step
- GitHub deploy key — create as Lab 11 / Lab 12 setup step

## COURSE_VERSIONS.md additions for Phase 4

Add a new section (per the existing organization pattern in `course-code/COURSE_VERSIONS.md`):

```markdown
## Production Ops + Capstone (Day 3)

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| KEDA (Helm chart `kedacore/keda`) | 2.19.0 | Latest stable; supports Prometheus scaler; works with K8s 1.30+ (we run 1.34). Controller image v2.19.x. Footprint ~150 MB across operator + metrics-apiserver + admission-webhooks pods. |
| metrics-server | latest (`https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`) | Required for SCALE-01 HPA on CPU. Patch with `--kubelet-insecure-tls` for KIND. |
| ArgoCD (Helm chart `argo/argo-cd`) | 9.5.11 (deploys ArgoCD v3.3.9) | Latest stable as of 2026-05-01. Supports K8s 1.32-1.35. Default values overridden: `dex.enabled=false`, `notifications.enabled=false`, `applicationSet.enabled=false`, `server.service.type=NodePort`, `server.service.nodePortHttp=30700`, `configs.params."server\.insecure"=true`. |
| `argocd` CLI | matches server (3.3.x) | Optional; lab uses `kubectl apply -f` for Application CRs. |
| Argo Workflows (Helm chart `argo/argo-workflows`) | 1.0.13 (deploys Argo Workflows v4.0.5) | Latest stable as of 2026-04-23. v4 line is the default new-install track. Default values: `server.serviceType=NodePort`, `server.serviceNodePort=30800`, `server.authModes={server}`. |
| `argo` CLI | matches server (4.0.x) | Optional; lab uses `kubectl create -f` for Workflow CRs. |
| `deepeval` (pip, used in Lab 12 eval container) | 3.9.9 | Latest stable as of 2026-04-28. `FaithfulnessMetric` works with custom Groq judge via `DeepEvalBaseLLM` wrapper. Python ≥3.9. |
| `openai` (pip, used in DeepEval custom judge) | 1.x latest | OpenAI-compatible client for Groq endpoint. |
| `williamyeh/hey:latest` (Docker Hub) | latest | scratch-based Go binary (rakyll/hey 0.1.4); image last updated ~7y but stable. Entrypoint `/hey`. Fallback: build from `https://github.com/rakyll/hey/blob/master/Dockerfile` and push to `kind-registry:5001/hey:v1.0.0`. |
| `alpine/git:latest` (Docker Hub) | latest | Used by Argo Workflows git-commit-step. Includes ssh-keyscan, git, openssh-client. |
| `python:3.11-slim` (Docker Hub) | latest | Base for data-gen, train, merge, package, eval Python steps. Already used in Phase 2. |
```

Also add to `course-code/config.env` (after the Phase 3 block):

```bash
# Day 3 — Production Ops namespaces and image pins (Phase 4)
NS_KEDA=keda
NS_ARGOCD=argocd        # Already declared in Phase 1 block — verify no duplicate
NS_ARGO=argo            # Replaces NS_ARGO_WORKFLOWS=argo-workflows (per chart's recommended `argo` namespace)
KEDA_VERSION=2.19.0
ARGOCD_CHART_VERSION=9.5.11
ARGO_WORKFLOWS_CHART_VERSION=1.0.13
DEEPEVAL_VERSION=3.9.9
HEY_IMAGE=williamyeh/hey:latest
ALPINE_GIT_IMAGE=alpine/git:latest
# NodePorts in use (existing): 30200 vLLM, 30300 Chainlit, 30500 Grafana, 31001 RAG retriever (quick task)
# NodePorts added Day 3:
NODEPORT_ARGOCD=30700
NODEPORT_ARGO_WORKFLOWS=30800
```

## Lab ordering rationale + cross-cutting checks

**Lab 10 → 11 → 12 → 13** sequencing is correct. Each lab leaves the cluster in a state the next consumes:
- Lab 10 leaves: vLLM scaled-back-to-1 + KEDA running + HPA on RAG + a still-imperatively-applied stack (everything kubectl-applied)
- Lab 11 leaves: ArgoCD running + the same stack now declaratively-managed (App-of-Apps points at vLLM, RAG, Chainlit, agent-sandbox, Tempo, OTEL collector). KEDA ScaledObject (Lab 10) NOT moved into ArgoCD — it's an "infra" CRD that stays imperative (consistent with KEDA controller itself staying imperative).
- Lab 12 leaves: Argo Workflows running + at least one successful pipeline run that committed a new image tag to gitops-repo + ArgoCD has synced a new vLLM tag (proving end-to-end). One intentional eval-failure demo run that did NOT commit (proving the gate works).
- Lab 13 leaves: GuardrailMiddleware deployed on all 4 MCP tools (3 from Phase 3 + the new insurance_check) + updated `hermes-config` ConfigMap with insurance_check + scope-prefixed SOUL.md + capstone end-to-end flow demonstrated.

## cleanup-phase4.sh

Following Phase 1 D-15/D-16 pattern (per-CRD `kubectl delete --ignore-not-found` + `helm status` guard). Skeleton:

```bash
#!/usr/bin/env bash
# cleanup-phase4.sh — End of Day 3 teardown
set -euo pipefail

# Delete custom CRs first (avoid finalizer races)
kubectl delete scaledobject vllm-smollm2 -n llm-serving --ignore-not-found
kubectl delete hpa rag-retriever -n llm-app --ignore-not-found
kubectl delete job vllm-loadgen -n llm-serving --ignore-not-found
kubectl delete workflowtemplate llm-pipeline -n argo --ignore-not-found
kubectl delete workflows --all -n argo --ignore-not-found
kubectl delete applications --all -n argocd --ignore-not-found
kubectl delete sandboxtemplate hermes-agent-template -n llm-agent --ignore-not-found  # Recreate from imperative apply if continuing
# ... (per-CRD list)

# Helm uninstalls with status guard (per Phase 1 pattern)
for release in argocd argo-workflows keda; do
  ns_var="NS_${release^^}"
  ns="${!ns_var:-$release}"
  if helm status "$release" -n "$ns" >/dev/null 2>&1; then
    helm uninstall "$release" -n "$ns"
  fi
done

# Remove namespaces only if empty
kubectl delete namespace keda --ignore-not-found
kubectl delete namespace argocd --ignore-not-found
kubectl delete namespace argo --ignore-not-found

echo "Phase 4 components removed. Day 1+2 stack still running. Run cleanup-phase3.sh next to remove Day 2."
```

## Sources

### Primary (HIGH confidence)
- KEDA docs `https://keda.sh/docs/latest/deploy/` and `/scalers/prometheus/` — chart 2.19.0, ScaledObject CRD spec, Prometheus trigger metadata
- ArgoCD docs `https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/` and `/cluster-bootstrapping/` — install methods, App-of-Apps pattern, root + child Application YAML, sync waves, auto-sync + self-heal
- Argo Workflows docs `https://argo-workflows.readthedocs.io/en/latest/quick-start/` and `/walk-through/{dag,conditionals,output-parameters,artifacts,secrets}/` — install, DAG syntax, when: conditional, output parameters, artifact passing limits, Secret mounting
- ArgoHub Chart.yaml inspection (via `https://github.com/argoproj/argo-helm/blob/main/charts/{argo-cd,argo-workflows}/Chart.yaml`) — chart 9.5.11 deploys ArgoCD v3.3.9; chart 1.0.13 deploys Argo Workflows v4.0.5 (verified 2026-05-03)
- DeepEval docs `https://deepeval.com/docs/metrics-faithfulness` and `/guides/guides-using-custom-llms` — FaithfulnessMetric API, custom DeepEvalBaseLLM pattern with OpenAI-compat endpoints (Groq examples shown)
- DeepEval PyPI `https://pypi.org/project/deepeval/` — version 3.9.9 (released 2026-04-28), Python ≥3.9
- FastMCP docs `https://gofastmcp.com/servers/middleware` — Middleware class, on_call_tool hook, ToolError exception, registration order
- Hermes Agent docs `https://hermes-agent.nousresearch.com/docs/developer-guide/prompt-assembly` — 10-layer system prompt order, SOUL.md = Layer 1 (identity), AGENTS.md = Layer 8 (project context)
- vLLM metrics docs (latest dev preview) — list of `vllm:` prefix metrics including `vllm:num_requests_running`, `vllm:num_requests_waiting`, `vllm:request_success_total`
- KEDA Prometheus scaler reference — `serverAddress`, `query`, `threshold`, polling/cooldown intervals
- Kubernetes HPA walkthrough `https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/` — autoscaling/v2 spec, metrics-server prereq, KIND-specific `--kubelet-insecure-tls` patch
- Project file `course-code/COURSE_VERSIONS.md` — existing Day 1+2 pins (vLLM image, FastMCP 1.27.0, OTEL Collector 0.153.0, Tempo 1.24.4, Hermes image, etc.)
- Project file `course-code/labs/lab-04/solution/k8s/30-deploy-vllm.yaml` — vLLM Deployment spec (served-model-name, image, resource limits)
- Project files `course-code/labs/lab-06/solution/k8s/observability/*.yaml` — ServiceMonitor pattern (`release: kps` selector), Grafana dashboard (`vllm:gpu_cache_usage_perc` confirms vLLM 0.9.x metric name)
- Project file `course-code/labs/lab-07/solution/tools/*/` — MCP tool TDD pattern (treatment_lookup, triage, book_appointment) for capstone replication
- Project file `course-code/labs/lab-07/solution/hermes-config/SOUL.md` — existing scope text; extension target for guardrail prefix
- Project file `course-code/labs/lab-08/solution/k8s/*.yaml` — Sandbox CRDs and patterns being onboarded into GitOps
- Project file `course-code/labs/lab-09/solution/cost_middleware/cost_middleware.py` + `test_cost_middleware.py` — CollectorRegistry pattern for tests with reload()

### Secondary (MEDIUM confidence)
- KEDA Helm chart values (`https://artifacthub.io/packages/helm/kedacore/keda`) — confirms 2.19.0 chart version
- argo-cd Helm chart values (`https://artifacthub.io/packages/helm/argo/argo-cd`) — confirms 9.5.11 chart version
- ArgoCD App-of-Apps directory structure community guidance — multiple sources agree on `apps/` for child Application CRs + `bases/` (or per-app subdirs) for actual manifests
- vLLM autoscaling-with-KEDA reference (`https://docs.vllm.ai/projects/production-stack/en/latest/use_cases/autoscaling-keda.html`) — confirms KEDA pattern for vLLM is established
- `williamyeh/hey:latest` Docker Hub — image last updated ~7 years ago BUT scratch-based Go binary (no library rot risk)
- ArgoCD webhook docs `https://argo-cd.readthedocs.io/en/stable/operator-manual/webhook/` — confirms 3-min default polling, webhook is optional optimization

### Tertiary (LOW confidence — flagged for runtime validation)
- Exact kube-prometheus-stack Prometheus Service name in this project's cluster (cluster currently API-unresponsive — verify on rebuild before writing ScaledObject)
- DeepEval rate-limit consumption against Groq free tier with 20-item eval set (TPM mathematics depends on retrieval_context length per case — dry-run with 5 cases to validate before full run)
- Whether `kindnet v1.34+` enforces NetworkPolicy on this exact cluster — Phase 3 found "kindnet does NOT enforce" (RESEARCH.md note in lab-08 NetworkPolicy YAML comment), but this might have changed in newer kindnet revisions; doesn't affect Phase 4 (no NetworkPolicy reliance for guardrails) but worth noting if any Lab 11 ArgoCD-managed NetworkPolicy is included

## Metadata

**Confidence breakdown:**
- Standard stack (KEDA, ArgoCD, Argo Workflows, DeepEval, FastMCP middleware): **HIGH** — all versions verified against current Helm chart Chart.yaml or PyPI; install commands verified against official docs.
- Architecture patterns (KEDA ScaledObject, App-of-Apps, DAG with PVC + when:): **HIGH** — patterns are standard, examples adapted from official docs.
- Pitfalls: **HIGH** — most are derived from Phase 3 lessons + cross-checked with the project's existing manifest comments (e.g., `vllm:gpu_cache_usage_perc` legend in Lab 06 dashboard, `release: kps` in ServiceMonitor selector).
- DeepEval LLM judge integration with Groq: **MEDIUM** — code pattern is documented but full eval-set run on free tier needs validation during plan execution.
- FastMCP middleware: **HIGH** — confirmed via gofastmcp.com docs; API surface (Middleware class, on_call_tool, ToolError, add_middleware) is unambiguous.
- Hermes scope prefix location (SOUL.md vs AGENTS.md): **MEDIUM** — Hermes prompt-assembly docs are clear that SOUL.md is Layer 1 identity, but personality.md page muddied the distinction. Recommendation: SOUL.md.
- Resource budget (12-16 GB Docker Desktop): **MEDIUM** — current cluster is overloaded (API timeouts), so the assumption needs explicit validation during plan execution. Plan must include "free up resources" step.

**Research date:** 2026-05-03
**Valid until:** 2026-06-03 (30 days for stable infra components like KEDA/ArgoCD/Argo Workflows; 14 days for DeepEval which iterates faster)
