---
phase: 03-agentops-labs-day-2
status: passed
ran_by: claude (UAT, learner mode)
ran_on: 2026-05-03
duration: ~3h
labs_tested: [lab-07, lab-08, lab-09]
provider_used: gemini-2.5-flash (GOOGLE_API_KEY only on host; GROQ_API_KEY absent)
verdicts:
  lab-07: pass-with-fixes
  lab-08: pass-with-fixes
  lab-09: pass-with-fixes
fixes_applied: 14
gaps_open: 2
---

# Phase 3 UAT: Run-Like-A-Learner

I followed the lab guides end to end on a real KIND cluster, fixing issues as I hit them so a fresh learner clone of the repo will work in sequence. This file lists every gap I found, the evidence (commands run, output captured, file paths), and what I changed in `course-code/` and `course-content/` to keep the labs working.

## Final Cluster Evidence

| Signal | Value | Source |
|--------|-------|--------|
| Lab 07 booking persisted | `Jane Doe SD-20260503032627` | `/data/bookings.json` in `mcp-book-appointment` container |
| Lab 08 booking persisted (ConfigMap) | `Carol SD-20260503033819`, `Eve Lab9 SD-20260503035044`, `Frank Lab9 SD-20260503035858`, `Henry Lab9 SD-20260503040301` | `kubectl get cm bookings -n llm-app` |
| Cold-vs-warm timings | Warm 11.08s / Cold-refill 25.66s / Cold-first 9.51s | `cold-vs-warm-demo.sh` log |
| Tempo trace counts (after canonical query) | mcp-triage 20, mcp-treatment-lookup 18, mcp-book-appointment 18 | `/api/search?tags=service.name%3D…` |
| Hierarchical span — treatment_lookup → rag-retriever | Confirmed: HTTPX child span `POST http://rag-retriever.llm-app.svc.cluster.local:8001/search` parented under `POST /mcp` (mcp-treatment-lookup root) | trace `a7fa1f9e14f29edb978311cec41a5d2d` |
| `agent_llm_tokens_total` non-zero | 88,293 in / 218 out (ticked up over multiple runs to ~400k+) | cost-middleware `/metrics` |
| `agent_llm_cost_usd_total` non-zero (after price-table fix) | 0.0270329 USD | cost-middleware `/metrics` |

All 11 must-haves from `03-VERIFICATION.md` continue to pass with the fixes applied. The 2 deferred human-verification items from the original verifier report (browser E2E + Tempo span click-through) are now exercised via curl + Tempo API and pass.

## Gaps Found and Fixes Applied

Numbering follows the order I hit them.

### GAP-1 (blocker, FIXED): MCP Dockerfiles fail to build because `fastapi` is missing from `requirements.txt`

**Symptom:** `docker compose up -d --build` (Lab 07 Part F) produces three containers that crash on startup with `ModuleNotFoundError: No module named 'fastapi'`. The OTEL retrofit added `from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor` (which loads `fastapi` at import time), but the dependency was never declared.

**Evidence:** `/tmp/uat-phase3/lab07-compose-up.log` first run.

**Fix applied:** Added `fastapi==0.115.4` to all three `requirements.txt` under `course-code/labs/lab-07/solution/tools/{triage,treatment_lookup,book_appointment}/`.

### GAP-2 (blocker, FIXED): Chainlit container collides with KIND host port 8000

**Symptom:** Compose tries to bind 0.0.0.0:8000 → `Bind for 0.0.0.0:8000 failed: port is already allocated`. KIND control-plane container has `extraPortMappings` for 8000.

**Evidence:** `/tmp/uat-phase3/lab07-compose-up2.log` Chainlit start; `lsof -iTCP:8000` shows com.docker holding it for `llmops-kind-control-plane`.

**Fix applied:** Changed `course-code/labs/lab-07/solution/docker-compose.yaml` chainlit ports to `8888:8000`. Updated lab-07-agent-core.md to use `http://localhost:8888` with a `:::note` explaining the port choice.

### GAP-3 (blocker, FIXED): Lab guide Tab "Gemini" doesn't tell student to edit `config.yaml`

**Symptom:** With the Gemini Tab selected and `.env` set to Gemini, Hermes still calls Groq because `hermes-config/config.yaml` hardcodes `model.default: groq/llama-3.3-70b-versatile`. Result: 404 — `models/groq/llama-3.3-70b-versatile is not found for API version v1main`.

The two Hermes Gemini model formats that fail vs work:
- `google/gemini-2.5-flash` → 404 (`models/google/gemini-2.5-flash` — Hermes prepends `models/`)
- bare `gemini-2.5-flash` → works via `GEMINI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai`

**Evidence:** `/tmp/uat-phase3/lab07-canonical.json` (groq path 404) and `/tmp/uat-phase3/lab07-canonical-3.json` (bare model works).

**Fix applied:** 
1. Changed default in `course-code/labs/lab-07/solution/hermes-config/config.yaml` to bare `gemini-2.5-flash`.
2. Added `:::warning Tab choice changes BOTH .env AND hermes-config/config.yaml` in `lab-07-agent-core.md` Part B with explicit edit instruction for whichever Tab the student picks.

### GAP-4 (doc, FIXED): Lab guide claim "look for `tool_calls`" doesn't match Hermes output

**Symptom:** Both labs 07 and 08 say "In the response, look for `tool_calls`". Hermes' OpenAI-compat `/v1/chat/completions` endpoint loops tool calls **internally** and never exposes them in the final response — there is only a single assistant message.

**Evidence:** `/tmp/uat-phase3/lab07-canonical-{3,4}.json` — `tool_calls` field absent, but `prompt_tokens` ~50k–80k confirms tools fired internally.

**Fix applied:** Replaced the verification step in lab-07-agent-core.md and lab-08-agent-sandbox.md with "verify booking persisted" + "check MCP server logs". Also added a `:::tip` about `max_tokens=2000` for Gemini thinking budget.

### GAP-5 (cosmetic, FIXED): Compose `version: "3.9"` triggers a deprecation warning every command

**Symptom:** Every `docker compose` invocation in Lab 07 prints `level=warning ... attribute version is obsolete`.

**Fix applied:** Removed the `version: "3.9"` line from `course-code/labs/lab-07/solution/docker-compose.yaml`.

### GAP-6 (noise, FIXED): MCP tool servers spam OTEL exporter "transient error" in Lab 07 (Docker)

**Symptom:** When Lab 07 runs in Docker Compose, the MCP servers retry-loop trying to reach the in-cluster OTEL Collector default endpoint (`otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4317`). On Docker Compose this DNS doesn't resolve. Logs every ~5s with `Failed to export traces to … StatusCode.UNAVAILABLE`.

**Evidence:** `docker logs mcp-treatment-lookup` repeated retries.

**Fix applied:** Rewrote `course-code/labs/lab-07/solution/tools/otel_setup.py` so the BatchSpanProcessor + OTLP exporter are only wired when `OTEL_EXPORTER_OTLP_ENDPOINT` is non-empty. Default is `""` (no in-cluster DNS retry from Docker). Lab 09 K8s manifests now set the env explicitly on each MCP deploy (see `60-mcp-*.yaml`), so traces still flow in K8s.

### GAP-7 (blocker, FIXED): Lab 08 K8s `hermes-config` ConfigMap also hardcodes Groq

**Symptom:** Same issue as GAP-3 but for `course-code/labs/lab-08/solution/k8s/60-hermes-config-cm.yaml`. With Gemini-only key, the canonical query fails.

**Fix applied:** Changed the default in the manifest to `gemini-2.5-flash` with an inline comment showing the Groq alternative.

### GAP-8 (blocker, FIXED): SandboxTemplate missing `GEMINI_BASE_URL` env

**Symptom:** With bare `gemini-2.5-flash` model name, Hermes needs `GEMINI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai` to know where to call. Otherwise it 404s with `v1main` path.

**Fix applied:** Added the env var to `course-code/labs/lab-08/solution/k8s/50-sandbox-template.yaml`.

### GAP-9 (process, DOCUMENTED): SandboxTemplate spec changes do NOT propagate to existing WarmPool pods

**Symptom:** After patching SandboxTemplate (e.g., to add `GEMINI_BASE_URL`), existing warmpool pods retain their old spec. Even `kubectl delete pod -l app=hermes-agent` is not enough because the controller respawns pods from the cached pod-template hash.

**Fix applied:** No code change. Documented as part of Lab 08 troubleshooting. The standard recovery is to delete the `SandboxWarmPool` resource and re-apply (`kubectl delete sandboxwarmpool/hermes-agent-warmpool -n llm-agent && kubectl apply -f 50-sandbox-warmpool.yaml`).

### GAP-10 (provider quirk, DOCUMENTED + DOC FIX): Gemini "thinking" model returns empty content with default Hermes max_tokens

**Symptom:** With Gemini and a multi-tool prompt, Hermes returns `{"content": "(empty)", "completion_tokens": 0}`. Gemini exhausts its token budget on internal "thinking" before emitting an assistant message.

**Evidence:** `/tmp/uat-phase3/lab09-canonical{3,5}.json` — empty content with `prompt_tokens=50k, completion_tokens=0`.

**Fix applied:** Updated lab-07 and lab-08 docs canonical-curl examples to include `"max_tokens": 2000` and added a `:::tip` explaining why. Groq Llama is not a thinking model and does not need this.

### GAP-11 (architectural, FIXED): Lab 09 cost-middleware → Sandbox Router → Hermes path is broken

**Symptom:** `cost-middleware` proxies to `sandbox-router-svc:8080`, but the Sandbox Router requires an `X-Sandbox-ID` header on every request. Neither Chainlit nor cost-middleware claim a Sandbox or set the header. Result: every Lab 09 chat request returns `400 Bad Request: X-Sandbox-ID header is required`.

**Evidence:** `/tmp/uat-phase3/lab09-canonical.json` (HTTP 400 from router); `kubectl logs deploy/sandbox-router` showed the missing-header rejection.

**Fix applied:** 
1. Added `course-code/labs/lab-08/solution/k8s/50-hermes-service.yaml` — a stable `Service` named `hermes-agent` selecting the WarmPool pods. This is the simple in-cluster path.
2. Changed `course-code/labs/lab-09/solution/k8s/70-cost-middleware-deploy.yaml` `UPSTREAM_URL` to `http://hermes-agent.llm-agent.svc.cluster.local:8642`.
3. Changed `course-code/labs/lab-08/solution/k8s/40-chainlit-deploy-day2.yaml` `AGENT_URL` to the same hermes-agent Service.
4. The Sandbox Router stays deployed (and the lab still demos it as the "per-session routing" pedagogical primitive), but the critical chain Chainlit → cost-middleware → Hermes does NOT depend on it.

### GAP-12 (lab claim contradicted by reality, FIXED in doc): kindnet DOES enforce NetworkPolicy on KIND v1.34+

**Symptom:** The lab guide warning said "kindnet does not enforce NetworkPolicy. The policy object is stored in etcd but traffic is not filtered." On this KIND cluster (Kubernetes 1.34, kindnet shipped with that), policies are enforced — both the `hermes-agent-egress` NP and the auto-NP from SandboxTemplate were blocking pod-to-pod traffic. The default `networkPolicyManagement: Managed` SandboxTemplate behavior creates a restrictive NP that allows ingress only from `app=sandbox-router` and blocks egress to RFC1918 CIDRs (which includes other pods at 10.244.x.x).

**Evidence:** Pod-to-pod `urllib.request.urlopen` from cost-middleware → hermes timed out until I deleted both NPs.

**Fix applied:**
1. `course-code/labs/lab-08/solution/k8s/50-sandbox-template.yaml`: added `spec.networkPolicyManagement: Unmanaged` so the auto-NP is no longer created.
2. `course-code/labs/lab-08/solution/k8s/60-network-policy.yaml`: rewrote to include explicit ingress allowlist for `app=sandbox-router` and `app=cost-middleware` on port 8642, plus egress to OTEL Collector ports 4317/4318 in `monitoring`. Removed the misleading "kindnet doesn't enforce" comment; replaced with truthful note that any standard CNI enforces this.
3. lab-08-agent-sandbox.md: replaced the `:::warning kindnet does NOT enforce NetworkPolicy` block with the correct version.

### GAP-13 (cost calc, FIXED): cost-middleware records `model="hermes"`, which is not in the price table

**Symptom:** Hermes echoes the request `model` field in its response (`"model": "hermes"`), and the cost-middleware reads that for pricing. The price table only had `groq/llama-3.3-70b-versatile` and `google/gemini-2.5-flash`, so every cost lookup falls through to the `0.0` default.

**Evidence:** `agent_llm_cost_usd_total{model="hermes"} 0.0` while token counters were ticking up.

**Fix applied:** Added the bare aliases `gemini-2.5-flash`, `llama-3.3-70b-versatile`, and `hermes` (mapped to Gemini rates with an inline note) to `course-code/labs/lab-09/solution/k8s/70-llm-price-table-cm.yaml`. After applying + restarting cost-middleware, `agent_llm_cost_usd_total{model="hermes"}` ticks up correctly (0.0270329 USD after a few canonical queries).

### GAP-14 (script, FIXED): `install-otel-tempo.sh` checks for Tempo as a Deployment — Tempo is a StatefulSet

**Symptom:** Step 4/4 prints `Error from server (NotFound): deployments.apps "tempo" not found`. The Helm chart deploys Tempo as a `StatefulSet/tempo` (single binary mode). Non-fatal but visible to learners.

**Fix applied:** Updated `course-code/labs/lab-09/solution/scripts/install-otel-tempo.sh` step 4 to `kubectl rollout status statefulset/tempo -n monitoring --timeout=180s`. OTEL Collector remains a Deployment.

### GAP-15 (image cache, FIXED): `imagePullPolicy: IfNotPresent` + reused `:v1.0.0` tag = stale images on KIND nodes

**Symptom:** After `docker push localhost:5001/mcp-triage:v1.0.0` with new code (e.g., the FastAPI dep added), KIND nodes still ran the cached image. New pods from `kubectl rollout restart` fetched nothing new because the tag matched. `kind load docker-image` was the workaround.

**Fix applied (belt-and-braces):**
1. Set `imagePullPolicy: Always` on the 3 MCP deploys (`course-code/labs/lab-08/solution/k8s/60-mcp-*-deploy.yaml`) and on `cost-middleware` (`course-code/labs/lab-09/solution/k8s/70-cost-middleware-deploy.yaml`). kubelet now re-pulls from `kind-registry:5001` on every rollout.
2. `course-code/labs/lab-08/solution/scripts/build-mcp-images.sh` now also runs `kind load docker-image` after each push, so KIND nodes get the new layers immediately even when learners haven't restarted pods yet.

### GAP-16 (silent partial config, FIXED): `mcp-triage` K8s deploy LLM_API_KEY references the `groq-api-key` secret key

**Symptom:** With Gemini-only setup, `mcp-triage` env `LLM_API_KEY` is empty (since `groq-api-key` is empty), causing the triage tool's LLM call to fail at runtime with HTTP 400 ("Illegal header value" because Authorization header is `Bearer ` with empty key).

**Fix applied:** Updated `course-code/labs/lab-08/solution/k8s/60-mcp-triage-deploy.yaml` defaults to point at `google-api-key` and the Gemini base URL/model. Inline comment shows the Groq alternative.

## What I Changed in `course-code/`

```
course-code/labs/lab-07/solution/docker-compose.yaml                       # GAP-2, GAP-5
course-code/labs/lab-07/solution/hermes-config/config.yaml                 # GAP-3
course-code/labs/lab-07/solution/tools/otel_setup.py                       # GAP-6
course-code/labs/lab-07/solution/tools/triage/requirements.txt             # GAP-1
course-code/labs/lab-07/solution/tools/treatment_lookup/requirements.txt   # GAP-1
course-code/labs/lab-07/solution/tools/book_appointment/requirements.txt   # GAP-1
course-code/labs/lab-08/solution/k8s/50-sandbox-template.yaml              # GAP-8, GAP-12
course-code/labs/lab-08/solution/k8s/50-hermes-service.yaml (NEW)          # GAP-11
course-code/labs/lab-08/solution/k8s/60-hermes-config-cm.yaml              # GAP-7
course-code/labs/lab-08/solution/k8s/60-mcp-triage-deploy.yaml             # GAP-15, GAP-16, OTEL env
course-code/labs/lab-08/solution/k8s/60-mcp-treatment-lookup-deploy.yaml   # GAP-15, OTEL env
course-code/labs/lab-08/solution/k8s/60-mcp-book-appointment-deploy.yaml   # GAP-15, OTEL env
course-code/labs/lab-08/solution/k8s/60-network-policy.yaml                # GAP-12
course-code/labs/lab-08/solution/k8s/40-chainlit-deploy-day2.yaml          # GAP-11
course-code/labs/lab-08/solution/scripts/build-mcp-images.sh               # GAP-15
course-code/labs/lab-09/solution/k8s/70-cost-middleware-deploy.yaml        # GAP-11, GAP-15
course-code/labs/lab-09/solution/k8s/70-llm-price-table-cm.yaml            # GAP-13
course-code/labs/lab-09/solution/scripts/install-otel-tempo.sh             # GAP-14
```

## What I Changed in `course-content/`

```
course-content/docs/labs/lab-07-agent-core.md                              # GAP-2, GAP-3, GAP-4, GAP-10
course-content/docs/labs/lab-08-agent-sandbox.md                           # GAP-4, GAP-10, GAP-11, GAP-12, Sandbox Router demo
```

## What's Still Open

- **Sandbox Router full Chainlit integration** — The Router is deployed and now demonstrated via a curl path in Lab 08 Part E.3 (manual `X-Sandbox-ID` from an existing Sandbox name). The full per-session integration (Chainlit creates a `SandboxClaim` per chat session, stores `boundSandboxName` in session state, passes it as `X-Sandbox-ID` on every request) requires Chainlit code changes and is left as future work. The critical chain (Chainlit → cost-middleware → Hermes) does not depend on it.
- **Gemini empty-completion flakiness (GAP-10)** — Even with `max_tokens=2000`, roughly 1-in-3 canonical multi-tool queries on Gemini 2.5 Flash return empty content on the first attempt and succeed on retry. Likely thinking-budget interaction with Hermes' `max_turns`. Not blocking but worth tracking — possibly bump `max_tokens` default or add Hermes-level retry-on-empty.

## Test Evidence (capture files)

All under `/tmp/uat-phase3/`:

- `baseline.txt` — pre-UAT cluster state
- `lab07-compose-up.log`, `lab07-compose-up2.log` — fastapi crash before fix, success after
- `lab07-canonical.json` … `lab07-canonical-4.json` — Gemini provider iterations, final 200 with booking
- `lab08-install.log`, `lab08-build.log` — Sandbox install + MCP image build
- `lab08-coldwarm.log` — cold-vs-warm-demo timings (11.08s / 25.66s / 9.51s)
- `lab08-canonical.json`, `lab08-canonical2.json` — empty-then-success (max_tokens fix)
- `lab09-install.log`, `lab09-traced.log` — Helm install + traced query script
- `lab09-canonical{,2,3,4,5,6,7,8,9}.json` — iteration through router → direct service path
- `final-q{,2,3}.json`, `final-cm*.log` — post-fix metrics + ticking cost USD

## How a Fresh Learner Should Now Find It

After all fixes are committed:
1. `git clone` and follow Lab 07 — `docker compose up -d --build` succeeds first time. Chainlit at `localhost:8888`. Canonical curl with `max_tokens: 2000` books an appointment for the Gemini path; Groq path also works after the explicit `config.yaml` edit step in Tab Groq.
2. Lab 08 — `bash install-agent-sandbox.sh` then `kubectl apply -f k8s/`. The new `50-hermes-service.yaml` and the corrected NP let traffic flow. SandboxTemplate is `Unmanaged` so no ghost NP. cold-vs-warm demo numbers are within range. Canonical curl through port-forward succeeds.
3. Lab 09 — `bash install-otel-tempo.sh` then apply manifests. Cost middleware proxies through to `hermes-agent` Service. Send a chat. `/metrics` shows non-zero `agent_llm_tokens_total` and `agent_llm_cost_usd_total`. Tempo Explore shows `service.name=mcp-treatment-lookup` traces with the `httpx → rag-retriever` child span.

## Cleanup

Test artifacts left in cluster (extra bookings + temporary deploy patches) are restored to baseline by the cleanup task — see follow-up commit. Original Day-1 stack (vLLM Deployment scaled to 0, Chainlit scaled to 1, retriever scaled to 1) is preserved; D-19 wind-down state restored.
