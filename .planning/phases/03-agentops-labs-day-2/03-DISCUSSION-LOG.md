# Phase 3: AgentOps Labs (Day 2) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-02
**Phase:** 03-agentops-labs-day-2
**Areas discussed:** Hermes integration depth, K8s Agent Sandbox role, Tool implementations, Lab boundaries (07/08/09), Lean cluster between Day 1 and Day 2

---

## Hermes Integration Depth

### Q1: How to integrate Hermes Agent for the Smile Dental tools?

| Option | Description | Selected |
|--------|-------------|----------|
| Run upstream as-is + register tools | Use official hermes-agent container; configure + register 3 tools through its tool interface. Aligns with "configure and deploy, don't build" | ✓ |
| Fork and customize | Course-owned fork of hermes-agent with Smile Dental tools as Python modules; ship custom image | |
| Lightweight loop inspired by Hermes | Thin Python agent loop using openai SDK + tool-calling. Borrow Hermes patterns conceptually | |

**User's choice:** Run upstream as-is + register tools

### Q2: How should the 3 Smile Dental tools be surfaced to Hermes?

| Option | Description | Selected |
|--------|-------------|----------|
| MCP servers | Each tool runs as a small MCP server; Hermes connects via MCP protocol; demos the modern protocol | ✓ |
| HTTP endpoints + Hermes HTTP-tool wrapper | FastAPI endpoints; Hermes registers via OpenAPI; familiar K8s pattern | |
| In-process Python plugins | Tools as Python modules inside custom Hermes container; fastest in-process calls | |

**User's choice:** MCP servers

### Q3: Default LLM API for Day 2 lab walkthroughs?

| Option | Description | Selected |
|--------|-------------|----------|
| Groq | Fastest tokens/sec (LPU); generous free quota; OpenAI-compatible | |
| Google Gemini | Brand recognition; generous quota; OpenAI-compatible | |
| Both, side-by-side toggle | Lab shows both; students pick `GROQ_API_KEY` or `GEMINI_API_KEY`; doc both | ✓ |

**User's choice:** Both, side-by-side toggle

### Q4: How should agent session memory work?

| Option | Description | Selected |
|--------|-------------|----------|
| Stateless per-session | Each Chainlit session = fresh agent context; no persistent backend | ✓ |
| In-memory conversation history | History kept in Hermes process memory; lost on restart | |
| Persistent memory (sqlite/redis) | Adds backing store; demos Hermes persistent memory feature | |

**User's choice:** Stateless per-session

---

## K8s Agent Sandbox Role

### Q5: How should the agent map to Sandbox resources?

| Option | Description | Selected |
|--------|-------------|----------|
| Per-session Sandbox from warm pool | Each session claims pre-warmed Sandbox; demos isolation + warm-pool benefit | ✓ |
| Single long-running Sandbox | One Sandbox serves all sessions; warm pool becomes academic | |
| Per-tool-invocation Sandbox | Agent as normal Deployment; spawns ephemeral Sandbox per tool call; doesn't match SANDBOX-02 | |

**User's choice:** Per-session Sandbox from warm pool

### Q6: How should the agent (inside Sandbox) reach the RAG retriever?

| Option | Description | Selected |
|--------|-------------|----------|
| Egress allow-list | NetworkPolicy allows egress to retriever + LLM API endpoints only | ✓ |
| Open egress | Sandbox allows all egress; simpler but isolation story weak | |
| Sidecar proxy in Sandbox | Sidecar proxies outbound calls; complex; overkill | |

**User's choice:** Egress allow-list

### Q7: How should users reach the agent from outside (Sandbox stable identity / gateway)?

| Option | Description | Selected |
|--------|-------------|----------|
| Sandbox gateway via Chainlit UI proxy | Chainlit (NodePort 30300) is front door; calls Sandbox via Gateway; reuses familiar UI | ✓ |
| Sandbox gateway exposed directly via NodePort | Curl-based access; thinner UI lab content | |
| Both: UI for chat, NodePort for curl | Doc both paths; more content | |

**User's choice:** Sandbox gateway via Chainlit UI proxy

### Q8: Warm pool sizing + cold-start demo design?

| Option | Description | Selected |
|--------|-------------|----------|
| Pool size 2; demo cold vs warm by scaling pool to 0 | Cleanest demo; minimal cluster load | ✓ |
| Pool size 1; demo via two parallel requests | Smaller footprint; trickier demo | |
| You decide | Researcher/planner picks defaults | |

**User's choice:** Pool size 2; scale-to-0 demo pattern

---

## Tool Implementations

### Q9: How should the triage tool decide severity?

| Option | Description | Selected |
|--------|-------------|----------|
| LLM-prompted classifier | LLM with rubric; parses JSON; demos LLM-as-tool-impl | ✓ |
| Rule-based keyword match | Hardcoded keywords; deterministic; mechanical | |
| Hybrid: rules first, LLM fallback | Quick rules + LLM for ambiguous cases | |

**User's choice:** LLM-prompted classifier

### Q10: How should the treatment-lookup tool work?

| Option | Description | Selected |
|--------|-------------|----------|
| Wraps existing RAG retriever | Tool calls retriever `/search`; reuses Day 1 work | ✓ |
| RAG + structured price/duration JSON | RAG + ConfigMap-mounted treatments.json | |
| Direct LLM call with RAG context | Tool internally does RAG + LLM synthesis | |

**User's choice:** Wraps existing RAG retriever

### Q11: How should the appointment-booking tool persist state?

| Option | Description | Selected |
|--------|-------------|----------|
| ConfigMap-backed JSON | Bookings to ConfigMap; visible via kubectl; pedagogically fun | ✓ |
| In-memory dict in MCP server | Fastest; lost on restart | |
| SQLite on PVC | Real DB; adds storage discussion; heavy | |

**User's choice:** ConfigMap-backed JSON

### Q12: Multi-step workflow demo (AGENT-04 success criterion #1) — canonical example?

| Option | Description | Selected |
|--------|-------------|----------|
| Symptom → triage → lookup → book | "severe tooth pain" → triage(severe) → lookup(emergency root canal) → book(soonest); hits all 3 tools | ✓ |
| Free-form: agent picks tools as needed | Several queries; agent chooses; less scripted | |
| Both: scripted canonical + free-form exploration | Canonical example + 2-3 student-driven queries | |

**User's choice:** Symptom → triage → lookup → book

---

## Lab Boundaries (07/08/09)

### Q13: How should the 11 Phase 3 requirements split across labs 07/08/09?

| Option | Description | Selected |
|--------|-------------|----------|
| 07=agent+tools (Docker), 08=K8s Sandbox, 09=OTEL | Matches lab page names; clear arc per lab | ✓ |
| 07=agent on K8s (Deployment), 08=migrate to Sandbox, 09=OTEL | Teaches "why Sandbox" by contrast | |
| 07=agent+Sandbox basic, 08=WarmPool+Gateway, 09=OTEL | Spreads Sandbox content across 2 labs | |

**User's choice:** 07=agent+tools (Docker), 08=K8s Sandbox, 09=OTEL

### Q14: Trace backend for OTEL traces (OBS-07)?

| Option | Description | Selected |
|--------|-------------|----------|
| Grafana Tempo | Native Grafana integration; reuses Day 1 dashboard; lighter than Jaeger | ✓ |
| Jaeger | Separate UI; familiar name; doesn't reuse Day 1 Grafana | |
| Both, student choice | Doc both; more content | |

**User's choice:** Grafana Tempo

### Q15: How should API cost tracking (OBS-05) be implemented?

| Option | Description | Selected |
|--------|-------------|----------|
| Prometheus counter from agent middleware | `agent_llm_tokens_total` + `agent_llm_cost_usd_total`; Grafana dashboard | ✓ |
| OTEL span attributes only | Token + cost as span attrs; visible in Tempo | |
| Both: span attributes + Prometheus counters | Most complete; most code | |

**User's choice:** Prometheus counter from agent middleware

### Q16: What goes in the OTEL trace span tree per agent request?

| Option | Description | Selected |
|--------|-------------|----------|
| Hierarchical: agent.request → llm.completion + tool.invoke (with mcp.call child) + retriever.search nested under treatment_lookup | Full chain visible in Tempo | ✓ |
| Flat: one span per major step | Simpler; loses "distributed" story | |
| You decide | Researcher picks based on OTEL semantic conventions | |

**User's choice:** Hierarchical span tree

---

## Lean Cluster Between Day 1 and Day 2 (post-discussion follow-up)

### Q17: What to do with the Day 1 vLLM serving stack during Day 2?

| Option | Description | Selected |
|--------|-------------|----------|
| Tear down vLLM at start of Day 2 via cleanup script | Lab 07 starts with cleanup-day1-llm.sh deleting vllm Deployment + Service | |
| Scale vLLM Deployment to 0 (keep manifest) | kubectl scale to 0; manifest stays; quick to bring back | ✓ |
| Keep vLLM running | Wastes ~2-4 GB RAM and CPU | |
| Tear down vLLM AND retriever | Aggressive; not viable since retriever is reused | |

**User's choice:** Scale vLLM Deployment to 0 (keep manifest)

### Q18: Where in the lab flow should the cleanup happen?

| Option | Description | Selected |
|--------|-------------|----------|
| First step of Lab 07 | Lab 07 opens with "Free Day 1 resources" section | |
| End of Lab 06 / Day 1 wrap | Day 1 ends with wind-down; Day 2 starts fresh | ✓ |
| Optional reference script, not enforced | Doc-only; students choose | |

**User's choice:** End of Lab 06 / Day 1 wrap

---

## Claude's Discretion

- Container build / image registry strategy for the 3 MCP tool images
- Hermes container image source / tag (researcher confirms upstream tag and CPU compatibility)
- Static USD price table values (researcher fetches current Groq/Gemini free-tier rates)
- Sandbox CRD version + warm-pool spec syntax (researcher fetches current K8s Agent Sandbox docs)
- MCP transport choice within K8s (stdio over sidecar vs SSE/HTTP — depends on hermes-agent client support)
- Chainlit changes for Day 2 (Sandbox Gateway call path, glass-box step kind for tool calls)
- OTEL collector deploy mode (DaemonSet vs Deployment) — pick based on KIND footprint
- Tempo storage backend (in-memory for KIND)
- Exact wording + commands for Lab 06 wind-down
- Symmetric "scale vLLM back up" prelude in Phase 4 / Day 3 first lab

## Deferred Ideas

- Persistent agent memory across sessions
- Multi-agent coordination via Sandbox (already in v2: MULTI-01, MULTI-02)
- Langfuse trace dashboard (already deferred in v2: ADV-OBS-01)
- Code-interpreter / shell tool inside Sandbox
- Real calendar/EHR integration for booking
- Custom Hermes fork with course-specific prompts baked in
- Jaeger as alternative trace backend
