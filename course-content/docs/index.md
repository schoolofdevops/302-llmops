---
sidebar_position: 1
slug: /
---

# LLMOps & AgentOps with Kubernetes

A comprehensive hands-on course teaching how to take AI systems — LLMs and agents — from prototype to production on Kubernetes.

Build a dental clinic AI assistant (Smile Dental) from RAG retrieval through fine-tuning, packaging, serving, a chat UI, a multi-tool Hermes agent, GitOps deployments, and production observability.

## What You Will Build

- **RAG Retriever** — FAISS-backed semantic search over Smile Dental clinic data
- **Fine-Tuned LLM** — SmolLM2-135M trained on CPU with LoRA adapters
- **OCI Model Image** — Model packaged as a container, mounted via Kubernetes ImageVolumes
- **vLLM + KServe** — OpenAI-compatible serving with autoscaling on KIND
- **Chainlit Chat UI** — Streaming chat interface connected to the full RAG + LLM pipeline
- **Hermes Agent** — Multi-tool agent with triage, lookup, and booking capabilities
- **K8s Agent Sandbox** — Isolated agent deployment with OTEL tracing
- **Production Ops** — HPA/KEDA autoscaling, ArgoCD GitOps, Argo Workflows pipelines

## Prerequisites

- Docker Desktop with at least 8GB RAM allocated (12GB recommended)
- `kind`, `kubectl`, `helm` installed
- See the [Prerequisites](./setup/prerequisites) page for installation instructions

## How to Use This Course

Follow the labs in order from Lab 00 through Lab 13. Each lab builds on the previous one.
Use the companion code repository for starter files and reference solutions.
