# LLMOps with Kubernetes

Hands-on course teaching production LLM serving on Kubernetes — from synthetic data and LoRA fine-tuning through model packaging, three serving patterns (plain vLLM, KServe, vLLM Router), observability, autoscaling, and GitOps.

**Companion course (AgentOps):** https://github.com/schoolofdevops/303-agentops

## Which version are you on?

| Version | Branch/Tag | Content |
|---------|------------|---------|
| **v1.0.0+** (current) | `main` | LLMOps-only: Labs 00-06 + new serving patterns. AgentOps removed. |
| **v0.19.0** (archived) | [`v0.19.0` tag](https://github.com/schoolofdevops/302-llmops/tree/v0.19.0) | Combined LLMOps + AgentOps (Labs 00-13) — 3-day workshop |
| **v0.19.x** (maintenance) | [`v0.19.x` branch](https://github.com/schoolofdevops/302-llmops/tree/v0.19.x) | Bug fixes for v0.19.0 students during the transition window |
| **AgentOps** | [303-agentops](https://github.com/schoolofdevops/303-agentops) | Hermes Agent, MCP tools, Kubernetes Agent Sandbox — companion course |

**If you enrolled in the Udemy course on the combined LLMOps + AgentOps workshop:** pin your fork to the `v0.19.0` tag or `v0.19.x` branch. The v0.19.0 content is permanently available there.

**If you want the latest LLMOps-only course:** you are on the right branch (`main`). v1.0.0 covers multiple serving patterns (plain vLLM Deployment, KServe InferenceService, vLLM Router), disk-based model loading, and a full Argo Workflows training pipeline.

**If you want AgentOps content:** https://github.com/schoolofdevops/303-agentops — builds on this course as a prerequisite.

## Course Site

https://llmops.schoolofdevops.com (Docusaurus — built from `course-content/`)

## Quick Start

See Lab 00 in the course site for cluster setup. Requires Docker Desktop + KIND + 16GB RAM.
