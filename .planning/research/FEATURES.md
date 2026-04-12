# Feature Research

**Domain:** LLMOps & AgentOps with Kubernetes — instructor-led workshop + Udemy course
**Researched:** 2026-04-12
**Confidence:** MEDIUM-HIGH (competitor curriculum verified via web; K8s Agent Sandbox from official k8s.io blog; framework comparisons from multiple sources)

---

## Feature Landscape

### Table Stakes (Students Expect These)

These are the non-negotiable modules. A student browsing Udemy will skip the course if any of these are absent. Competitors (DeepLearning.AI, Duke/Coursera, Full Stack Deep Learning bootcamp, Made With ML) cover all of these.

| Module / Feature | Why Expected | Complexity | Notes |
|-----------------|--------------|------------|-------|
| RAG pipeline (end-to-end) | Every LLMOps course in 2026 covers RAG; it is the entry point for practical LLM apps | MEDIUM | Must cover chunking, embedding, vector store, retrieval, synthesis — not just "what is RAG" |
| Model fine-tuning (LoRA/QLoRA) | DeepLearning.AI, Duke, Made With ML all include fine-tuning; students expect to adapt models | MEDIUM | CPU-safe with SmolLM2-135M; must show data prep, training loop, adapter management |
| Model serving (vLLM + KServe) | Serving is the #1 production skill gap; no course omits it | HIGH | vLLM has evolved significantly; KServe is the K8s-native standard; both must be current |
| Observability (Prometheus + Grafana) | MLOps muscle memory for DevOps audience; any production module needs metrics | MEDIUM | Must include LLM-specific metrics (token throughput, TTFT, queue depth), not just infra health |
| Kubernetes cluster setup (KIND) | All K8s courses start here; students need a local env that works | LOW | ImageVolumes is a 2026 feature worth highlighting; KIND on 16GB laptop must be validated |
| CI/CD for ML (GitOps with ArgoCD) | Made With ML, Full Stack DL bootcamp, Duke all cover ML CI/CD; expected by DevOps audience | MEDIUM | GitOps is the correct pattern for K8s-native deployments; Argo Rollouts for canary model deploys |
| ML pipeline orchestration (Argo Workflows) | Production AI pipelines need DAG orchestration; Kubeflow Pipelines is the DeepLearning.AI approach; Argo Workflows is more K8s-native | MEDIUM | Show full pipeline: data prep → fine-tune → package → deploy |
| Prompt engineering fundamentals | Every course in 2026 includes this; students without ML background need it as an entry ramp | LOW | Keep concise — zero-shot, few-shot, chain-of-thought, system prompts; 1 lab max; do NOT make it a full module |
| Autoscaling (HPA/KEDA/VPA) | Production LLM workloads have spiky traffic; autoscaling is a DevOps table stake | MEDIUM | KEDA is the critical differentiator over basic HPA; scale-to-zero for inference is compelling |
| OCI model packaging | Model-as-OCI-image (ImageVolumes) is emerging best practice; gives course currency | MEDIUM | Differentiates from Hugging Face Hub-only approaches; aligns with K8s-native philosophy |
| Web UI for the demo app | Students hate curl; a chat UI makes the whole course more relatable and demo-able | LOW | Simple React or Streamlit chat interface suffices; no auth required; Smile Dental theme |
| Data versioning / experiment tracking | Made With ML, Duke both cover this; without it, fine-tuning feels unscientific | LOW-MEDIUM | MLflow is adequate; DVC for data; keep lightweight given CPU constraint |

### Differentiators (Competitive Advantage)

These are what no other course covers — or covers well. This is the product's moat. The K8s-first framing unlocks a cluster of differentiators unavailable to cloud-platform courses.

| Module / Feature | Value Proposition | Complexity | Notes |
|-----------------|-------------------|------------|-------|
| Kubernetes Agent Sandbox (SandboxCRD + SandboxWarmPool) | NO competing course teaches this. First-class K8s primitive for agentic workloads (k8s-sigs project, March 2026 blog). Solves the three "impossible" problems: isolation, cold-start latency, PVC hibernation. | HIGH | Use Python SDK (`k8s-agent-sandbox`); demonstrate SandboxClaim, warm pools, gVisor isolation; directly tied to Smile Dental agentic use case |
| Multi-tool AI agent on Kubernetes (full lifecycle) | Courses teach "build an agent"; none teach "deploy, scale, and operate an agent on K8s with production isolation" | HIGH | Use LangGraph for stateful orchestration (strongest checkpointing story per 2026 comparisons); show appointment booking, triage, treatment lookup as concrete tools |
| LLM evaluation as a CI gate | Most courses mention evals; none wire them into a CI/CD pipeline as a quality gate blocking deployment | MEDIUM | Use DeepEval or a lightweight eval harness; metrics: RAG faithfulness, hallucination rate, task success rate; ArgoCD + Argo Workflows integration |
| Agent-specific observability (traces + evals in production) | Standard courses show Prometheus/Grafana; none show distributed tracing through agent tool calls with OpenTelemetry | MEDIUM-HIGH | vLLM + OpenTelemetry sidecar on KServe; Langfuse or Jaeger for trace visualization; agent-specific metrics: task success rate, tool call failure rate |
| Agentic framework comparison + selection rationale | Students are confused by LangGraph vs CrewAI vs OpenAI SDK; a decision framework with production deployment lens is unique | LOW | Present a concise comparison matrix (LangGraph = stateful/complex, CrewAI = rapid multi-agent, OpenAI SDK = simplest but vendor-locked); course uses LangGraph |
| Kubernetes-native FinOps for LLM inference | FinOps for AI (token-aware billing, per-model attribution, scale-to-zero economics) is barely covered anywhere; K8s framing makes it concrete | MEDIUM | KEDA scale-to-zero, resource quotas, VPA right-sizing, cost-per-token estimation; tie to Smile Dental operational budget narrative |
| Security guardrails as a lab (not just slides) | Courses mention prompt injection; none implement input/output guardrail pipelines in a Kubernetes deployment | MEDIUM | Implement NeMo Guardrails or a lightweight custom guardrail layer; show prompt injection defense, PII detection, output filtering; add as KServe transformer |
| Docusaurus-based course site with per-lab starter/solution code | Copy-paste walls are the #1 student frustration in competing courses; companion repo with `starter/` + `solution/` per lab eliminates this | LOW | This is a course delivery differentiator, not a technical one; still critical for Udemy ratings and repeat sales |
| Smile Dental end-to-end narrative | Competing courses use generic "chatbot" demos; a cohesive vertical use case (dental clinic: triage, appointments, FAQs) makes abstract concepts concrete and memorable | LOW | Every lab builds on the same app; agentic evolution is natural: RAG assistant → tool-using agent → sandboxed autonomous agent |
| 3-day instructor-led workshop format | Udemy courses exist; live workshops with labs are rare in this space; dual format is a revenue differentiator | LOW | Pacing, facilitator guides, breakout exercises; separate concern from content development |

### Anti-Features (Deliberately Excluded)

Features that students sometimes request but that would dilute the course or create problems.

| Feature | Why Requested | Why Problematic | What to Do Instead |
|---------|---------------|-----------------|-------------------|
| GPU-specific content (A100, H100, NVLink) | "Real production uses GPUs" | Excludes 90% of learners with only laptops; course becomes inaccessible without expensive hardware; distracts from K8s-operational focus | Call out GPU upgrade paths in notes; show that same patterns apply; keep all labs CPU-runnable on KIND |
| Cloud-managed services (EKS/GKE/AKS specifics) | Students want to deploy to real cloud | Cloud-specific labs fragment the audience and go stale quickly; AWS console UIs change constantly | Use cloud-agnostic KIND throughout; mention cloud as an appendix or "next steps"; one optional lab showing `kind` → cloud migration is acceptable |
| Enterprise auth/SSO (Okta, Keycloak, SAML) | "Production apps need auth" | Scope creep; 3+ labs consumed on auth instead of AI; not differentiated | Use API key or basic auth for demo; note enterprise auth patterns briefly |
| Mobile app or voice interface | "Chatbots should have voice/mobile" | Doubles UI complexity; not relevant to DevOps/ML target audience | Web chat interface only; note that the same backend serves any client |
| Multi-cloud model federation (routing across OpenAI/Anthropic/local) | "We need model routing in production" | Adds LiteLLM/BedRock proxy complexity that obscures the core K8s learning | Keep serving simple: vLLM serving local SmolLM2; one slide on LiteLLM as extension |
| Full MLOps lifecycle for classical ML (sklearn, XGBoost) | "I want to learn MLOps broadly" | Scope divergence; this course is LLM-specific | Position scope clearly in intro: LLMOps ≠ classical MLOps; link to Made With ML for classical path |
| Comprehensive prompt engineering course (6+ labs) | Prompt engineering is huge in 2026 | A standalone prompt engineering deep-dive belongs in a dedicated course; embedding 6 labs here burns time on concepts the K8s-audience already handles via application layer | One lab covering system prompts, few-shot patterns, and chain-of-thought; treat as enabling skill not core curriculum |
| Real-time streaming UI (SSE/WebSockets at scale) | "Production needs streaming" | Streaming UX is solved by off-the-shelf libraries; building it from scratch is frontend work, not LLMOps | Show vLLM streaming API in one demo; use a simple streaming-capable UI component |

---

## Feature Dependencies

```
[Lab 00: K8s Setup with KIND + ImageVolumes]
    └──enables──> ALL subsequent labs

[Lab 01: Synthetic Data + FAISS RAG]
    └──requires──> [Lab 00]
    └──enables──> [Lab 04: KServe/vLLM Serving] (app integration)
    └──enables──> [Evaluation Lab] (need retrieval output to evaluate)

[Lab 02: CPU LoRA Fine-Tuning]
    └──requires──> [Lab 00]
    └──enables──> [Lab 03: OCI Model Packaging]

[Lab 03: OCI Model Packaging]
    └──requires──> [Lab 02]
    └──enables──> [Lab 04: KServe/vLLM Serving]

[Lab 04: KServe + vLLM Model Serving]
    └──requires──> [Lab 03]
    └──enables──> [Web UI Lab]
    └──enables──> [Observability Lab]
    └──enables──> [Autoscaling Lab]
    └──enables──> [Agent Labs]

[Web UI Lab (Smile Dental Chat Interface)]
    └──requires──> [Lab 04]
    └──enables──> [Agent Labs] (students need UI to see agent responses)

[Lab 05: Prometheus + Grafana Observability]
    └──requires──> [Lab 04]
    └──enables──> [Agent Observability Lab] (extends with OTel traces)

[Lab 06: Autoscaling HPA/KEDA/VPA]
    └──requires──> [Lab 04]
    └──enhances──> [FinOps Module] (scale-to-zero = cost data)

[Lab 07: ArgoCD GitOps]
    └──requires──> [Lab 04]
    └──enables──> [Evaluation CI Gate Lab] (eval wired into ArgoCD sync)

[Lab 08: Argo Workflows Pipeline]
    └──requires──> [Lab 07]
    └──enables──> [Evaluation CI Gate Lab] (eval step in pipeline)

[Agent Framework Lab (LangGraph multi-tool agent)]
    └──requires──> [Lab 04] (needs serving endpoint)
    └──requires──> [Web UI Lab] (needs UI to demo)
    └──enables──> [Kubernetes Agent Sandbox Lab]

[Kubernetes Agent Sandbox Lab]
    └──requires──> [Agent Framework Lab]
    └──requires──> [Lab 00] (Sandbox CRD installed on cluster)
    └──enhances──> [Security Guardrails Lab] (Sandbox provides isolation layer)

[LLM Evaluation Lab]
    └──requires──> [Lab 01] (RAG pipeline to evaluate)
    └──requires──> [Lab 04] (serving endpoint for inference)
    └──enhances──> [Lab 07/08] (CI gate integration)

[Security Guardrails Lab]
    └──requires──> [Lab 04] (KServe transformer pattern)
    └──enhances──> [Kubernetes Agent Sandbox Lab]

[FinOps Module]
    └──requires──> [Lab 06] (autoscaling data)
    └──requires──> [Lab 05] (metrics)
    └──enhances──> [Agent Sandbox Lab] (PVC hibernation as cost strategy)

[Agent Observability Lab (OpenTelemetry + traces)]
    └──requires──> [Lab 05] (extends Prometheus/Grafana stack)
    └──requires──> [Agent Framework Lab]
```

### Dependency Notes

- **Everything requires Lab 00:** KIND setup is the foundation. This must be bulletproof — any cluster setup failure kills the whole workshop. Invest heavily in troubleshooting guides.
- **Model serving (Lab 04) is the pivot lab:** It unlocks Web UI, observability, autoscaling, GitOps, and all agent labs. It should be lab 4 of 4 in Day 1, with everything from Day 2+ building on it.
- **Agent Sandbox requires the agent framework lab:** Students must understand what an agent IS before learning how K8s isolates it. Framework lab first, sandbox lab second.
- **Evaluation and Security can be parallelized:** Neither depends on the other; they can be delivered as separate tracks on Day 3 or offered as electives in self-paced format.
- **FinOps is a capstone topic:** It requires autoscaling and observability data to be meaningful. Best as the final Day 3 lab or a workshop wrap-up discussion.

---

## MVP Definition

### Launch With (v1 — Initial Workshop)

Minimum viable content to run a credible 3-day workshop and publish the Udemy course.

- [ ] Lab 00: KIND cluster + ImageVolumes — foundation, must be flawless
- [ ] Lab 01: RAG with FAISS — table stakes, Smile Dental FAQ use case
- [ ] Lab 02: CPU LoRA fine-tuning SmolLM2-135M — table stakes
- [ ] Lab 03: OCI model packaging — table stakes + K8s-native credential
- [ ] Lab 04: vLLM + KServe model serving — pivot lab, must deliver
- [ ] Web UI lab: Smile Dental chat interface — replaces CLI; required for engagement
- [ ] Lab 05: Prometheus + Grafana — table stakes observability
- [ ] Lab 06: HPA/KEDA/VPA autoscaling — table stakes
- [ ] Lab 07: ArgoCD GitOps — table stakes
- [ ] Lab 08: Argo Workflows pipeline — table stakes
- [ ] Agent Framework Lab (LangGraph multi-tool): Smile Dental appointment + triage tools — primary differentiator
- [ ] Kubernetes Agent Sandbox Lab — the course's flagship differentiator

### Add After Validation (v1.x)

- [ ] LLM Evaluation as CI gate — high value, medium complexity; add after initial cohort feedback
- [ ] Agent Observability with OpenTelemetry traces — extends existing Prometheus lab; add in v1.1
- [ ] Security Guardrails Lab (KServe transformer) — important but separable; add in v1.1

### Future Consideration (v2+)

- [ ] FinOps deep-dive module — valuable but requires cost data that's hard to simulate on KIND; defer until real-cost cloud lab is possible
- [ ] Advanced multi-agent orchestration (CrewAI patterns, agent-to-agent handoffs) — add once LangGraph baseline is solid
- [ ] Model registry integration (MLflow Model Registry) — nice-to-have; competing courses cover it; deprioritize given K8s focus

---

## Feature Prioritization Matrix

| Feature | Student Value | Implementation Cost | Priority |
|---------|--------------|---------------------|----------|
| KIND cluster setup (Lab 00) | HIGH | LOW | P1 |
| RAG pipeline (Lab 01) | HIGH | MEDIUM | P1 |
| CPU LoRA fine-tuning (Lab 02) | HIGH | MEDIUM | P1 |
| OCI model packaging (Lab 03) | HIGH | LOW | P1 |
| vLLM + KServe serving (Lab 04) | HIGH | HIGH | P1 |
| Web UI (Smile Dental chat) | HIGH | LOW | P1 |
| Prometheus + Grafana (Lab 05) | HIGH | MEDIUM | P1 |
| HPA/KEDA autoscaling (Lab 06) | HIGH | MEDIUM | P1 |
| ArgoCD GitOps (Lab 07) | HIGH | MEDIUM | P1 |
| Argo Workflows pipeline (Lab 08) | HIGH | MEDIUM | P1 |
| LangGraph multi-tool agent | HIGH | HIGH | P1 |
| Kubernetes Agent Sandbox | HIGH | HIGH | P1 |
| LLM Evaluation CI gate | HIGH | MEDIUM | P2 |
| Agent observability (OTel traces) | MEDIUM | MEDIUM | P2 |
| Security guardrails lab | MEDIUM | MEDIUM | P2 |
| Agentic framework comparison | MEDIUM | LOW | P2 |
| FinOps module | MEDIUM | HIGH | P3 |
| Prompt engineering module | LOW | LOW | P2 (brief) |
| Data versioning / MLflow | MEDIUM | LOW | P2 |

**Priority key:**
- P1: Must have for workshop launch
- P2: Should have; add before Udemy publish or in v1.1
- P3: Nice to have; defer to v2

---

## Competitor Feature Analysis

| Feature | DeepLearning.AI LLMOps | Duke/Coursera LLMOps | Full Stack DL Bootcamp | Made With ML | **This Course** |
|---------|------------------------|----------------------|------------------------|--------------|-----------------|
| RAG pipeline | No (fine-tuning focused) | Yes (vector DBs) | Partial | Yes | Yes (FAISS, K8s-native) |
| Fine-tuning | Yes (supervised tuning) | Yes (multi-cloud) | No | Yes | Yes (LoRA, CPU-safe) |
| Model serving | Limited (Google Cloud) | Yes (Azure/AWS) | Partial | Yes | Yes (vLLM+KServe, K8s-native) |
| Kubernetes-native throughout | No | No | No | No | **YES — entire course** |
| Agent framework lab | No | No | No | No | **YES (LangGraph)** |
| K8s Agent Sandbox | No | No | No | No | **YES (unique globally)** |
| LLM evaluation / evals | No (safety scores only) | No | No | Yes (model testing) | Yes (as CI gate) |
| Security guardrails | Partial (safety scores) | No | No | No | Yes (KServe transformer) |
| FinOps / cost optimization | No | No | No | No | Partial (KEDA scale-to-zero) |
| CI/CD (GitOps) | No (Kubeflow only) | No | Yes (CI/CD workflows) | Yes | Yes (ArgoCD + Argo Workflows) |
| Autoscaling | No | No | No | No | Yes (HPA/KEDA/VPA) |
| Web UI for demo app | No | Partial | No | No | Yes (Smile Dental chat) |
| OpenTelemetry traces | No | No | No | No | Yes (agent observability) |
| Companion code repo | No | No | No | Yes | Yes (starter+solution per lab) |
| Local-only (no cloud required) | No (Google Cloud) | No (Azure/AWS/Databricks) | No | Partial | **YES — KIND only** |

---

## Sources

- [DeepLearning.AI LLMOps Course](https://www.deeplearning.ai/short-courses/llmops/) — verified via WebFetch; curriculum covers supervised tuning, Kubeflow Pipelines, BigQuery, safety scores
- [Duke University LLMOps Specialization on Coursera](https://www.coursera.org/specializations/large-language-model-operations) — multi-cloud focus, Azure/AWS/Databricks, 20+ projects; no K8s-native focus
- [Full Stack Deep Learning LLM Bootcamp](https://fullstackdeeplearning.com/llm-bootcamp/) — prompt engineering, LLMOps, UX, augmented LMs; no Kubernetes
- [Made With ML](https://madewithml.com/) — Design, Data, Model, Testing, Production, CI/CD, Monitoring; classical MLOps framing
- [Kubernetes Agent Sandbox official blog post](https://kubernetes.io/blog/2026/03/20/running-agents-on-kubernetes-with-agent-sandbox/) — HIGH confidence; verified CRD names, Python SDK, SandboxWarmPool, gVisor isolation
- [Agent framework comparison 2026](https://particula.tech/blog/langgraph-vs-crewai-vs-openai-agents-sdk-2026) — LangGraph owns stateful/complex; CrewAI owns rapid multi-agent; OpenAI SDK is simplest but vendor-locked
- [LLM Evaluation frameworks 2026](https://www.braintrust.dev/articles/llm-evaluation-guide) — RAG faithfulness, hallucination, regression testing, CI gate patterns
- [LLM Guardrails guide](https://www.confident-ai.com/blog/llm-guardrails-the-ultimate-guide-to-safeguard-llm-systems) — prompt injection, PII detection, output filtering; latency costs per layer
- [Kubernetes FinOps for LLM workloads](https://earezki.com/ai-news/2026-04-05-complete-guide-to-kubernetes-ai-cost-optimization-for-llm-workloads/) — KEDA scale-to-zero, per-model attribution, token-aware billing
- [vLLM + OpenTelemetry observability](https://www.parseable.com/blog/vllm-inference-metrics-otel) — sidecar pattern, Prometheus scrape, distributed tracing
- [Udemy bestseller analysis](https://medium.com/javarevisited/top-7-udemy-courses-to-learn-mlops-and-aiops-in-2027-febeac912194) — hands-on projects, end-to-end pipelines, practical observability are key drivers of bestseller status
- [AgentOps discipline overview](https://medium.com/@Intellibytes/what-is-agentops-the-ultimate-2026-guide-to-ai-agent-operations-544876848ddd) — agent-specific metrics: task success rate, tool call failure, intent monitoring

---

*Feature research for: LLMOps & AgentOps with Kubernetes*
*Researched: 2026-04-12*
