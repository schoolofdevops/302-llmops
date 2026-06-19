# Milestones

## v1.0.0 LLMOps with Kubernetes (Shipped: 2026-06-19)

**Phases completed:** 6 phases, 24 plans
**Stats:** 198 commits, 254 files changed, 44,663 lines added
**Timeline:** 2026-04-12 → 2026-06-18 (67 days)

**Key accomplishments:**

- Curriculum split: AgentOps content migrated to `schoolofdevops/303-agentops`; v0.19.0 frozen with maintenance branch; 302-llmops main is LLMOps-only with Docusaurus redirects for all removed lab URLs
- Labs 00–05 restored and modernized: KIND 1.34 + ImageVolume feature gates, synthetic data + FAISS RAG, CPU LoRA fine-tune (SmolLM2-135M, max_steps=50), OCI packaging, plain vLLM Deployment + Chainlit UI, kube-prometheus-stack 83.4.2 observability
- Lab 06: Disk-based model loading via MinIO initContainer + emptyDir sizeLimit (sha256 sentinel pattern) + OCI vs disk decision tree
- Lab 07: vLLM Production Stack router (vllm-stack chart 0.1.11) — 2 CPU backends, session routing demo, KEDA scale-up
- Lab 08: KServe v0.18.0 InferenceService (RawDeployment, no Knative) with cert-manager v1.16.5 + Gateway API CRDs v1.2.1; separate NodePort Service workaround (KServe reconciles predictor Service to ClusterIP)
- Lab 09: Serving decision page — side-by-side comparison of all three patterns with decision tree
- Lab 10: Autoscaling — HPA on rag-retriever, KEDA ScaledObjects for Pattern A and C, Grafana dashboard; KEDA serverAddress = `kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090`
- Lab 11: ArgoCD 9.5.11 App-of-Apps + model promotion via `spec.template.metadata.annotations` bump (pod-template, not Deployment metadata — critical for rolling restart trigger); probe timeout 15s fix for KIND stability
- Lab 12: Argo Workflows 1.0.13 — 5-step DAG (data-gen→build-index→train→merge→promote) with alpine/git + SSH deploy key for fully-automated E2E LLMOps loop

**Archive:** [v1.0.0-ROADMAP.md](milestones/v1.0.0-ROADMAP.md) | [v1.0.0-REQUIREMENTS.md](milestones/v1.0.0-REQUIREMENTS.md)

---

## v0.19.0 LLMOps & AgentOps Course (3-Day Workshop) (Shipped: 2026-05-05)

**Phases completed:** 5 phases, 30 plans, 44 tasks

**Key accomplishments:**

- 14-lab companion code repository skeleton with starter/solution structure, shared infrastructure directories, central config.env, and student workflow README
- Docusaurus 3.10.0 course site with dark-mode Kubernetes.io theme, 14 lab placeholder pages, OS-specific Tabs pattern, and single sequential courseSidebar — build exits 0
- Cross-platform environment validation scripts: bash preflight-check.sh (macOS/Linux/Git Bash) and PowerShell preflight-check.ps1 (Windows), both checking Docker memory, required tools, port availability, and stale KIND clusters
- 3-node KIND cluster config with dual ImageVolume feature gates, bootstrap script with REPLACE_HOST_PATH substitution, 5-namespace manifest, and 14-component COURSE_VERSIONS.md
- Three bash cleanup scripts (cleanup-phase1.sh, -phase2.sh, -phase3.sh) that free KIND cluster memory between lab phases using kubectl --ignore-not-found and helm status guards
- Replaced abandoned schoolofdevops/vllm-cpu-nonuma:0.9.1 with official vllm/vllm-openai-cpu:v0.19.0-x86_64 in config.env and COURSE_VERSIONS.md
- One-liner:
- CPU LoRA fine-tuning of SmolLM2-135M-Instruct via PEFT 0.19.0 with K8s batch Job, max_steps=50 completing in ~15 minutes
- Alpine:3.20 model-as-OCI-image packaging with build script, plus CPU vLLM Deployment on KIND using ImageVolume mount at nodePort 30200
- Chainlit 2.11.0 chat UI with 3 collapsible pipeline Steps (RAG retrieval, prompt construction, LLM generation streaming) deployed on NodePort 30300 in llm-app namespace
- One-liner:
- One-liner:
- Surgical 3-file edit: replace llmops-project/lab-01/ sub-dirs with flat llmops-project/ paths and substitute pip install with uv pip install --system in student-facing steps
- Day 2 version pins (Hermes, Sandbox v0.4.3, MCP 1.27.0, OTEL 1.41.1, Tempo 1.24.4) landed in COURSE_VERSIONS.md and config.env, with Lab 06 wind-down subsection freeing ~2-4 GB before Lab 07
- 1. [Rule 3 - Blocking] Dockerfile build context path wrong
- 1. [Rule 3 - Blocking] HTML comment syntax breaks MDX parser
- 1. [Rule 1 - Bug] hermes-agent overwrites /etc/resolv.conf — DNS breaks for in-cluster MCP services
- Line count management:
- One-liner:
- One-liner:
- Phase 4 infrastructure pinned: KEDA 2.19.0 / ArgoCD 9.5.11 / Argo Workflows 1.0.13 / DeepEval 3.9.9 version table in COURSE_VERSIONS.md, Day 3 namespaces in config.env, cleanup-phase4.sh teardown, and vLLM scale-back-up prereq script for Lab 10
- One-liner:
- One-liner:
- ArgoCD 9.5.11 installed in argocd namespace via Helm with NodePort 30700, all 5 RESEARCH.md value overrides applied (dex/notifications/applicationSet disabled, insecure HTTP), and 4 bootstrap scripts committed
- Full Lab 11 GitOps walkthrough (411 lines) with embedded live evidence, D-20 honest scoping, SSH deploy-key setup, and GUARD-03 audit trail anchor
- One-liner:
- One-liner:
- Test count:
- One-liner:
- Root App-of-Apps smile-dental-apps with 5 child Applications (monitoring, vllm, rag-retriever, agent-sandbox, chainlit) all Synced + Healthy; GITOPS-02 annotation-bump demo auto-synced by ArgoCD in 70 seconds

---
