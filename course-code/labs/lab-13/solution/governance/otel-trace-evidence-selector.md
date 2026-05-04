# OTEL trace evidence selectors (GUARD-03 Pillar 3)

These TraceQL queries (Tempo) and Grafana Explore URLs are the canonical evidence-gathering recipes the Lab 13 Governance section cites. They produce screenshot-ready output for audits.

## Recipe 1: "Show me the trace where Aetna+root canal was queried on date D"

**TraceQL:**
```
{ resource.service.name = "mcp-insurance-check" && span.tool.arguments =~ ".*Aetna.*root canal.*" }
```

**Grafana Explore URL** (replace `<DATE>` with the audit date in `YYYY-MM-DDTHH:mm:ssZ` form):
```
http://localhost:30500/explore?left=%7B%22datasource%22:%22Tempo%22,%22queries%22:%5B%7B%22query%22:%22%7B%20resource.service.name%20%3D%20%5C%22mcp-insurance-check%5C%22%20%7D%22%7D%5D,%22range%22:%7B%22from%22:%22<DATE>%22,%22to%22:%22now%22%7D%7D
```

## Recipe 2: "Show me a guardrail-blocked query trace"

The GuardrailMiddleware raises `ToolError` on a blocked input — Tempo records this as `status=error` on the tool's span.

**TraceQL:**
```
{ resource.service.name =~ "mcp-.*" && status = error }
```

This catches blocks across all 4 MCP tools (triage, treatment_lookup, book_appointment, insurance_check).

## Recipe 3: "Show me the cost panel for the audit window"

Lab 09's cost middleware exports `agent_llm_cost_usd_total`. The auto-discovered Grafana dashboard (Phase 3 Lab 09) has a "Smile Dental — LLM Cost" panel.

**Grafana dashboard URL:**
```
http://localhost:30500/d/smile-dental-cost
```

Set the time range to the audit window. Screenshot the panel. Include in compliance report.

## Recipe 4: End-to-end audit query — "What was deployed on date D, and what did it serve?"

Three steps:

1. `argocd app history vllm` (or `kubectl get application vllm -n argocd -o jsonpath='{.status.history}'`) — find the revision SHA active at date D
2. `git show <SHA>:course-code/labs/lab-11/solution/gitops-repo/bases/vllm/30-deploy-vllm.yaml | grep gitops/model-version` — extract the model-version tag in effect
3. Use Recipe 1 with date D — extract a sample of traces showing what users actually asked

The combination is the audit trail: image version + GitOps deploy time + runtime evidence.

## Notes

- All three pillars exist BEFORE Lab 13. GUARD-03 (D-18) is the act of teaching students to combine them, not building new infrastructure.
- For real production audits, store the output of `audit-trail-queries.sh` and the screenshot of Recipe 3 in your evidence repository on the date of each release.
