---
sidebar_position: 10
---

# Lab 09: Serving Decision Lab — Which Pattern Fits Your Use Case?

## Overview

By the time you reach this page, you have deployed the same fine-tuned SmolLM2-135M model three ways:

- **Lab 04**: Pattern A — plain vLLM Kubernetes Deployment (simplest, no control-plane overhead)
- **Lab 07**: Pattern C — vLLM Production Stack router with two CPU backends and KEDA autoscaling
- **Lab 08**: Pattern B — KServe InferenceService with a custom ClusterServingRuntime

Each pattern exposed the model at a different NodePort and required a different amount of cluster infrastructure to support it. This page is a reference card to bookmark — use it when you are choosing a serving pattern for a new project or recommending one to your team.

## Comparison Table

| Dimension | Pattern A: Plain vLLM Deployment | Pattern C: vLLM Router (Multi-pod) | Pattern B: KServe InferenceService |
|-----------|-----------------------------------|------------------------------------|-------------------------------------|
| **Lines of YAML** | ~80 (Deployment + Service) | ~160 (values.yaml Helm) | ~170 (ClusterServingRuntime + InferenceService + NodePort Service) |
| **Scaling primitive** | HPA on Deployment (CPU-based) | KEDA on backends (Prometheus metric: `vllm:num_requests_waiting`) | HPA or KEDA on InferenceService predictor (Phase 06) |
| **Storage approach** | emptyDir initContainer (mc cp from MinIO) | emptyDir initContainer per backend pod | emptyDir initContainer (this course) or KServe storage initializer (S3/GCS) |
| **Cluster overhead** | Minimal (~0 extra RAM) | ~1 GB (lmstack-router pod) | ~700 Mi–1.5 GB (cert-manager + KServe controller) |
| **Observability** | Prometheus `/metrics` built-in on vLLM port | Prometheus `/metrics` built-in on each backend; ServiceMonitor auto-created by chart | Prometheus `/metrics` built-in on vLLM port |
| **Scale to zero** | No | No | No (RawDeployment; Serverless mode would enable it but requires Knative + Istio) |
| **Multi-model support** | No (one Deployment per model) | No (one vllm-stack per model) | Yes (multiple InferenceServices share one ClusterServingRuntime) |
| **CRD dependency** | None | None (Helm chart only) | KServe CRDs + cert-manager + Gateway API CRDs |
| **NodePort access** | Direct (Service type NodePort) | Direct (router Service type NodePort) | Separate NodePort Service required (KServe manages its own ClusterIP Service) |
| **Seen in** | [Lab 04](./lab-04-serving-and-ui) | [Lab 07](./lab-07-vllm-router) | [Lab 08](./lab-08-kserve-inferenceservice) |

:::info Lines of YAML — real numbers from this course
The YAML line counts in the table are based on actual files created in this course:
- Pattern A: `course-code/labs/lab-04/solution/k8s/` — Deployment + Service
- Pattern C: `course-code/labs/lab-07/solution/k8s/00-values-vllm-router.yaml` — Helm values file (~160 lines)
- Pattern B: `course-code/labs/lab-08/solution/k8s/` — ClusterServingRuntime (~59 lines) + InferenceService (~115 lines) + NodePort Service (~25 lines) = ~199 total

Pattern B has more YAML but the ClusterServingRuntime is defined once and reused for every InferenceService that uses the same runtime image. At scale (many models), this amortizes the per-model YAML cost.
:::

## Decision Tree

```
Do you need to serve more than one model variant on the same cluster?
├── YES → Use KServe InferenceService (Pattern B)
│         Multi-model management, ClusterServingRuntime reuse across namespaces
└── NO  → Continue...

Do you need session-affinity routing or KV-cache awareness across multiple replicas?
├── YES → Use vLLM Router (Pattern C)
│         Built-in session routing, prefix-aware routing, KEDA on backends
└── NO  → Continue...

Is your team already operating Kubernetes and comfortable with plain Deployments?
├── YES (single model, no special routing needed)
│   → Use Plain vLLM Deployment (Pattern A)
│     Lowest overhead, no additional control-plane, standard kubectl operations
└── NO  → Does your ops team manage the model lifecycle
           (rollouts, A/B tests, version promotion)?
           ├── YES → Use KServe InferenceService (Pattern B)
           │         CRD-based lifecycle, GitOps-friendly, standard serving abstraction
           └── NO  → Use Plain vLLM Deployment (Pattern A)
```

## Pattern A: Plain vLLM Deployment — When to Use

**Reference: [Lab 04 — vLLM Serving and UI](./lab-04-serving-and-ui)**

Choose Pattern A when:

- You are serving a **single model** with no plans to add more on the same cluster
- Your team is already comfortable with **standard Kubernetes Deployments** and does not need a serving abstraction layer
- You want the **lowest control-plane overhead** — no extra namespaces, no CRDs beyond core Kubernetes, no cert-manager
- You need to get a model running **quickly** — Deployment + Service YAML is ~80 lines
- You are building a **development or staging** environment where operational maturity is not yet required
- You are working with an existing Kubernetes cluster where you do not have permission to install cluster-scoped CRDs

**Not a good fit when:** multiple models need to share infrastructure, you need session-affinity routing, or your ops team needs CRD-based lifecycle management (rollback, revision history, canary deployments via spec fields).

## Pattern C: vLLM Router (Multi-pod) — When to Use

**Reference: [Lab 07 — vLLM Router Multi-Pod Serving](./lab-07-vllm-router)**

Choose Pattern C when:

- You need **session-affinity routing** — multi-turn conversations must reach the same backend pod to preserve the KV cache between turns
- You are scaling **horizontally** across multiple backend pods and need a load-balancing layer in front
- You want **KEDA-driven autoscaling** of the backend pod count based on Prometheus metrics (`vllm:num_requests_waiting`), with the router staying at a fixed replica count
- Your model **fits on a single node** but you need more than one replica for throughput
- You are familiar with Helm and prefer to manage the router + backends as a single `helm upgrade` operation
- You need **prefix-aware routing** (shared KV cache for common prompt prefixes across users) — this is the path to LMCache-based optimizations in production

**Not a good fit when:** you need to serve multiple different models (one vllm-stack per model gets expensive), or your team does not want to maintain the routing layer (Pattern B's KServe managed service is a better fit).

## Pattern B: KServe InferenceService — When to Use

**Reference: [Lab 08 — KServe InferenceService](./lab-08-kserve-inferenceservice)**

Choose Pattern B when:

- You need to **manage multiple models** on the same cluster — each InferenceService is a separate CRD object, and they all share the same ClusterServingRuntime
- Your **ops team manages the model lifecycle** (A/B deployments, traffic splitting, canary rollouts via InferenceService spec fields) rather than application developers managing raw Deployments
- You want a **GitOps-friendly serving abstraction** — InferenceService CRs are declarative and version-controlled in the same repo as other Kubernetes resources
- You plan to use KServe's **storage initializer** integration later (S3, GCS, Azure Blob) once you move to larger models with object-store backends
- You are building toward **scale-to-zero** (KServe Serverless mode with Knative is the path to this; RawDeployment is the stepping stone)
- Your organization has **standardized on KServe** as the model serving layer across teams (shared ClusterServingRuntimes, central control-plane, consistent CRD-based API)

**Not a good fit when:** you cannot tolerate the ~700 Mi–1.5 GB control-plane overhead (cert-manager + KServe controller), your cluster does not allow cluster-scoped CRDs, or your team is not yet ready to operate the KServe control-plane (upgrades, cert-manager version pinning, webhook TLS management).

## What This Page Does Not Cover

:::note Deferred topics

**Latency benchmarks across the three patterns** — Running three patterns simultaneously requires three sets of backend pods plus the respective control-planes (router, KServe controller, cert-manager). This does not fit in the 16 GB KIND cluster RAM budget. Latency comparisons between patterns are deferred to an instructor demo in v1.1 using a GPU cluster where model load time is not the bottleneck.

**GPU comparisons** — All three patterns work identically on GPU-backed vLLM instances. GPU-specific sizing, cost economics, and throughput comparisons are instructor demo content in v1.1.

**Cost economics (build vs buy)** — Comparing self-hosted vLLM (any pattern) against API services (Groq, Gemini) requires cost data from production deployments. This is covered in v1.1 as GOVERN-04 (token-cost tracking middleware + cost dashboard).
:::
