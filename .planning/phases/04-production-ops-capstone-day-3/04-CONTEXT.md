# Phase 4: Production Ops + Capstone (Day 3) - Context

**Gathered:** 2026-05-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Day 3 (Labs 10–13) takes the running Day 1+2 stack and operationalizes it. Four labs, twelve requirements:

- **Lab 10 — Autoscaling** (SCALE-01..03): vLLM scales under load via KEDA on `vllm:num_requests_running`, visible live in Grafana
- **Lab 11 — GitOps** (GITOPS-01..02): ArgoCD App-of-Apps manages a meaningful subset of the stack (incl. vLLM); a manual git commit on the model image tag triggers auto-sync
- **Lab 12 — Pipelines + Eval Gate** (GITOPS-03, EVAL-01..02): Argo Workflows DAG runs data → train → merge → package → DeepEval → commit-tag, blocking on faithfulness regression
- **Lab 13 — Guardrails + Capstone** (GUARD-01..03, CAP-01): Two-layer guardrails (MCP middleware + Hermes prompt prefix) protect the agent; capstone has students ship a guided `insurance_check` MCP tool end-to-end through TDD → GitOps → eval gate → ArgoCD → Grafana

Scope = labs 10/11/12/13. Reuses the entire Day 1+2 stack: vLLM, RAG retriever, Chainlit, Hermes Sandbox, MCP tools, Prometheus, Grafana, Tempo, OTEL Collector. Adds: KEDA, `hey` loadgen, ArgoCD, Argo Workflows, DeepEval, lightweight guardrail middleware, and one new MCP tool (`insurance_check`).

</domain>

<decisions>
## Implementation Decisions

### Lab 10 — Autoscaling
- **D-01:** Autoscaling target = **vLLM Deployment** (SmolLM2 serving). Single service, CPU-bound, demonstrates LLM-serving autoscaling — the most pedagogically interesting target. RAG retriever and Chainlit do NOT scale in this lab. Reconciles REQUIREMENTS "Chat API" wording: in this course, "the Chat API" = the vLLM OpenAI-compatible HTTP endpoint.
- **D-02:** Autoscaling primitive = **KEDA on `vllm:num_requests_running`** Prometheus trigger. Plain HPA on CPU is rejected (vLLM stays high-CPU even when idle — scaling thrashes). KEDA install is in Lab 10. SCALE-01 (HPA on CPU-based) is satisfied by a token HPA on RAG retriever as a brief contrast moment, NOT the headline; the lab's main act is KEDA on vLLM.
- **D-03:** Loadgen tool = **`hey`** (single Go binary, runs as a K8s Job). Targets the vLLM `/v1/completions` endpoint with a small fixed prompt. SCALE-03 satisfied.
- **D-04:** Demo win = **live pod count + RPS climbing in Grafana**. Lab walkthrough opens Grafana split-screen showing replica count panel and request-rate panel side by side; loadgen kicks off in another terminal; pause loadgen and watch scale-down. Single screenshot-worthy moment per lab.
- **D-05:** **vLLM scale-back-up** is the first action of Lab 10 (`kubectl scale deploy vllm-smollm2 --replicas=1 -n llm-serving`), symmetric to D-19/D-20 from Phase 3 (which scaled it to 0 at end of Lab 06). Lab 10 prereq doc states this explicitly.

### Lab 11 — GitOps
- **D-06:** GitOps scope = **Hybrid (App-of-Apps with meaningful subset)**. The App-of-Apps tree COULD manage the full stack; Lab 11 actually onboards: **vLLM Deployment**, **RAG retriever**, **Chainlit**, **agent Sandbox + SandboxWarmPool**, and the **monitoring stack** (Tempo + OTEL collector — kube-prometheus-stack stays Helm-managed for footprint). Argo Workflows (Lab 12 controller) and the one-shot KEDA loadgen Job stay imperative.
- **D-07:** GitOps repo = **`course-code/labs/lab-11/solution/gitops-repo/`** sub-folder in the companion repo. ArgoCD Application points at the same GitHub URL as the lab repo, on a path. Single clone, single auth context for students.
- **D-08:** Bootstrap point = **Lab 11 itself, post-Lab 10**. Lab 10 ships imperative kubectl applies. Lab 11 introduces ArgoCD, then re-imports Lab 10's KEDA ScaledObject manifest (and the rest of the subset) via App-of-Apps as the demo. Pedagogical arc: imperative first, declarative second.
- **D-09:** Promotion mechanic = **manual git commit → ArgoCD auto-sync** (3-min poll OR webhook — researcher picks). Student edits the image tag in `gitops-repo/apps/vllm/values.yaml` (or equivalent), commits, pushes; ArgoCD detects and rolls vLLM. argocd-image-updater is rejected (extra controller, magic).
- **D-10:** Promotion target = **vLLM Deployment**. vLLM is in the Lab 11 subset specifically so Lab 12's pipeline has a real workload to promote into. No "demo-echo" deployment; promotion is shown on the actual model.

### Lab 12 — Pipeline + Eval Gate
- **D-11:** Pipeline DAG = **full pipeline** — `data-gen → train → merge → package → eval → commit-tag`. Re-runs Day 1 Labs 01–04 logic as Argo Workflows steps. Training reuses Lab 02's 50-step CPU LoRA configuration (~5–10 min). Total DAG run ~15–20 min — acceptable for a workshop demo.
- **D-12:** Eval test set = **handcrafted ~10–20 dental Q&A pairs** at `course-code/labs/lab-12/solution/eval/eval-set.jsonl`. Each item: `{question, expected_answer, ground_truth_context}`. Stable, deterministic, debuggable. Smile-Dental-domain-specific (treatment costs, hours, walk-in policy, etc.). Tied to Lab 01 source docs so faithfulness scoring has clear ground truth.
- **D-13:** Eval metric = **faithfulness only** (DeepEval `FaithfulnessMetric`). Single threshold, single decision. Maps verbatim to roadmap success criterion #4. Failing the gate = bump retrieval top-k to 0 (or drop relevant docs from FAISS) to demonstrate the block.
- **D-14:** Gate mechanic = **DeepEval as Argo Workflows step + git-cli commit step**. Pipeline structure: `build-image → deepeval-step (LLM-as-judge via free-tier Groq/Gemini, queries a temp vLLM pod inside the workflow that has just loaded the new model) → if pass: git-commit-step writes the new image tag to the gitops sub-folder using an SSH-key K8s Secret → ArgoCD auto-syncs vLLM`. Conditional branch on eval result. EVAL-02 satisfied literally.

### Lab 13 — Guardrails
- **D-15:** Guard layer = **MCP tool middleware + Hermes system prompt prefix** (two-layer). Layer 1: Hermes system prompt declares scope ("You only answer questions about Smile Dental services. If asked anything else, decline politely."). Layer 2: programmatic middleware on each MCP tool checks args before tool execution; a small post-process step on the agent response runs the output filter. No sidecar; no Chainlit-only enforcement (would bypass on direct Sandbox calls).
- **D-16:** Input guardrail = **hybrid: regex fast-path + LLM-as-judge on uncertain**. Step 1: small regex/keyword block-list (e.g., `prescribe`, `dose`, `diagnose me`, `medication for`, `MRI`) → fast block with disclaimer. Step 2: if regex passes, a tiny LLM scope-check call ("Is this a question about a dental clinic? yes/no") via the agent's existing Groq/Gemini key. Demonstrates both deterministic and LLM-based safety; degrades gracefully when free-tier quota is tight.
- **D-17:** Output guardrail = **pattern check + disclaimer injection** (not LLM-as-judge — keeps quota cost down and pairs with input-side regex for teaching consistency). Post-process the agent response: regex-match for medical-advice phrases (`"I recommend you take"`, `"the diagnosis is"`, drug names from a small static list at `course-code/labs/lab-13/solution/guardrails/blocklist.json`). On match, replace or prepend with the canonical disclaimer (see Specific Ideas below). GUARD-02 satisfied.
- **D-18:** GUARD-03 (governance overview) = **documentation page + walkthrough section**, not new code. Lab 13 page has a final "Governance" section that ties: model versioning (the Lab 12 image tag commit history is the audit trail), GitOps as deploy-time provenance (ArgoCD Application history shows what was synced when), and OTEL traces (Lab 09) as runtime evidence ("here's the trace for the blocked query"). No new tooling.

### Lab 13 — Capstone (CAP-01)
- **D-19:** Capstone = **guided `insurance_check` MCP tool, shipped end-to-end**. Specific spec: `insurance_check(provider: str, treatment: str) -> {covered: bool, estimated_coverage_pct: int, notes: str}`. Backed by a static JSON map (e.g., `insurance-coverage.json`) with 3-4 providers × 5-6 treatments. Students execute: (1) write tool with TDD, (2) add to Hermes config, (3) commit through GitOps sub-folder, (4) extend `eval-set.jsonl` with insurance Q&A so the eval gate verifies the new tool's grounding, (5) Argo Workflows DAG runs eval gate, (6) on pass, ArgoCD deploys, (7) verify in Grafana via OTEL trace + cost panel. One exercise hits SCALE/GITOPS/EVAL/GUARD/CAP success criteria together.

### Cross-Lab Resource Strategy
- **D-20:** **Honest scoping note for success criterion #2.** Roadmap says "ArgoCD manages all components via App-of-Apps." Hybrid scope (D-06) means ArgoCD manages a meaningful subset (vLLM, RAG retriever, Chainlit, agent Sandbox, monitoring add-ons), not literally all components (Argo Workflows controller and one-shot loadgen Job stay imperative). Lab 11 page documents this explicitly as a teaching choice (App-of-Apps pattern is shown end-to-end; refactoring all 7 prior labs into GitOps was deemed scope creep). Mirrors the D-18 honest-disclosure pattern from Phase 3.
- **D-21:** **Resource budget assumption** = vLLM (1 replica) + ArgoCD (~512MB) + Argo Workflows (~512MB) + Tempo + OTEL collector + agent Sandbox + RAG + Chainlit + Prometheus + Grafana fits 12-16GB Docker Desktop allocation. Plan must include a brief check at start of Lab 10 ("if your KIND is tight, scale agent Sandbox to 1 replica before starting"). Researcher should validate live on user's KIND during plan execution.

### Claude's Discretion
- Exact KEDA Helm chart version + install method (Helm vs YAML); KEDA min/max replica bounds for vLLM; ScaledObject `pollingInterval` and `cooldownPeriod` values
- HPA values for the contrast moment on RAG retriever (CPU target %, min/max)
- ArgoCD Helm chart version + install command + values; App-of-Apps directory layout inside `gitops-repo/`; AppProject scoping
- Argo Workflows install method (Helm), namespace, RBAC for git-commit-step's SSH key Secret
- Choice between ArgoCD 3-min poll vs configuring a GitHub webhook for instant sync
- Exact 10-20 Q&A in `eval-set.jsonl` (researcher drafts, surfaced for user review during plan)
- Faithfulness threshold value (researcher recommends; default to ~0.7 if no other signal)
- Choice of LLM judge for DeepEval step (Groq llama-3.3-70b-versatile is the default)
- Specific regex/keyword list for input-side block-list and output-side blocklist (researcher drafts a starter set, lab guides explain how to extend)
- Exact prompt engineering for the input scope-classifier LLM call (1-2 line system + user)
- `insurance_check` static data: provider list, treatment-coverage map values
- Container build / image registry strategy for the `insurance_check` tool image (reuses Phase 3 MCP tool pattern from Lab 07)
- Exact 5 dental Q&A items added to `eval-set.jsonl` for the capstone (insurance-related questions)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project / Course Specs
- `.planning/PROJECT.md` — Locked decisions (Hermes Agent, two-phase LLM, no LangGraph/CrewAI, Chainlit UI, FAISS over Qdrant, Smile Dental naming, CPU-only, 16GB-laptop KIND, live-cluster verification mandatory)
- `.planning/REQUIREMENTS.md` §SCALE-01..03, §GITOPS-01..03, §EVAL-01..02, §GUARD-01..03, §CAP-01 — 12 requirements scoped to Phase 4
- `.planning/ROADMAP.md` §"Phase 4: Production Ops + Capstone (Day 3)" — Goal + 5 success criteria
- `.planning/STATE.md` §Decisions — full chain of locked decisions from Phases 01–03 (especially D-19/D-20 vLLM wind-down → scale-back symmetric pattern)

### Prior Phase Context (locked decisions to honor)
- `.planning/phases/03-agentops-labs-day-2/03-CONTEXT.md` — D-19 (vLLM scaled to 0 at end of Lab 06) and D-20 (symmetric scale-back at start of Lab 10); D-15 (cost middleware Prometheus counters); D-17 (`agent_llm_cost_usd_total` already in Grafana — capstone visualizes increment from `insurance_check` invocation)
- `.planning/phases/02-llmops-labs-day-1/02-CONTEXT.md` — vLLM serving topology, Chainlit deployment, Prometheus stack patterns

### Day 1+2 Code Reused, Wrapped, or Onboarded into GitOps
- `course-code/config.env` — `NS_SERVING=llm-serving`, `NS_APP=llm-app`, `NS_AGENT=llm-agent`, `NS_MONITORING=monitoring`; Phase 4 adds `NS_GITOPS=argocd`, `NS_WORKFLOWS=argo` if needed
- `course-code/COURSE_VERSIONS.md` — Existing Day 1+2 pins; Phase 4 adds: KEDA Helm chart version, ArgoCD Helm chart version, Argo Workflows Helm chart version, DeepEval pip version, `hey` image tag
- `course-code/labs/lab-04/solution/k8s/30-deploy-vllm.yaml` + `30-svc-vllm.yaml` — vLLM Deployment to autoscale (D-01) and to onboard into GitOps (D-10). Lab 10 first scales replicas back to 1; Lab 11 adopts under ArgoCD; Lab 12 promotes new tag.
- `course-code/labs/lab-01/solution/rag/retriever.py` + `course-code/labs/lab-01/solution/k8s/10-retriever-deployment.yaml` — RAG retriever (CPU HPA contrast in Lab 10; onboarded into GitOps in Lab 11)
- `course-code/labs/lab-05/solution/ui/app.py` + `course-code/labs/lab-05/solution/k8s/40-deploy-chainlit.yaml` — Chainlit Deployment (onboarded into GitOps in Lab 11)
- `course-code/labs/lab-08/solution/k8s/` — agent Sandbox + SandboxWarmPool manifests (onboarded into GitOps in Lab 11)
- `course-code/labs/lab-09/solution/helm/values-tempo.yaml` + `values-otel-collector.yaml` — Tempo + OTEL Collector (onboarded into GitOps in Lab 11)
- `course-code/labs/lab-09/solution/cost_middleware/` — `agent_llm_cost_usd_total` Prometheus counter (capstone shows increment in Grafana when `insurance_check` invoked)
- `course-code/labs/lab-09/solution/k8s/70-grafana-tempo-datasource-cm.yaml` — Tempo datasource (capstone uses for OTEL trace verification)
- `course-code/labs/lab-06/solution/k8s/observability/` — ServiceMonitors + Grafana dashboard ConfigMap (Lab 10 adds vLLM replicas + RPS panels)
- `course-code/labs/lab-07/solution/hermes-config/` — Hermes config + tool registration pattern (capstone extends with `insurance_check`)
- `course-code/labs/lab-07/solution/tools/` — MCP tool pattern (TDD example for capstone)
- `course-content/docs/labs/lab-06-web-ui.md` §"Wind down before Day 2" — Symmetric "scale vLLM back up" prelude at Lab 10 page top references this (D-05)

### Empty Day 3 Lab Slots (writers / artifact targets)
- `course-code/labs/lab-10/{starter,solution}/` — Empty; Lab 10 artifacts (KEDA install, ScaledObject, hey loadgen Job, Grafana dashboard panels)
- `course-code/labs/lab-11/{starter,solution}/` — Empty; Lab 11 artifacts (ArgoCD install, App-of-Apps tree, gitops-repo sub-folder)
- `course-code/labs/lab-12/{starter,solution}/` — Empty; Lab 12 artifacts (Argo Workflows install, DAG WorkflowTemplate, eval-set.jsonl, DeepEval container, git-commit-step)
- `course-code/labs/lab-13/{starter,solution}/` — Empty; Lab 13 artifacts (guardrail middleware, blocklist.json, insurance_check MCP tool + tests, capstone walkthrough materials)
- `course-content/docs/labs/lab-10-autoscaling.md` — Placeholder; rewrite with full lab content
- `course-content/docs/labs/lab-11-gitops.md` — Placeholder; rewrite
- `course-content/docs/labs/lab-12-pipelines.md` — Placeholder; rewrite
- `course-content/docs/labs/lab-13-capstone.md` — Placeholder; rewrite

### External Docs (researcher MUST fetch + cite)
- KEDA docs (`keda.sh`) — ScaledObject CRD spec, Prometheus trigger configuration, install via Helm; current stable version
- ArgoCD docs (`argo-cd.readthedocs.io`) — App-of-Apps pattern, Application CRD, AppProject scoping, auto-sync + self-heal flags, install via Helm or manifests
- Argo Workflows docs (`argo-workflows.readthedocs.io`) — DAG WorkflowTemplate syntax, conditional steps (`when:`), Secret mounting for SSH keys, install via Helm
- DeepEval docs (`deepeval.com`) — FaithfulnessMetric, custom datasets, configuring an OpenAI-compatible LLM judge (Groq/Gemini)
- `hey` docs (`github.com/rakyll/hey`) — flag reference (`-z`, `-c`, `-q`); container image options
- vLLM Prometheus metrics reference — confirm `vllm:num_requests_running` is the correct gauge name on v0.19.x (we use the colon-prefix form per Phase 02 D-02)
- GitHub webhook docs for ArgoCD (optional, only if D-09 chooses webhook over polling)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **vLLM Deployment manifest** (`course-code/labs/lab-04/solution/k8s/30-deploy-vllm.yaml`) — Already in place; Lab 10 just scales it back to ≥1 replica and adds a ScaledObject pointing at it; Lab 11 adopts it under ArgoCD; Lab 12 promotes new tags into it.
- **`vllm:` Prometheus metrics** — Phase 2 D-02 locked the colon-prefix; KEDA trigger uses `vllm:num_requests_running` directly.
- **Grafana dashboard ConfigMap auto-discovery** (Phase 2 D-09) — Lab 10 ships a new dashboard ConfigMap with `grafana_dashboard: '1'` label; auto-loads.
- **Hermes config + MCP tool pattern** (Phase 3, lab-07) — Capstone extends with one new MCP tool; reuses TransportSecuritySettings + FastMCP patterns established in Lab 07.
- **Cost middleware** (Phase 3, lab-09) — `agent_llm_cost_usd_total` already in Grafana; capstone needs zero new instrumentation work — invocation of the new tool ticks the counter automatically.
- **OTEL trace propagation** (Phase 3, lab-09) — Capstone's new tool inherits OTEL spans automatically via FastAPIInstrumentor + HTTPXClientInstrumentor.
- **Chainlit + agent Sandbox + RAG retriever** — All run unchanged through Day 3; just get adopted into GitOps in Lab 11.
- **Cleanup script pattern** (Phase 1 D-15/D-16) — `cleanup-phase4.sh` follows the established per-CRD `kubectl delete --ignore-not-found` + `helm status` guard pattern.

### Established Patterns
- **Lab dir convention** — `course-code/labs/lab-NN/{starter,solution}/{k8s,scripts,...}`. Day 3 follows.
- **Numbered K8s manifest files** — `10-foo.yaml`, `30-bar.yaml`, etc. Day 3 ranges: 80-autoscaling (Lab 10), 90-gitops-bootstrap (Lab 11), 100-pipelines (Lab 12), 110-guardrails (Lab 13).
- **Namespace per concern** — `argocd` (ArgoCD), `argo` (Argo Workflows), `keda` (KEDA controller). Existing namespaces (`llm-serving`, `llm-app`, `llm-agent`, `monitoring`) untouched.
- **NodePort for student access** — 30700 (ArgoCD UI), 30800 (Argo Workflows UI). Adds to existing 30300 (Chainlit), 30500 (Grafana).
- **TDD for Python code** — Phase 3 02 + 06 established RED→GREEN with reload() + isolated CollectorRegistry. Capstone tool, guardrail middleware, and DeepEval test runner all follow.
- **CPU-only, 16GB KIND constraint** — All new components must fit alongside the existing stack.
- **`uv pip install --system`** — Day 3 student-facing pip commands use `uv` (Phase 02.1).
- **MDX JSX comments** (Phase 3 D-?) — `{/* */}` not `<!-- -->` in Docusaurus pages.
- **One Docusaurus page per lab** — Already-placeholder `lab-10-autoscaling.md`, `lab-11-gitops.md`, `lab-12-pipelines.md`, `lab-13-capstone.md` get rewritten.

### Integration Points
- **KEDA → Prometheus** — ScaledObject queries existing kube-prometheus-stack (no new Prometheus install)
- **ArgoCD → GitHub** — Application points at the same companion repo, sub-folder path
- **ArgoCD → all onboarded apps** — replaces existing imperative deploys for vLLM, RAG, Chainlit, agent Sandbox, Tempo, OTEL collector
- **Argo Workflows → vLLM (temp pod inside DAG)** — eval step spins a transient vLLM pod loaded with the just-built model
- **Argo Workflows → kind-registry:5001** — package step pushes new image
- **Argo Workflows → GitHub** (via SSH-key Secret) — git-commit-step writes new tag to gitops sub-folder
- **Hermes → guardrail middleware** — middleware sits in MCP tool entry points; Hermes system prompt prefix carries the scope declaration
- **Capstone insurance_check tool → static JSON** — same local-JSON pattern as `book_appointment` (Phase 3 D-11), but read-only
- **Capstone tool invocation → cost middleware → Grafana panel** — automatic via Phase 3 instrumentation; visible "the new tool ticks the cost counter" moment

</code_context>

<specifics>
## Specific Ideas

- **Lab 10 demo prompt for hey** — small fixed prompt body to vLLM `/v1/completions`, e.g., `{"model":"smollm2","prompt":"What treatments does Smile Dental offer?","max_tokens":32}`. Keep `max_tokens` low so generations finish quickly and queue depth is the bottleneck.
- **Lab 10 Grafana panel pair** — left panel: `vllm_replicas` (or `kube_deployment_status_replicas{deployment="vllm-smollm2"}`); right panel: `vllm:num_requests_running`. Stack vertically in the lab screenshot.
- **Lab 11 narrative beat** — "Last lab you applied a YAML by hand. Today, the YAML lives in Git. Watch what happens when you change it." Lead with `git diff` showing image tag bump, then ArgoCD UI auto-syncing.
- **Lab 12 demo failure path** — instructor optionally drops the relevant chunks from FAISS before triggering the workflow → eval gate fails → no commit → ArgoCD doesn't sync → vLLM stays on previous tag. The "non-deploy" is the win.
- **Lab 13 canonical disclaimer text** — `"Smile Dental cannot provide medical advice. For health concerns beyond dental care, please consult your physician."` — used by the output filter on match.
- **Lab 13 demo blocked queries** — Input regex catches: `"prescribe me painkillers"`, `"what dosage of amoxicillin should I take"`. LLM scope-check catches: `"my dog has fleas, what should I do"`. Output filter catches a hallucinated `"I recommend you take 500mg of ibuprofen"`.
- **Capstone canonical `insurance_check` invocation** — student adds the tool, then sends through Chainlit: `"Does Aetna cover root canals at Smile Dental?"` Hermes triages → `treatment_lookup(root canal)` → `insurance_check(Aetna, root canal)` → response with coverage estimate. OTEL trace shows three tool spans; Grafana cost panel ticks. Single end-to-end win moment for Day 3.

</specifics>

<deferred>
## Deferred Ideas

- **Retroactive ArgoCD onboarding of all Day 1+2 components** (kube-prometheus-stack, all Day 1 Jobs) — D-06 picked Hybrid; full retrofit would balloon Lab 11 and break prior-lab kubectl commands.
- **`argocd-image-updater`** — D-09 picked manual commit + auto-sync for transparency; image-updater is a v2 enhancement chapter.
- **Synthetic eval set generated each run** — D-12 picked handcrafted for determinism; synthetic could be a v2 "evaluating eval sets" deep-dive.
- **Multi-metric DeepEval gate** (Faithfulness + Answer Relevancy + Context Precision/Recall) — D-13 picked single metric to keep teaching tight; multi-metric is an enhancement.
- **LLM-as-judge output guardrail** — D-17 picked pattern check + disclaimer to save quota; LLM-as-judge output filter is a v2 enhancement once cost is acceptable.
- **Open-ended capstone** ("design and ship a tool of your choice") — D-19 picked guided `insurance_check` for time-boxed completion in 60–90 min; open-ended could be a homework appendix.
- **Multi-track capstone** (3 spec'd options, students pick) — same trade-off as above.
- **Argo Workflows DAG light/heavy split** — D-11 picked the full pipeline; a light-demo subset could be a "if you're short on time" appendix.
- **GitHub webhook for instant ArgoCD sync** — within D-09 Claude's discretion; default to 3-min poll for simpler student setup.
- **Separate gitops repo (multi-repo pattern)** — D-07 picked sub-folder; multi-repo is a "real-world ops" appendix.
- **Local-only gitea Git server** — within D-07 considered; rejected as adding a stack component.
- **NeMo Guardrails / Guardrails-AI** — already excluded by PROJECT.md "no heavy frameworks"; v2 candidate at most.
- **Network-policy-based agent isolation** — kindnet doesn't enforce; Phase 3 D-7 already documented this gap. Phase 4 stays with code-based guardrails.
- **Cost-tracking dashboard improvements** (e.g., per-tool USD breakdown panel) — already in Phase 3; capstone reuses what exists.
- **Real calendar/EHR integration for booking** — already deferred in Phase 3 03-CONTEXT.

</deferred>

---

*Phase: 04-production-ops-capstone-day-3*
*Context gathered: 2026-05-03*
