# Phase 2: LLMOps Labs (Day 1) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-15
**Phase:** 02-llmops-labs-day-1
**Areas discussed:** Smile Dental data, Chainlit UI design, Lab progression, vLLM config

---

## Smile Dental Data

### Q1: How to globalize the clinic data?

| Option | Description | Selected |
|--------|-------------|----------|
| US-style clinic | USD, US phone format, insurance | |
| Generic/neutral | No specific country, $ symbol | |
| Keep as-is | Keep India context (INR, Pune) | ✓ |
| You decide | Claude picks | |

**User's choice:** Keep as-is (India context with Smile Dental name)

### Q2: How much synthetic data?

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal (current) | 4 treatments, 5 policies | |
| Richer dataset | 10-15 treatments, 8-10 policies, 10+ FAQs | ✓ |
| You decide | Claude picks | |

**User's choice:** Richer dataset

### Q3: Keep INR/Pune specifically?

| Option | Description | Selected |
|--------|-------------|----------|
| Keep INR/Pune | Just rename clinic | ✓ |
| Switch to USD | Rename + globalize pricing | |
| You decide | Claude picks | |

**User's choice:** Keep INR/Pune

### Q4: Include appointment data for Phase 3 agent?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, include now | Doctor schedules, slots for agent | ✓ |
| Add in Phase 3 | Keep Phase 2 RAG-only | |
| You decide | Claude decides | |

**User's choice:** Yes, include now

---

## Chainlit UI Design

### Q1: Glass-box learning mode implementation?

| Option | Description | Selected |
|--------|-------------|----------|
| Chainlit Steps | Built-in collapsible panels for each step | ✓ |
| Side panel | Custom dual-panel layout | |
| You decide | Claude picks | |

**User's choice:** Chainlit Steps

### Q2: Chat branding?

| Option | Description | Selected |
|--------|-------------|----------|
| Branded | Smile Dental logo, dental colors, welcome message | ✓ |
| Minimal | Clean default with just title | |
| You decide | Claude picks | |

**User's choice:** Branded

---

## Lab Progression

### Q1: How to split 6 sub-topics across labs?

| Option | Description | Selected |
|--------|-------------|----------|
| One lab per topic | 6 labs: data/RAG, fine-tune, package, serve, UI, observability | ✓ |
| Combine small labs | 5 labs, merge packaging+serving | |
| You decide | Claude decides | |

**User's choice:** One lab per topic (6 labs)

### Q2: Starter code approach?

| Option | Description | Selected |
|--------|-------------|----------|
| Skeleton starters | Empty placeholder files, student fills in | ✓ |
| Partial starters | Boilerplate pre-written, student adds core logic | |
| You decide | Claude picks | |

**User's choice:** Skeleton starters
**Notes:** Python app code should be PROVIDED in solution/. Students understand the code from lab guide, then copy. Focus on LLMOps concepts, not writing Python.

---

## vLLM Config

### Q1: KServe or plain Deployment?

| Option | Description | Selected |
|--------|-------------|----------|
| KServe RawDeployment | Current approach, more production concepts | |
| Plain Deployment first | Simpler K8s Deployment+Service | |
| You decide | Claude picks | |

**User's choice:** Other — "Plain manifest with vLLM. Also considering vLLM Router as alternative to KServe but don't want too much complexity."

### Q2: vLLM version?

| Option | Description | Selected |
|--------|-------------|----------|
| Update to 0.19.0 | Latest, needs CPU verification | ✓ |
| Keep 0.9.1 | Known working | |
| You decide | Claude verifies | |

**User's choice:** Update to 0.19.0

---

## Claude's Discretion

- Chainlit theme colors and logo
- FAISS index parameters
- LoRA hyperparameters
- Prometheus ServiceMonitor vs PodMonitor
- Grafana dashboard layout
- vLLM CPU flags

## Deferred Ideas

- vLLM Router as KServe alternative (evaluate later)
- Agent tool implementations (Phase 3)
