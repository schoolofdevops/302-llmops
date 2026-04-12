# LLMOps & AgentOps with Kubernetes

## What This Is

A comprehensive, hands-on course that teaches how to productionize LLM applications and AI agents on Kubernetes. Students build a dental clinic assistant (Smile Dental) from scratch — starting with RAG and fine-tuning, evolving into a multi-tool agent, then deploying it with production-grade observability, autoscaling, GitOps, and Kubernetes Agent Sandbox. Designed for DevOps engineers, ML engineers, and full-stack developers. Delivered as both instructor-led 3-day workshops and a self-paced Udemy course.

## Core Value

Teach practitioners how to take AI systems (LLMs + agents) from prototype to production on Kubernetes — the only course that covers the full journey from RAG to agentic deployments with K8s Agent Sandbox.

## Requirements

### Validated

(Existing course covers these topics — being rewritten from scratch with modernized content)

- Kubernetes cluster setup (KIND) with ImageVolumes — existing (Lab 00)
- Synthetic data generation + FAISS RAG retriever — existing (Lab 01)
- CPU LoRA fine-tuning of SmolLM2 — existing (Lab 02)
- Model packaging as OCI image — existing (Lab 03)
- Model serving with KServe + vLLM — existing (Lab 04)
- Prometheus + Grafana observability for LLM workloads — existing (Lab 05)
- Autoscaling with HPA/KEDA/VPA — existing (Lab 06)
- GitOps with ArgoCD — existing (Lab 07)
- Argo Workflows for LLM pipelines — existing (Lab 08)

### Active

- [ ] Rewrite all labs from scratch with fresh structure and modern tooling
- [ ] Rename domain from "Atharva Dental Clinic" to "Smile Dental" globally
- [ ] Replace CLI-based API interactions with a web UI (e.g., chat interface)
- [ ] Add agentic capabilities — extend dental assistant into a multi-tool agent (appointment booking, treatment lookup, triage workflows)
- [ ] Add Kubernetes Agent Sandbox module — deploy agents using the new Sandbox CRD, SandboxWarmPool, and Python SDK
- [ ] Create companion code repository with starter/ and solution/ directories per module
- [ ] Convert documentation site from MkDocs (readthedocs theme) to Docusaurus
- [ ] Structure for 3-day workshop format (~24 hours, 12-15 labs)
- [ ] Ensure all content is 2026-relevant (current AI landscape, modern frameworks, latest K8s features)
- [ ] Design for dual delivery: instructor-led workshop + Udemy self-paced course
- [ ] Evaluate and integrate LLM evaluation/testing practices (evals, guardrails)
- [ ] Research modern agent frameworks (LangGraph, CrewAI, Claude Agent SDK, OpenAI Agents SDK) for the agentic modules

### Out of Scope

- GPU-specific content — course stays CPU-friendly for accessibility on laptops
- Cloud-specific managed services (EKS/GKE/AKS specifics) — keep cloud-agnostic with KIND
- Mobile app or native UI — web interface only
- Enterprise auth/SSO integration — keep demo-grade for learning

## Context

**Current state:** Existing course has 9 labs (00-08) using MkDocs with readthedocs theme. All code is inline (copy-paste). Domain is "Atharva Dental Clinic" with India-specific context (INR, Pune). Application is CLI/curl-based. No agent capabilities. No web UI.

**What's changing in the AI world (2026):**
- Agentic AI is mainstream — tool-using, multi-step agents are production workloads
- Kubernetes Agent Sandbox (k8s-sigs) provides first-class primitives for agent workloads (Sandbox CRD, warm pools, isolation)
- LLM evaluation and guardrails are now expected practices
- Agent frameworks have matured (LangGraph, CrewAI, Anthropic Agent SDK, OpenAI Agents SDK)
- vLLM has evolved significantly; model serving landscape has shifted
- Observability for AI has expanded beyond basic metrics to include traces, evals, cost tracking

**Brownfield context:** The `llmops-labuide/` directory contains the existing MkDocs site with all lab content. The `slides/` directory has presentation PDFs/DOCX for 5 modules. Both will be replaced with the rewritten course.

**Target audience:** Mixed — DevOps/platform engineers, ML/AI engineers, and full-stack developers. Course must bridge Kubernetes expertise and AI/ML expertise.

**Delivery:** 3-day instructor-led workshop AND bestselling Udemy course. Code companion repo with starter/solution per module.

## Constraints

- **Duration**: ~24 hours of content fitting a 3-day workshop format (12-15 labs)
- **Hardware**: Must run on laptops with 16GB RAM, CPU-only (KIND clusters)
- **Code delivery**: Companion Git repo with starter/ and solution/ per module — no copy-paste walls
- **Site platform**: Docusaurus (replacing MkDocs)
- **Naming**: "Smile Dental" (not "Atharva") — globally accessible branding
- **Model size**: Small models (SmolLM2-135M or similar) that work on CPU

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Rewrite from scratch vs. update existing | User wants fresh structure, modern flow, and fundamentally different scope (adding agents, web UI, new tooling) | Rewrite from scratch |
| Rename Atharva to Smile Dental | "Atharva" is India-specific, hard to type globally; "Smile" is universally accessible | Pending implementation |
| Docusaurus over MkDocs | Modern React-based doc framework, better for course sites with interactive elements, versioning, search | Pending |
| Starter + solution code structure | Eliminates copy-paste walls; students get working starter code and can reference solutions | Pending |
| Kubernetes Agent Sandbox for agentic module | First-class K8s primitive for agent workloads — new, differentiated, production-relevant | Pending |
| Agent framework choice | Need to research which framework best fits the course (LangGraph vs CrewAI vs Anthropic SDK vs OpenAI SDK) | Pending research |
| Dual delivery format | Workshop (3-day) + Udemy maximizes reach and revenue | Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-12 after initialization*
