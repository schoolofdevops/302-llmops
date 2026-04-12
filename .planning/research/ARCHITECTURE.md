# Architecture Research

**Domain:** LLMOps & AgentOps educational course with Kubernetes
**Researched:** 2026-04-12
**Confidence:** HIGH (Agent Sandbox official blog + docs; KServe official docs; LangGraph docs; Argo official docs)

---

## Standard Architecture

### System Overview — Final "Smile Dental" System

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Student Laptop (KIND Cluster)                   │
│                                                                         │
│  ┌──────────────┐    ┌──────────────────────────────────────────────┐  │
│  │   Browser    │    │             Kubernetes (KIND)                │  │
│  │  (Web Chat)  │    │                                              │  │
│  └──────┬───────┘    │  ┌─────────────────────────────────────┐    │  │
│         │            │  │   smile-app namespace                │    │  │
│         │ HTTP        │  │                                     │    │  │
│         ▼            │  │  ┌────────────┐  ┌───────────────┐  │    │  │
│  ┌──────────────┐    │  │  │  Chat UI   │  │ Agent API     │  │    │  │
│  │  Nginx/      │◄───┼──┼──│  (React /  │  │ (FastAPI      │  │    │  │
│  │  Ingress     │    │  │  │  Next.js)  │  │  LangGraph)   │  │    │  │
│  └──────────────┘    │  │  └─────┬──────┘  └──────┬────────┘  │    │  │
│                      │  │        │                 │           │    │  │
│                      │  └────────┼─────────────────┼───────────┘    │  │
│                      │           │                 │                │  │
│                      │  ┌────────▼─────────────────▼───────────┐    │  │
│                      │  │   smile-ml namespace                  │    │  │
│                      │  │                                       │    │  │
│                      │  │  ┌──────────────┐  ┌──────────────┐  │    │  │
│                      │  │  │ RAG Retriever│  │  KServe +    │  │    │  │
│                      │  │  │ (FastAPI +   │  │  vLLM        │  │    │  │
│                      │  │  │  FAISS)      │  │ (SmolLM2)    │  │    │  │
│                      │  │  └──────────────┘  └──────────────┘  │    │  │
│                      │  │                                       │    │  │
│                      │  │  ┌──────────────┐  ┌──────────────┐  │    │  │
│                      │  │  │ Agent Sandbox│  │  Prometheus/ │  │    │  │
│                      │  │  │ (k8s-sigs    │  │  Grafana     │  │    │  │
│                      │  │  │  CRD)        │  │              │  │    │  │
│                      │  │  └──────────────┘  └──────────────┘  │    │  │
│                      │  └───────────────────────────────────────┘    │  │
│                      │                                               │  │
│                      │  ┌─────────────────────────────────────────┐  │  │
│                      │  │  argocd / argo-workflows namespace       │  │  │
│                      │  │  ┌───────────┐   ┌──────────────────┐   │  │  │
│                      │  │  │  ArgoCD   │   │  Argo Workflows  │   │  │  │
│                      │  │  │ (GitOps)  │   │  (LLM pipeline)  │   │  │  │
│                      │  │  └───────────┘   └──────────────────┘   │  │  │
│                      │  └─────────────────────────────────────────┘  │  │
│                      └───────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Technology |
|-----------|----------------|-----------|
| Chat UI | Patient-facing web interface for clinic queries | React / Next.js served as static assets |
| Agent API | Orchestrates tool calls, state machine, LLM routing | FastAPI + LangGraph |
| RAG Retriever | Semantic search over dental knowledge base | FastAPI + FAISS + sentence-transformers |
| KServe InferenceService | Model serving abstraction, autoscaling, health checks | KServe v0.15+ |
| vLLM backend | Efficient token generation with PagedAttention | vLLM (via KServe HuggingFace runtime) |
| SmolLM2 model | Fine-tuned dental domain LLM (CPU-friendly) | SmolLM2-135M + LoRA merge, OCI image |
| Agent Sandbox | Isolated, stateful execution environment for agents | k8s-sigs/agent-sandbox (Sandbox CRD) |
| SandboxWarmPool | Pre-warmed agent instances for cold-start elimination | SandboxWarmPool CRD |
| Prometheus | Metrics collection (LLM tokens, latency, queue depth) | Prometheus Operator |
| Grafana | Dashboard for LLM/agent observability | Grafana with custom dashboards |
| HPA / KEDA / VPA | Autoscaling inference and agent pods | HPA on CPU; KEDA on queue depth |
| ArgoCD | GitOps reconciliation, App-of-Apps for all services | ArgoCD |
| Argo Workflows | DAG pipelines for data gen, fine-tuning, eval | Argo Workflows |
| Ingress (KIND) | Cluster ingress routing to Chat UI and APIs | nginx-ingress |

---

## Recommended Project Structure

```
smileDental/                        # companion code repo root
├── labs/
│   ├── lab00-cluster-setup/
│   │   ├── starter/                # incomplete manifests, students fill gaps
│   │   └── solution/               # fully working version
│   ├── lab01-synthetic-data/
│   │   ├── starter/
│   │   └── solution/
│   ├── lab02-rag/
│   │   ├── starter/
│   │   └── solution/
│   ├── lab03-finetuning/
│   │   ├── starter/
│   │   └── solution/
│   ├── lab04-model-packaging/
│   │   ├── starter/
│   │   └── solution/
│   ├── lab05-model-serving/
│   │   ├── starter/
│   │   └── solution/
│   ├── lab06-web-ui/
│   │   ├── starter/
│   │   └── solution/
│   ├── lab07-agent-core/
│   │   ├── starter/
│   │   └── solution/
│   ├── lab08-agent-sandbox/
│   │   ├── starter/
│   │   └── solution/
│   ├── lab09-observability/
│   │   ├── starter/
│   │   └── solution/
│   ├── lab10-autoscaling/
│   │   ├── starter/
│   │   └── solution/
│   ├── lab11-gitops/
│   │   ├── starter/
│   │   └── solution/
│   ├── lab12-pipelines/
│   │   ├── starter/
│   │   └── solution/
│   └── lab13-capstone/
│       ├── starter/
│       └── solution/
├── shared/
│   ├── k8s/                        # shared manifests reused across labs
│   │   ├── namespaces.yaml
│   │   ├── kind-config.yaml
│   │   └── ingress/
│   ├── data/                       # base synthetic dental dataset
│   └── scripts/                    # setup/teardown helpers
├── site/                           # Docusaurus documentation site
│   ├── docs/
│   │   ├── intro.md
│   │   ├── workshop/               # 3-day workshop track
│   │   │   ├── day1/
│   │   │   ├── day2/
│   │   │   └── day3/
│   │   └── udemy/                  # self-paced module track
│   ├── static/
│   ├── src/
│   └── docusaurus.config.js
└── README.md
```

### Structure Rationale

- **starter/ + solution/ per lab:** Eliminates copy-paste walls. Students get runnable scaffolding with intentional gaps (TODOs) and can diff against solution when stuck. Each lab is self-contained for instructor cherry-picking.
- **shared/ for cross-lab artifacts:** KIND cluster config, namespace definitions, and base data are used across many labs. Centralizing avoids duplication and ensures consistency when students reset a lab.
- **site/ co-located with code:** Docusaurus site lives in the same repo so documentation and code drift together under the same PR/review cycle.
- **workshop/ vs udemy/ doc tracks:** Same lab content, different pacing guides. Workshop track groups labs into 3-day blocks; Udemy track treats each lab as an independent module with intro/outro context.

---

## Architectural Patterns

### Pattern 1: Layered Namespace Isolation

**What:** Three Kubernetes namespaces divide concerns: `smile-app` (user-facing services), `smile-ml` (model + RAG), `monitoring` (observability stack). ArgoCD and Argo Workflows get their own namespaces.

**When to use:** Always — this is established course convention inherited from existing labs and maps cleanly to the "introduce namespaces early" pedagogical goal in Lab 00.

**Trade-offs:** Adds cross-namespace service communication complexity (students see real RBAC + NetworkPolicy), but that complexity is the lesson. CPU overhead negligible.

### Pattern 2: OCI Image as Model Artifact

**What:** Fine-tuned SmolLM2 merged weights are packaged as an OCI image (using ImageVolumes, Kubernetes 1.34+). KServe pulls the image rather than downloading from a model registry.

**When to use:** This pattern is central to Lab 04 (model packaging). It teaches that models are versioned artifacts like any container image, enabling GitOps-style model promotion via image tag.

**Trade-offs:** Requires KIND's ImageVolume feature gate (already enabled in Lab 00). Image sizes are large (~300MB for 135M model), but acceptable for a laptop lab. No external model registry dependency.

### Pattern 3: Agent as LangGraph State Machine

**What:** The dental agent is a LangGraph graph with typed state. Nodes handle intent routing, RAG retrieval, tool execution (appointment booking, treatment lookup, triage), and response synthesis. Conditional edges route between nodes based on LLM output.

**When to use:** Introduced in Lab 07. Students build the graph incrementally — first a simple RAG-only agent, then add tool nodes, then add interrupt/human-in-the-loop for appointment confirmation.

**Trade-offs:** LangGraph's explicit state and conditional edges make the agent debuggable (state is inspectable at each step). More verbose than simple chain patterns, which is pedagogically valuable — students see what "production agentic code" looks like.

```python
# Simplified LangGraph structure for Smile Dental agent
from langgraph.graph import StateGraph, END
from typing import TypedDict, Annotated

class DentalAgentState(TypedDict):
    messages: list
    intent: str          # "faq" | "appointment" | "triage"
    rag_context: str
    appointment_data: dict

builder = StateGraph(DentalAgentState)
builder.add_node("router", route_intent)
builder.add_node("rag_retrieve", retrieve_dental_knowledge)
builder.add_node("book_appointment", call_booking_tool)
builder.add_node("triage", run_symptom_triage)
builder.add_node("synthesize", generate_response)

builder.add_conditional_edges("router", {
    "faq": "rag_retrieve",
    "appointment": "book_appointment",
    "triage": "triage",
})
```

### Pattern 4: SandboxClaim for Agent Execution Isolation

**What:** Rather than running agent logic directly in the Agent API pod, Lab 08 deploys the agent code inside a Kubernetes Agent Sandbox — an isolated, stateful pod with stable identity. The Agent API creates a SandboxClaim, gets an assigned Sandbox from the warm pool, and the agent runs there.

**When to use:** Introduced in Lab 08 as the "production hardening" step for agents. Teaches why isolation matters for agents that execute untrusted or dynamically generated code.

**Trade-offs:** Adds ~100ms overhead for warm claim assignment (vs. cold pod startup which is seconds). Requires agent-sandbox controller installed on the cluster. On KIND, gVisor isolation is optional — students learn the concept without needing the full security runtime.

---

## Data Flow

### Primary Request Flow: User Query to Response

```
Browser (Chat UI)
    │  POST /chat  {message: "I have tooth pain"}
    ▼
Agent API (FastAPI, smile-app ns)
    │  LangGraph graph invoked with user message
    ▼
Router Node
    │  LLM classifies intent → "triage"
    ▼
RAG Retrieve Node
    │  POST /retrieve  {query: "tooth pain symptoms"}
    ▼
RAG Retriever Service (smile-ml ns)
    │  Embed query → FAISS search → top-k chunks returned
    ▼
Back to Agent API
    │  Context injected into LLM prompt
    ▼
KServe InferenceService (smile-ml ns)
    │  POST /v1/chat/completions  (OpenAI-compatible)
    ▼
vLLM backend (SmolLM2-135M fine-tuned)
    │  Token generation (PagedAttention, continuous batching)
    ▼
Response flows back through Agent API
    ▼
Chat UI renders streamed response
```

### Appointment Booking Tool Flow

```
Agent API
    │  LLM emits tool_call: book_appointment({date, time, treatment})
    ▼
ToolNode (LangGraph)
    │  Calls booking_tool function
    ▼
Appointment Service (mock FastAPI, smile-app ns)
    │  Writes appointment to in-memory store (demo-grade)
    │  Returns confirmation_id
    ▼
Back to synthesize node
    │  LLM generates confirmation message
    ▼
User sees: "Your cleaning is booked for April 15 at 10am. Ref: APT-4821"
```

### Model Packaging and Deployment Flow (GitOps path)

```
Argo Workflows (pipeline trigger)
    │
    ├── Step 1: data_generation  — Python job creates synthetic dental Q&A JSONL
    ├── Step 2: fine_tune        — LoRA fine-tune SmolLM2 on CPU (Lab 03)
    ├── Step 3: merge_model      — Merge LoRA weights into base model
    ├── Step 4: package_oci      — Build OCI image with model weights
    └── Step 5: push_image       — Push to local KIND registry

Git commit → InferenceService YAML with new image tag
    ▼
ArgoCD detects diff → syncs to cluster
    ▼
KServe controller → rolls out new InferenceService version
    ▼
vLLM serving new model weights
```

### Agent Sandbox Flow (Lab 08)

```
Agent API receives request
    │  Needs isolated execution environment
    ▼
Create SandboxClaim (references SandboxTemplate "dental-agent")
    ▼
SandboxClaimReconciler
    │  Checks SandboxWarmPool → warm instance available
    │  Transfers ownership in < 100ms
    ▼
Agent code executes in Sandbox pod
    │  Stable hostname: dental-agent-sandbox-{id}.smile-ml.svc
    │  Persistent state across tool calls
    ▼
Sandbox suspended when idle (scales to zero)
    │  Resumed on next claim (near-instant)
```

---

## Suggested Build Order (Lab Progression)

The progression follows a strict dependency chain: infrastructure before data, data before model, model before serving, serving before agents, agents before sandbox, all before production concerns.

### Phase 1 — Foundation (Day 1, Morning)

| Lab | Title | What Students Build | Dependency |
|-----|-------|---------------------|------------|
| 00 | Cluster Setup | KIND cluster + ImageVolumes, namespaces, ingress | None |
| 01 | Synthetic Data | Python data generator → 500 dental Q&A JSONL | Lab 00 |
| 02 | RAG Retriever | FAISS index + FastAPI retriever service on K8s | Lab 01 |

**Rationale:** Cluster and data must exist before anything else. RAG is introduced early because it's foundational to every subsequent lab — both the plain chat path and the agent path use the retriever.

### Phase 2 — Model (Day 1, Afternoon)

| Lab | Title | What Students Build | Dependency |
|-----|-------|---------------------|------------|
| 03 | Fine-tuning | LoRA fine-tune SmolLM2-135M on CPU | Lab 01 (data) |
| 04 | Model Packaging | OCI image with merged weights + local KIND registry | Lab 03 |
| 05 | Model Serving | KServe InferenceService + vLLM, test with curl | Lab 04 |

**Rationale:** Fine-tuning before serving because students need their own model artifact, not a pre-built one. OCI packaging bridges the ML output to Kubernetes input — this is the "models are artifacts" lesson.

### Phase 3 — Application (Day 2, Morning)

| Lab | Title | What Students Build | Dependency |
|-----|-------|---------------------|------------|
| 06 | Web Chat UI | React chat interface deployed on K8s, calls model API | Lab 05 |
| 07 | Agent Core | LangGraph agent with RAG + tool use (appointment booking, triage) | Labs 02, 05, 06 |

**Rationale:** Web UI replaces CLI before agents so students can see agent responses in a real interface. Agent lab is the most complex, introduced on Day 2 after all infrastructure is stable.

### Phase 4 — Agent Sandbox (Day 2, Afternoon)

| Lab | Title | What Students Build | Dependency |
|-----|-------|---------------------|------------|
| 08 | Agent Sandbox | Install agent-sandbox controller, SandboxTemplate, SandboxWarmPool, SandboxClaim, Python SDK integration | Lab 07 |

**Rationale:** Agent Sandbox requires a working agent (Lab 07) because it wraps agent execution — teaching isolation without an existing agent would be abstract. This is the unique differentiator lab for the course.

### Phase 5 — Production Hardening (Day 3)

| Lab | Title | What Students Build | Dependency |
|-----|-------|---------------------|------------|
| 09 | Observability | Prometheus scraping vLLM + agent metrics, Grafana dashboards | Lab 05, 07 |
| 10 | Autoscaling | HPA on inference pods, KEDA on agent queue, VPA on RAG | Lab 09 |
| 11 | GitOps | ArgoCD App-of-Apps manages all components, model promotion | Lab 05 |
| 12 | Pipelines | Argo Workflows DAG: data gen → fine-tune → package → deploy | Labs 03, 04, 11 |
| 13 | Capstone | Students wire a new dental symptom tool end-to-end from scratch | All labs |

**Rationale:** Observability before autoscaling — you need metrics before you can scale on them. GitOps after serving — students first understand what they're managing before handing control to ArgoCD. Pipelines last in the sequence because Argo Workflows depends on all pipeline steps already being understood individually.

---

## Integration Points

### External Services (none in production — all local)

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| KIND local registry | Docker push/pull via localhost:5001 | Set up in Lab 00 |
| Hugging Face Hub | One-time model download during fine-tuning | Network required only for Lab 03 |
| KIND host volume mount | `./project` → `/mnt/project` on KIND nodes | Persistent across pod restarts |

### Internal Service Communication

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Chat UI → Agent API | REST/HTTP over cluster ingress | Cross-namespace via Service DNS |
| Agent API → RAG Retriever | REST/HTTP (smile-ml.svc.cluster.local) | Cross-namespace — teaches RBAC/NetworkPolicy |
| Agent API → KServe | REST/HTTP OpenAI-compatible endpoint | InferenceService exposes `/v1/chat/completions` |
| Agent API → Agent Sandbox | Kubernetes API (SandboxClaim creation) | Python SDK wraps `kubectl apply` pattern |
| ArgoCD → All components | GitOps reconciliation (git → cluster) | Watches Git repo, applies declarative state |
| Argo Workflows → K8s jobs | Workflow steps spawn Kubernetes Jobs | Each pipeline step is a containerized job |
| Prometheus → vLLM | Scrape `/metrics` endpoint | vLLM exposes OpenMetrics natively |
| Prometheus → Agent API | Scrape `/metrics` endpoint | FastAPI + prometheus-fastapi-instrumentator |

---

## Anti-Patterns

### Anti-Pattern 1: Introducing Agents Before Serving Is Stable

**What people do:** Teach LangGraph tool use in the same lab as model serving setup.

**Why it's wrong:** Students are debugging two complex systems simultaneously. When the agent "doesn't work," they can't tell if it's the LLM output, the tool call parsing, or the KServe deployment. Debugging surface is too large.

**Do this instead:** Fully verify model serving with a plain curl request (Lab 05) before adding any agent logic. Students should see a working `/v1/chat/completions` response before building the graph.

### Anti-Pattern 2: Copy-Paste Walls for Kubernetes YAML

**What people do:** Embed 100-line YAML manifests inline in lab documentation.

**Why it's wrong:** Students copy-paste without understanding, get whitespace errors, and don't internalize what each field does. Also creates maintenance burden when tool versions change.

**Do this instead:** Starter code in the repo contains the YAML with annotated TODOs. Lab documentation explains each resource type conceptually, then tells students to fill in the gaps in `labs/labNN/starter/k8s/`. Solution provides the complete file.

### Anti-Pattern 3: Running Fine-tuning and Inference in the Same Lab

**What people do:** Combined "train and serve" labs to save time.

**Why it's wrong:** Fine-tuning on CPU takes 20-40 minutes. Mixing it with KServe deployment means students sit idle or rush ahead without understanding each step. Also obscures the distinct operational roles (ML engineer trains, platform engineer serves).

**Do this instead:** Lab 03 ends with a saved model checkpoint. Lab 04 packages it. Lab 05 serves it. Each is a separate operator concern, which is the LLMOps lesson.

### Anti-Pattern 4: Agent Sandbox Without a Working Agent First

**What people do:** Introduce Kubernetes Agent Sandbox as the primary agent deployment mechanism from the start.

**Why it's wrong:** SandboxClaim, SandboxTemplate, and SandboxWarmPool are only meaningful when students already have an agent that needs the isolation. Introducing the CRDs in a vacuum feels like Kubernetes YAML for its own sake.

**Do this instead:** Lab 07 builds a fully working LangGraph agent running in a plain Deployment. Lab 08 then migrates it to Agent Sandbox, demonstrating the before/after value.

### Anti-Pattern 5: Skipping Namespace Separation

**What people do:** Deploy everything to `default` namespace for simplicity.

**Why it's wrong:** Students never see cross-namespace communication patterns, RBAC between components, or the actual operational separation between ML workloads and application workloads — all of which are central LLMOps concepts.

**Do this instead:** Establish `smile-app`, `smile-ml`, and `monitoring` namespaces in Lab 00 and enforce them throughout. Make the RBAC a learning moment, not an obstacle.

---

## Docusaurus Site Architecture

### Dual-Delivery Structure

```
site/docs/
├── intro.md                    # Course overview, prerequisites, setup
├── architecture/               # System diagrams students refer back to
│   └── smile-dental-system.md
├── workshop/                   # 3-day instructor-led track
│   ├── day1/
│   │   ├── overview.md        # Day 1 agenda (Cluster → RAG → Model)
│   │   ├── lab00.md
│   │   ├── lab01.md
│   │   ├── lab02.md
│   │   ├── lab03.md
│   │   ├── lab04.md
│   │   └── lab05.md
│   ├── day2/
│   │   ├── overview.md        # Day 2 agenda (App → Agent → Sandbox)
│   │   ├── lab06.md
│   │   ├── lab07.md
│   │   └── lab08.md
│   └── day3/
│       ├── overview.md        # Day 3 agenda (Production)
│       ├── lab09.md
│       ├── lab10.md
│       ├── lab11.md
│       ├── lab12.md
│       └── lab13.md
└── reference/                  # Standalone reference pages
    ├── troubleshooting.md
    ├── k8s-manifests.md
    └── api-reference.md
```

**Udemy delivery:** Udemy uses video modules, not the Docusaurus site. The lab markdown files serve as instructor scripts and student reference material. Each lab page maps to one Udemy section. The site is the companion documentation for the Udemy course (linked in course resources).

**Tabs pattern:** Use Docusaurus `<Tabs>` for OS-specific commands (macOS vs Linux for KIND setup) and for showing starter vs solution code diffs.

**Versioning:** Use Docusaurus versioning to lock a stable version for each Udemy course release while `main` continues developing.

---

## Capstone Module Design (Lab 13)

The capstone avoids introducing new technology — it recombines everything students have built. Recommended structure:

1. **Problem statement:** "Add a medication interaction checker tool to the Smile Dental agent."
2. **Student tasks:**
   - Add synthetic medication data to the RAG knowledge base
   - Write a new LangGraph tool node for medication lookup
   - Register the tool with the existing agent graph
   - Deploy the updated agent in a new Agent Sandbox
   - Wire Prometheus metrics for the new tool call
   - Commit the change and let ArgoCD deploy it
3. **Assessment:** Does the full system work end-to-end with the new tool?

This exercises Labs 01 (data), 02 (RAG), 07 (agent tool), 08 (sandbox), 09 (observability), and 11 (GitOps) in a single coherent change.

---

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Single laptop (KIND) | All components co-located, no external dependencies, local OCI registry, mock appointment service — matches course constraints |
| Dev cluster (cloud) | Replace KIND local registry with ECR/GCR, add PVC for FAISS persistence, replace mock appointment service with real API |
| Production (multi-tenant) | SandboxWarmPool with per-tenant templates, KServe InferenceGraph for A/B model routing, Prometheus federation, ArgoCD ApplicationSets for multi-env |

---

## Sources

- [Running Agents on Kubernetes with Agent Sandbox | kubernetes.io blog](https://kubernetes.io/blog/2026/03/20/running-agents-on-kubernetes-with-agent-sandbox/) — HIGH confidence
- [kubernetes-sigs/agent-sandbox GitHub](https://github.com/kubernetes-sigs/agent-sandbox) — HIGH confidence
- [Agent Sandbox Getting Started](https://agent-sandbox.sigs.k8s.io/docs/getting_started/) — HIGH confidence
- [KServe Generative Inference Overview](https://kserve.github.io/website/docs/model-serving/generative-inference/overview) — HIGH confidence
- [LangGraph Agentic RAG docs](https://docs.langchain.com/oss/python/langgraph/agentic-rag) — HIGH confidence
- [Argo Workflows fine-tuning LLMs with Hera](https://pipekit.io/blog/fine-tune-llm-argo-workflows-hera) — MEDIUM confidence
- [GitOps for ML in 2026](https://earezki.com/ai-news/2026-03-14-gitops-for-ml-in-2026-treat-your-ai-models-like-microservices-or-watch-them-drift-into-production-chaos/) — MEDIUM confidence
- [Building Production-Ready RAG with FastAPI + FAISS](https://www.freecodecamp.org/news/build-rag-app-faiss-fastapi/) — MEDIUM confidence

---

*Architecture research for: LLMOps & AgentOps with Kubernetes (Smile Dental course)*
*Researched: 2026-04-12*
