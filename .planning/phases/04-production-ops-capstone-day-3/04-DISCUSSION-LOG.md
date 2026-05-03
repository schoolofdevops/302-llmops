# Phase 4: Production Ops + Capstone (Day 3) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-03
**Phase:** 04-production-ops-capstone-day-3
**Areas discussed:** Autoscaling target & load source (Lab 10), GitOps scope & repo strategy (Lab 11), Pipeline shape + Eval gate (Lab 12), Guardrails + Capstone shape (Lab 13)

---

## Area Selection

**Question:** Which areas do you want to discuss for Phase 4 (Production Ops + Capstone)?

| Option | Description | Selected |
|--------|-------------|----------|
| Autoscaling target & load source (Lab 10) | What scales, what drives load, which metric powers KEDA. Reconciles REQUIREMENTS "Chat API" with actual architecture. | ✓ |
| GitOps scope & repo strategy (Lab 11) | Retroactive vs Day-3-only; same repo or separate; bootstrap point; promotion mechanism. | ✓ |
| Pipeline shape + Eval gate (Lab 12) | Full DAG vs subset; eval test set design; metric choice; gate mechanic + git-commit. | ✓ |
| Guardrails + Capstone shape (Lab 13) | Where guardrails live; input/output techniques; capstone exercise (guided vs open). | ✓ |

**User's choice:** All four areas selected.

---

## Lab 10 — Autoscaling target & load source

### Q1: What service(s) should the autoscaling demo scale?

| Option | Description | Selected |
|--------|-------------|----------|
| vLLM (SmolLM2 serving) | Single service, CPU-bound, dramatic scaling, real LLM workload. Reuses Day 1 vLLM (just scales it back up after D-19/D-20 wind-down). | ✓ |
| vLLM + RAG retriever (both) | Two services with different metrics: vLLM via KEDA, retriever via HPA on CPU. Heavier resource footprint. | |
| New Chat API wrapper service | Build a small FastAPI wrapper to honor REQUIREMENTS "Chat API" wording literally. Adds new service for demo only — drift risk. | |
| Chainlit/Sandbox chat path | Most realistic for "production agent" but Chainlit is WebSocket-stateful, free-tier rate-limited, messy. | |

**User's choice:** vLLM (SmolLM2 serving) — recommended.
**Notes:** "Chat API" in REQUIREMENTS interpreted as the vLLM OpenAI-compatible HTTP endpoint.

### Q2: What tool drives the load?

| Option | Description | Selected |
|--------|-------------|----------|
| hey | Single Go binary, runs as K8s Job, simple flags. CPU-friendly. | ✓ |
| k6 | More production-grade, JS scripts, ramps. Bigger footprint. | |
| Bash curl + xargs in a Job | Zero deps but ugly metrics; students who don't read shell tune out. | |
| Locust / Python loadgen pod | Web UI for live RPS graphs. Heavier image. | |

**User's choice:** hey — recommended.

### Q3: What metric powers the autoscaler(s)?

| Option | Description | Selected |
|--------|-------------|----------|
| KEDA on vllm:num_requests_running | vLLM-native queue-depth metric. Right signal for LLM serving. | ✓ |
| HPA on CPU only | Simplest; vLLM stays high-CPU even when idle — scaling thrashes. | |
| KEDA on HTTP RPS via Prometheus | Generic, bypasses LLM-specific signals. | |
| Mix: HPA on CPU + KEDA on Prometheus | Most complete, longest lab. | |

**User's choice:** KEDA on vllm:num_requests_running — recommended.

### Q4: What's a satisfying success moment?

| Option | Description | Selected |
|--------|-------------|----------|
| Watch pods scale up live in Grafana | Visceral, screenshot-worthy, time-bound (~5 min). | ✓ |
| Compare latency before/after scaling | Pedagogically richer but takes longer. | |
| Demonstrate scaling failure mode | Most production-realistic, risks confusion. | |
| All three in sequence | Most thorough, longest lab. | |

**User's choice:** Watch pods scale up live in Grafana — recommended.

### Lab 10 wrap-up

**Question:** More Lab 10 questions, or move to next?
**User's choice:** Next area.

---

## Lab 11 — GitOps scope & repo strategy

### Q1: What's the GitOps scope?

| Option | Description | Selected |
|--------|-------------|----------|
| Hybrid: pattern + subset | App-of-Apps that COULD manage everything; Lab 11 actually onboards a meaningful subset. | ✓ |
| Retroactive: ArgoCD owns everything | Most realistic; refactors all 7 prior labs. Heavy. | |
| Day-3-only: just new components | Cleanest scoping; success criterion "manages all components" becomes a stretch. | |

**User's initial choice:** Day-3-only (then revised).
**User's revised choice:** Hybrid — recommended.
**Notes:** User explicitly course-corrected mid-discussion: "for ● Lab 11 — What's the GitOps scope? → Day-3-only: just new components / you can use your recommendations instead." Final decision is Hybrid; the Hybrid subset includes vLLM (so the model-promotion demo lands on a real workload), RAG retriever, Chainlit, agent Sandbox, and monitoring add-ons (Tempo + OTEL collector). Argo Workflows controller and one-shot loadgen Job stay imperative. The honest scoping note (D-20 in CONTEXT.md) explains the gap between roadmap "all components" and the actual subset.

### Q2: Where does the GitOps repo live?

| Option | Description | Selected |
|--------|-------------|----------|
| Sub-folder in companion repo | Single clone, single auth context. | ✓ |
| New top-level repo (course-gitops) | More realistic separation; multi-repo overhead. | |
| Branch in companion repo | Confuses teaching narrative. | |
| Local file system (no remote, gitea) | Adds a stack component. | |

**User's choice:** Sub-folder in companion repo — recommended.

### Q3: When does ArgoCD enter the curriculum?

| Option | Description | Selected |
|--------|-------------|----------|
| Lab 11 itself, post-Lab 10 | Imperative first, declarative second. Natural arc. | ✓ |
| Lab 10 prelude bootstraps ArgoCD first | Cleaner from "real production"; cognitive overload risk. | |
| Lab 11 prelude install + onboard in 11 | Functionally equivalent to option 1. | |

**User's choice:** Lab 11 itself, post-Lab 10 — recommended.

### Q4: How does a model tag bump trigger redeploy?

| Option | Description | Selected |
|--------|-------------|----------|
| Manual git commit → ArgoCD auto-sync | Most transparent; sets up Lab 12 cleanly. | ✓ |
| argocd-image-updater watches the registry | Full auto-promotion; more magic; another controller. | |
| Manual sync (no auto-sync) | Defeats "GitOps just happens" demo. | |
| Show all three approaches | Turns Lab 11 into a reference manual. | |

**User's choice:** Manual git commit → ArgoCD auto-sync — recommended.

### Q5 (follow-up after scope-revise): Which Day-1 component gets pulled INTO Lab 11's GitOps subset to demonstrate model promotion?

| Option | Description | Selected |
|--------|-------------|----------|
| vLLM Deployment | Natural target — Lab 12's pipeline produces a new vLLM image tag. Clean Lab 11→12 narrative. | ✓ |
| A new tagged 'echo-deployment' demo app | Pure pattern teaching, no real workload involvement. | |
| Both — echo for the mechanic, vLLM for the real flow | Most thorough; stretches Lab 11 scope. | |

**User's choice:** vLLM Deployment — recommended.

---

## Lab 12 — Pipeline shape + Eval gate

### Q1: What does the Argo Workflows DAG actually do?

| Option | Description | Selected |
|--------|-------------|----------|
| Full pipeline: data → train → merge → package → eval → commit-tag | End-to-end automation of Day 1 Labs 01–04. ~15–20 min run. | ✓ |
| Subset: package + eval + commit-tag | Skip data-gen and training. ~3 min. Doesn't satisfy "full pipeline" success criterion cleanly. | |
| Subset: train + merge + commit-tag (no eval gate) | Doesn't satisfy EVAL-02 cleanly. | |
| Two DAGs: light demo + full optional | Best of both worlds; more lab content to maintain. | |

**User's choice:** Full pipeline — recommended.

### Q2: What's the DeepEval test set?

| Option | Description | Selected |
|--------|-------------|----------|
| Handcrafted ~10–20 dental Q&A pairs | Stable, deterministic, easy to debug. Tractable threshold. | ✓ |
| Synthetic eval set generated from Lab 01 data | More realistic; non-deterministic; hard to demo stable threshold. | |
| Both: handcrafted regression + synthetic exploration | Cognitive load. | |

**User's choice:** Handcrafted ~10–20 dental Q&A pairs — recommended.

### Q3: Which DeepEval metric(s) drive the gate?

| Option | Description | Selected |
|--------|-------------|----------|
| Faithfulness only | Single metric, single threshold. Maps to roadmap success criterion #4 verbatim. | ✓ |
| Faithfulness + Context Precision | Catches retrieval AND generation regressions; more to explain. | |
| Faithfulness + Answer Relevancy + Context Precision/Recall | Full RAG triad; burns free-tier quota fast. | |

**User's choice:** Faithfulness only — recommended.

### Q4: Who runs the eval, and how does pass/fail commit the new image tag?

| Option | Description | Selected |
|--------|-------------|----------|
| DeepEval as Argo Workflows step + git-cli commit step | Clean linear DAG, conditional branch, pipeline-as-promotion. | ✓ |
| DeepEval as separate K8s Job, manual promotion | Breaks the "gate" framing. | |
| DeepEval inline + mock LLM judge (embedding-similarity) | Quota-safe; less faithful to real DeepEval usage. | |

**User's choice:** DeepEval as Argo Workflows step + git-cli commit step — recommended.

---

## Lab 13 — Guardrails + Capstone shape

### Q1: Where do guardrails live in the architecture?

| Option | Description | Selected |
|--------|-------------|----------|
| MCP tool middleware + Hermes system prompt | Two-layer; testable, debuggable, complementary. | ✓ |
| Separate guardrail sidecar in the Sandbox | Most isolated; heavy for a workshop. | |
| Chainlit hooks (input/output) | Easiest to debug; bypassed on direct Sandbox calls — pedagogically misleading. | |
| Hermes system prompt only | Weakest enforcement; no programmatic backstop. | |

**User's choice:** MCP tool middleware + Hermes system prompt — recommended.

### Q2: Input guardrail technique?

| Option | Description | Selected |
|--------|-------------|----------|
| Hybrid: regex fast-path + LLM classifier on uncertain | Both deterministic and LLM-based safety. Degrades gracefully. | ✓ |
| Regex/keyword block-list only | Deterministic, zero LLM cost; falls over on rephrasings. | |
| LLM-as-judge classifier only | Most flexible; rate-limit risk on free tier. | |
| Embedding-similarity scope check | Reuses existing embedding model; threshold tuning fiddly. | |

**User's choice:** Hybrid: regex fast-path + LLM classifier — recommended.

### Q3: Output guardrail technique?

| Option | Description | Selected |
|--------|-------------|----------|
| Pattern check + disclaimer injection | Deterministic, transparent, no LLM judge cost. Pairs with input regex. | ✓ |
| LLM-as-judge before reply | More flexible; extra API call per response. | |
| Hybrid: pattern first, LLM if pattern matches | Balances cost and flexibility. | |
| Trust system prompt + skip output filter | Doesn't satisfy GUARD-02 verifiably. | |

**User's choice:** Pattern check + disclaimer injection — recommended.

### Q4: What does the capstone exercise have students do?

| Option | Description | Selected |
|--------|-------------|----------|
| Guided: add insurance_check MCP tool end-to-end | Specific spec; tight executable in 60–90 min; hits all Day 3 success criteria together. | ✓ |
| Open-ended: design and ship a tool of your choice | More creative; some students design themselves into a corner. | |
| Hybrid: walk through insurance_check, then open challenge | Blurs lab vs capstone boundary. | |
| Multi-track: 3 spec'd options, students pick one | More variety; more lab content to write & test. | |

**User's choice:** Guided: add insurance_check MCP tool end-to-end — recommended.

---

## Wrap-up

**Question:** Ready to write CONTEXT.md, or any gray areas still unclear?
**User's choice:** I'm ready for context — recommended.

## Claude's Discretion (areas where downstream agents have flexibility)

- KEDA install method, version, min/max bounds, polling/cooldown values
- HPA values for the brief RAG retriever contrast (CPU target %, min/max)
- ArgoCD install method, version, App-of-Apps directory layout
- Argo Workflows install method, RBAC for SSH-key Secret
- 3-min poll vs GitHub webhook for ArgoCD sync trigger
- Exact 10–20 Q&A items in `eval-set.jsonl` (researcher drafts; user reviews during plan)
- Faithfulness threshold value (default ~0.7)
- LLM judge model for DeepEval (default Groq llama-3.3-70b-versatile)
- Specific regex/keyword block-lists (input + output sides)
- Exact prompt for the input scope-classifier LLM call
- `insurance_check` static data values (provider list, treatment-coverage map)
- 5 dental Q&A items added to `eval-set.jsonl` for capstone

## Deferred Ideas (noted for future phases or v2)

- Retroactive ArgoCD onboarding of all Day 1+2 components
- argocd-image-updater
- Synthetic eval set
- Multi-metric DeepEval gate (Answer Relevancy, Context Precision/Recall)
- LLM-as-judge output guardrail
- Open-ended capstone
- Multi-track capstone
- Argo Workflows DAG light/heavy split
- GitHub webhook for instant ArgoCD sync
- Separate gitops repo (multi-repo pattern)
- Local-only gitea Git server
- NeMo Guardrails / Guardrails-AI (already excluded by PROJECT.md)
- Network-policy-based agent isolation (kindnet doesn't enforce)

---

*Discussion log generated: 2026-05-03*
