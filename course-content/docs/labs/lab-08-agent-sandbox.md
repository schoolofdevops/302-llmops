---
sidebar_position: 9
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 08: Agent Sandbox

**Day 2 | Duration: ~90 minutes**

Today we take the Lab-07 Docker Compose stack and promote it to Kubernetes the production way — using the **Kubernetes Agent Sandbox** project. Each Chainlit session gets its own pre-warmed Sandbox instance (per-session isolation), a `SandboxWarmPool` keeps two Hermes pods ready so cold starts are bounded, an egress `NetworkPolicy` documents the production isolation pattern, and the Sandbox Router provides a stable cluster-internal gateway. By the end you will run the same multi-step "severe tooth pain" demo from Lab 07, this time on KIND with measurable warm-pool benefits.

## Learning Objectives

- Install the Kubernetes Agent Sandbox v0.4.3 CRDs and controller on a KIND cluster
- Deploy the Hermes Agent as a `Sandbox` resource via a `SandboxTemplate` (with the Lab-07 MCP tools running as plain Deployments in the `llm-agent` namespace)
- Pre-warm 2 agent instances using `SandboxWarmPool` and observe the cold-vs-warm timing difference with real measured numbers
- Persist agent state to a `ConfigMap` via in-cluster RBAC (`book_appointment` writes to `bookings` in `llm-app`)
- Apply an egress `NetworkPolicy` as a documented production pattern (with the KIND/kindnet enforcement caveat)
- Reach the agent through a stable cluster-internal gateway from Chainlit (Sandbox Router service)

## Lab Files

Companion code: `course-code/labs/lab-08/`

Scripts (`solution/scripts/`):

- `verify-sandbox-router-image.sh` — probes whether the GCR-hosted Router image pulls without credentials; writes `/tmp/lab08-router-mode`
- `install-agent-sandbox.sh` — idempotent install of v0.4.3 CRDs + controller; creates `llm-agent` namespace
- `build-mcp-images.sh` — builds the 3 MCP tool Docker images from Lab-07 sources and pushes to `kind-registry:5001`
- `cold-vs-warm-demo.sh` — warm→drain→cold timing demo; requires a running WarmPool

K8s manifests (`solution/k8s/`):

| File | What it creates |
|------|-----------------|
| `00-namespace.yaml` | `llm-agent` namespace |
| `50-sandbox-template.yaml` | `SandboxTemplate/hermes-agent-template` |
| `50-sandbox-warmpool.yaml` | `SandboxWarmPool/hermes-agent-warmpool` (replicas=2) |
| `50-sandbox-router.yaml` | `Deployment/sandbox-router` + `Service/sandbox-router-svc` (gcr mode) |
| `60-bookings-cm.yaml` | `ConfigMap/bookings` in `llm-app` (empty `[]` seed) |
| `60-booking-rbac.yaml` | `ServiceAccount/mcp-booking-sa` + cross-namespace `Role`/`RoleBinding` |
| `60-mcp-triage-deploy.yaml` | `Deployment/mcp-triage` + `Service/mcp-triage` |
| `60-mcp-treatment-lookup-deploy.yaml` | `Deployment/mcp-treatment-lookup` + `Service/mcp-treatment-lookup` |
| `60-mcp-book-appointment-deploy.yaml` | `Deployment/mcp-book-appointment` with `mcp-booking-sa` |
| `60-hermes-config-cm.yaml` | `ConfigMap/hermes-config` — `config.yaml` + `SOUL.md` |
| `60-hermes-secret.yaml.example` | Template Secret for API keys (do not commit filled) |
| `60-network-policy.yaml` | `NetworkPolicy/hermes-agent-egress` (egress allow-list) |
| `40-chainlit-deploy-day2.yaml` | Day-2 Chainlit `Deployment` + `Service` (NodePort 30300) |

UI code: `solution/ui/` — `app.py`, `Dockerfile`, `requirements.txt`

## Prerequisites

- [ ] **Lab 07 complete** — you have the Hermes config, 3 MCP tool Dockerfiles, and Day-2 Chainlit code in `course-code/labs/lab-07/solution/`. Lab 08 reuses these without modification.
- [ ] **vLLM scaled to 0** — if you did not complete the "Wind Down Before Day 2" section at the end of Lab 06, do it now:
  ```bash
  kubectl scale deployment vllm-smollm2 --replicas=0 -n llm-serving
  ```
- [ ] **kind-registry running** — the default course KIND config starts a local registry at `localhost:5001`. Verify:
  ```bash
  curl -s http://localhost:5001/v2/ | python3 -m json.tool
  ```
- [ ] **API key** — same `GROQ_API_KEY` or `GOOGLE_API_KEY` you used in Lab 07. You will paste it into the Secret in Part C.
- [ ] **Free RAM headroom** — the WarmPool keeps 2 Hermes pods running (~1.5 GB each). Check before starting:
  ```bash
  kubectl top nodes
  ```
  Target: at least 4 GB available on the worker node.

---

## Part A: Install the Agent Sandbox CRDs

### What is Kubernetes Agent Sandbox?

`kubernetes-sigs/agent-sandbox` (alpha, v0.4.3) is a K8s project that provides first-class primitives for running agentic workloads: `Sandbox` (one agent instance), `SandboxTemplate` (the agent pod spec), `SandboxWarmPool` (keep N ready Sandboxes), and `SandboxClaim` (client-side claim of a pre-warmed instance). Think of it as a scheduler extension for stateful, short-lived agent processes — the same way KNative handles function instances, but purpose-built for agents.

### Step A1: Check whether the Sandbox Router image is pullable

The Sandbox Router image is hosted on Google Artifact Registry (`us-central1-docker.pkg.dev`). On some networks it pulls without credentials; the verify script tests this and writes the result to `/tmp/lab08-router-mode`. Run it first so Part D.5 knows which path to take:

```bash
bash course-code/labs/lab-08/solution/scripts/verify-sandbox-router-image.sh
```

Expected output (if pull succeeds — which it does on standard KIND clusters):

```
[1/2] Trying to pull Sandbox Router image: us-central1-docker.pkg.dev/...
[2/2] PULL SUCCEEDED — using GCR-hosted Router (Service-based gateway).

Result: Lab 08 will deploy 50-sandbox-router.yaml (Service path).
```

Check the result:

```bash
cat /tmp/lab08-router-mode
# Either: ROUTER_MODE=gcr   OR   ROUTER_MODE=port-forward
```

:::warning Sandbox Router image pullability
The Sandbox Router image is on `us-central1-docker.pkg.dev` (GCR). On most networks this pulls without GCP credentials; on corporate networks with egress filtering it may fail. The verify script writes `/tmp/lab08-router-mode` with either `ROUTER_MODE=gcr` or `ROUTER_MODE=port-forward`. Part D.5 of this lab branches on that file — follow the path it shows.
:::

### Step A2: Install CRDs and controller

```bash
bash course-code/labs/lab-08/solution/scripts/install-agent-sandbox.sh
```

The script runs five steps:
1. Applies `manifest.yaml` from the v0.4.3 release (core CRDs + controller Deployment in `agent-sandbox-system`)
2. Applies `extensions.yaml` (SandboxTemplate, SandboxWarmPool, SandboxClaim CRDs)
3. Waits for the controller Deployment to become Available (up to 180s)
4. Verifies all 4 CRDs are registered
5. Creates the `llm-agent` namespace via `00-namespace.yaml`

### Verify

```bash
# 4 CRDs registered:
kubectl get crd | grep x-k8s.io
# Expected: sandboxes, sandboxtemplates, sandboxwarmpools, sandboxclaims

# Controller pod Running:
kubectl get deploy -n agent-sandbox-system
# Expected: agent-sandbox-controller   1/1   READY

# llm-agent namespace exists:
kubectl get ns llm-agent
```

:::info gvisor on KIND
GKE production examples use `runtimeClassName: gvisor` in the SandboxTemplate for hardware-level process isolation. KIND does not support gvisor. Our `50-sandbox-template.yaml` omits it — process isolation still comes from K8s namespaces, RBAC, and NetworkPolicy (even if the NetworkPolicy isn't enforced by kindnet, as explained in Part D.6).
:::

---

## Part B: Build and push the MCP tool images

Lab 08 runs the three MCP tools as plain K8s Deployments. The images are built from the same Dockerfiles you used in Lab 07 and pushed to the local KIND registry:

```bash
bash course-code/labs/lab-08/solution/scripts/build-mcp-images.sh
```

Expected output:

```
Building localhost:5001/mcp-triage:v1.0.0 from tools/triage/Dockerfile ...
Building localhost:5001/mcp-treatment-lookup:v1.0.0 from tools/treatment_lookup/Dockerfile ...
Building localhost:5001/mcp-book-appointment:v1.0.0 from tools/book_appointment/Dockerfile ...

OK: 3 MCP tool images built + pushed:
  localhost:5001/mcp-triage:v1.0.0
  localhost:5001/mcp-treatment-lookup:v1.0.0
  localhost:5001/mcp-book-appointment:v1.0.0
```

Verify the images are in the registry:

```bash
docker images | grep mcp-
```

:::warning First build takes 3-5 minutes
The base Python image and pip dependencies are downloaded on the first build. Subsequent builds use the layer cache and finish in under 30 seconds.
:::

---

## Part C: Configure secrets

Hermes needs two secrets: one for its own API key (used by Chainlit to call the Router) and one for the LLM provider key (Groq or Gemini).

### C.1 Hermes API key for the agent pod

```bash
cp course-code/labs/lab-08/solution/k8s/60-hermes-secret.yaml.example /tmp/lab08-hermes-secret.yaml
```

Open `/tmp/lab08-hermes-secret.yaml` in a text editor. Fill in your real Groq or Google API key in the appropriate `stringData` field (leave the other as the placeholder). Then apply:

```bash
kubectl apply -f /tmp/lab08-hermes-secret.yaml
```

:::warning Do not commit your filled secret
`/tmp/lab08-hermes-secret.yaml` contains your real API key. It lives in `/tmp` to prevent accidental commits. The example file (`60-hermes-secret.yaml.example`) in the repo uses placeholder strings — keep it that way.
:::

### C.2 Chainlit-side API key

Chainlit uses a separate Secret in the `llm-app` namespace to authenticate calls to the Sandbox Router:

```bash
kubectl -n llm-app create secret generic hermes-api-secret-chainlit \
  --from-literal=api-key=smile-dental-course-key
```

---

## Part D: Apply the K8s manifests

Apply in numbered order — namespaces → ConfigMaps + RBAC + tool Deployments → SandboxTemplate + WarmPool → Router (conditional) → NetworkPolicy. The numbering (50-*, 60-*) matches the load order.

### D.1 — Bookings ConfigMap and RBAC

The `bookings` ConfigMap (in `llm-app`) is the persistent store for the `book_appointment` MCP tool on K8s. The RBAC (`60-booking-rbac.yaml`) creates `ServiceAccount/mcp-booking-sa` in `llm-agent`, a `Role/configmap-booking-editor` in `llm-app`, and a cross-namespace `RoleBinding` that lets the SA patch the `bookings` ConfigMap. The cross-namespace `RoleBinding` (subject in `llm-agent`, Role in `llm-app`) is the standard K8s pattern for this topology.

```bash
kubectl apply -f course-code/labs/lab-08/solution/k8s/60-bookings-cm.yaml
kubectl apply -f course-code/labs/lab-08/solution/k8s/60-booking-rbac.yaml
```

### D.2 — Hermes config ConfigMap

`60-hermes-config-cm.yaml` bundles `config.yaml` and `SOUL.md` into a single ConfigMap that the SandboxTemplate mounts:

Key `config.yaml` lines (from the ConfigMap):

```yaml
model:
  default: groq/llama-3.3-70b-versatile

mcp_servers:
  triage:
    url: "http://mcp-triage.llm-agent.svc.cluster.local:8010/mcp"
  treatment_lookup:
    url: "http://mcp-treatment-lookup.llm-agent.svc.cluster.local:8020/mcp"
  book_appointment:
    url: "http://mcp-book-appointment.llm-agent.svc.cluster.local:8030/mcp"
```

Notice the URLs now use full cluster-local DNS names (`svc.cluster.local`) instead of Docker service names. The `/mcp` suffix is required — see Common Pitfalls.

```bash
kubectl apply -f course-code/labs/lab-08/solution/k8s/60-hermes-config-cm.yaml
```

### D.3 — MCP tool Deployments

Each MCP tool runs as a standalone Deployment + Service in `llm-agent`, using the images pushed in Part B. The pattern for all three is the same — `image: localhost:5001/mcp-<tool>:v1.0.0`, a `PORT` env, and an LLM API key from the `llm-api-keys` Secret.

The `mcp-book-appointment` Deployment is special: it sets `serviceAccountName: mcp-booking-sa` (enables the ConfigMap RBAC) and `BOOKING_BACKEND=configmap` (switches from local JSON file to K8s ConfigMap backend).

```bash
kubectl apply -f course-code/labs/lab-08/solution/k8s/60-mcp-triage-deploy.yaml
kubectl apply -f course-code/labs/lab-08/solution/k8s/60-mcp-treatment-lookup-deploy.yaml
kubectl apply -f course-code/labs/lab-08/solution/k8s/60-mcp-book-appointment-deploy.yaml
kubectl get pods -n llm-agent -l 'app in (mcp-triage,mcp-treatment-lookup,mcp-book-appointment)'
```

Expected: 3 pods `1/1 Running` within ~30 seconds.

### D.4 — SandboxTemplate and SandboxWarmPool

`SandboxTemplate` describes the agent pod spec — image, env, volumes, probes, resources. `SandboxWarmPool` tells the controller "keep 2 pre-warmed instances of this template ready at all times."

Key SandboxTemplate fields from `50-sandbox-template.yaml`:

```yaml
spec:
  podTemplate:
    spec:
      automountServiceAccountToken: false   # Hermes pods don't need K8s API access
      dnsPolicy: "None"
      dnsConfig:
        nameservers:
        - "10.96.0.10"    # CoreDNS ClusterIP — REQUIRED (see Why below)
      initContainers:
      - name: config-init
        image: busybox:1.36
        command: ["sh", "-c", "cp /configmap/config.yaml /hermes-home/config.yaml && cp /configmap/SOUL.md /hermes-home/SOUL.md"]
      containers:
      - name: hermes
        image: nousresearch/hermes-agent:latest
        command: ["/opt/hermes/docker/entrypoint.sh", "gateway"]
        env:
        - name: API_SERVER_HOST
          value: "0.0.0.0"   # REQUIRED — binds to all interfaces, not just 127.0.0.1
      volumes:
      - name: hermes-config-cm
        configMap:
          name: hermes-config
      - name: hermes-home
        emptyDir: {}         # REQUIRED — hermes writes to HERMES_HOME at startup
```

Two non-obvious settings:
- **`dnsPolicy: None` + CoreDNS nameserver** — the `hermes-agent` entrypoint overwrites `/etc/resolv.conf` with `8.8.8.8/1.1.1.1` at startup, which breaks in-cluster DNS for MCP service names. The explicit nameserver forces Hermes to use CoreDNS (`10.96.0.10` is the kubeadm default for KIND).
- **`emptyDir` for `hermes-home`** — Hermes writes lock files and config at startup. A ConfigMap mount is read-only (`EROFS`), so we copy ConfigMap files into a writable `emptyDir` via the `config-init` initContainer.

The WarmPool spec from `50-sandbox-warmpool.yaml` is simple:

```yaml
apiVersion: extensions.agents.x-k8s.io/v1alpha1
kind: SandboxWarmPool
metadata:
  name: hermes-agent-warmpool
  namespace: llm-agent
spec:
  replicas: 2
  sandboxTemplateRef:
    name: hermes-agent-template
```

Apply both:

```bash
kubectl apply -f course-code/labs/lab-08/solution/k8s/50-sandbox-template.yaml
kubectl apply -f course-code/labs/lab-08/solution/k8s/50-sandbox-warmpool.yaml
kubectl wait --for=jsonpath='{.status.readyReplicas}'=2 \
  sandboxwarmpool/hermes-agent-warmpool -n llm-agent --timeout=300s
kubectl get pods -n llm-agent -l app=hermes-agent
```

Expected: 2 hermes-agent pods `1/1 Running`.

:::warning First Hermes pull is ~2.4 GB
`nousresearch/hermes-agent:latest` is a large image. The `--timeout=300s` wait accounts for the first pull on a slow network. Subsequent restarts use the Docker layer cache and complete in under 30 seconds. If you already pulled the image in Lab 07 (Docker Compose mode), it will be in the local cache and the wait will be short.
:::

### D.5 — Sandbox Router (or port-forward fallback)

Check the mode the verify script chose:

```bash
cat /tmp/lab08-router-mode
```

<Tabs groupId="router-mode">
<TabItem value="gcr" label="ROUTER_MODE=gcr (most users)">

Apply the Router Deployment + Service:

```bash
kubectl apply -f course-code/labs/lab-08/solution/k8s/50-sandbox-router.yaml
kubectl rollout status deployment/sandbox-router -n llm-agent
kubectl get svc sandbox-router-svc -n llm-agent
```

Expected: `sandbox-router-svc` ClusterIP on port 8080. Chainlit will reach the Sandbox via `http://sandbox-router-svc.llm-agent.svc.cluster.local:8080`.

</TabItem>
<TabItem value="port-forward" label="ROUTER_MODE=port-forward (GCR blocked)">

Skip the Router manifest. Instead, port-forward directly to a WarmPool pod's API port for testing:

```bash
POD=$(kubectl get pod -n llm-agent -l app=hermes-agent -o jsonpath='{.items[0].metadata.name}')
kubectl -n llm-agent port-forward "pod/${POD}" 18642:8642
```

Leave this terminal open. Use `http://localhost:18642` in place of the Router URL in subsequent steps. For the Chainlit integration, edit the `AGENT_URL` env in `40-chainlit-deploy-day2.yaml` to point at a NodePort or adjust accordingly.

</TabItem>
</Tabs>

:::info Why the Router IS the gateway
In Agent Sandbox v0.4.3, "Gateway" (D-08) is implemented as the **Sandbox Router** Service — not a Kubernetes Gateway-API resource. The Router receives requests from Chainlit, selects an available pre-warmed Sandbox pod (via the `X-Sandbox-ID` header for per-session routing), and forwards traffic to it. This is the stable cluster-internal ingress point for the agent. The Router image is `us-central1-docker.pkg.dev/k8s-staging-images/agent-sandbox/sandbox-router:latest-main`.
:::

### D.6 — NetworkPolicy

The NetworkPolicy documents the egress allow-list for Hermes agent pods: DNS (UDP+TCP 53), the RAG retriever in `llm-app`, the 3 MCP tools in `llm-agent`, and HTTPS port 443 to any IP (for Groq and Gemini APIs).

The full policy is at `course-code/labs/lab-08/solution/k8s/60-network-policy.yaml`. It allows egress to: DNS (UDP+TCP 53), the RAG retriever in `llm-app` on port 8001, HTTPS 443 to any IP (for Groq/Gemini), and the 3 MCP tool ports (8010/8020/8030) in `llm-agent`.

Apply:

```bash
kubectl apply -f course-code/labs/lab-08/solution/k8s/60-network-policy.yaml
```

:::warning NetworkPolicy IS enforced on KIND v1.34+
Recent kindnet versions (shipped with KIND v1.34+) implement NetworkPolicy enforcement. The policy object is no longer pedagogical-only — egress and ingress are filtered. The course manifest lists exactly the upstreams Hermes legitimately needs (DNS, retriever, MCP tools, HTTPS for LLM APIs, OTEL Collector) and exposes ingress to the Sandbox Router and the Lab 09 cost-middleware. If you add new callers later, append them to the `from:` list under `ingress:`.
:::

---

## Part E: Switch Chainlit to the Sandbox

Day-2 Chainlit (`solution/ui/app.py`) replaces the direct vLLM call path with a single call to the Sandbox Router (or port-forwarded Sandbox pod). The UI is unchanged — the same `cl.Step` + tool sub-steps from Lab 07 render the agent's tool calls.

### E.1 Build and push the Day-2 Chainlit image

```bash
docker build \
  -t localhost:5001/smile-dental-ui-day2:v1.0.0 \
  course-code/labs/lab-08/solution/ui/
docker push localhost:5001/smile-dental-ui-day2:v1.0.0
```

### E.2 Deploy to Kubernetes

```bash
kubectl apply -f course-code/labs/lab-08/solution/k8s/40-chainlit-deploy-day2.yaml
kubectl rollout status deployment/chainlit-ui -n llm-app
```

The Deployment sets `AGENT_URL=http://hermes-agent.llm-agent.svc.cluster.local:8642` — pointing Chainlit at the **stable hermes-agent Service** (created by `50-hermes-service.yaml`), which load-balances across the 2 WarmPool pods. This path does not require per-session Sandbox claim handling.

:::info Why not route Chainlit through the Sandbox Router?
The Sandbox Router demands an `X-Sandbox-ID` header on every request. To use the Router from Chainlit, the UI would need to claim a Sandbox via a `SandboxClaim` CRD on session-start and inject the returned ID into every `/v1/chat/completions` call. The shipped Chainlit code does not yet do this — see "Per-session routing through the Router" below for a manual curl demo, and treat the full UI integration as future work. The stable Service path is functionally equivalent for the Day-2 lab demo and keeps the chain Chainlit → cost-middleware (Lab 09) → Hermes simple.
:::

### E.3 Per-session routing through the Router (manual demo)

The Sandbox Router is still deployed (`sandbox-router-svc:8080`) and works for any caller that supplies a valid `X-Sandbox-ID`. WarmPool sandboxes already exist as `Sandbox` resources whose `metadata.name` IS the routing ID:

```bash
kubectl -n llm-agent port-forward svc/sandbox-router-svc 8080:8080 &
SANDBOX_ID=$(kubectl get sandbox -n llm-agent -o jsonpath='{.items[0].metadata.name}')
curl -s -X POST http://localhost:8080/v1/chat/completions \
  -H "Authorization: Bearer smile-dental-course-key" \
  -H "Content-Type: application/json" \
  -H "X-Sandbox-ID: ${SANDBOX_ID}" \
  -d '{"model":"hermes","messages":[{"role":"user","content":"What is your job?"}],"stream":false,"max_tokens":300}' \
  | python3 -m json.tool
```

The `X-Sandbox-ID` header tells the Router which pre-warmed Sandbox pod to forward to. In a full per-session UI you would call `kubectl create -f` a `SandboxClaim` resource per Chainlit session, watch its status for `boundSandboxName`, and pass that as the header for every subsequent request from the session.

---

## Part F: Run the multi-step demo

Open the Chainlit UI at `http://localhost:30300` (NodePort unchanged from Lab 06/07).

Type: **severe tooth pain since yesterday**

You will see the Agent processing step expand with three Tool sub-steps: `mcp_triage_triage`, `mcp_treatment_lookup_treatment_lookup`, `mcp_book_appointment_book_appointment`.

Verify the booking was persisted to the ConfigMap:

```bash
kubectl get cm bookings -n llm-app -o jsonpath='{.data.bookings}' | python3 -m json.tool
```

Expected: a JSON array with at least one element. Appointment ID format: `SD-YYYYMMDDHHMMSS`.

For the curl-only path (port-forward mode or direct verification):

```bash
curl -s -X POST http://localhost:18642/v1/chat/completions \
  -H "Authorization: Bearer smile-dental-course-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "hermes",
    "messages": [{"role": "user", "content": "severe tooth pain since yesterday, my name is Carol, please book me in"}],
    "stream": false,
    "max_tokens": 2000
  }' | python3 -m json.tool
```

Hermes hides per-step `tool_calls` from the response — verify tool execution by checking the bookings ConfigMap above. If you used Gemini, the explicit `"max_tokens": 2000` is required so the thinking model has room to both reason and produce tool calls plus a final answer.

---

## Part G: Cold-vs-warm timing demo

### Concept

`SandboxWarmPool` keeps 2 Hermes pods pre-warmed so a new session's first request goes straight to an already-running pod (warm path). When the pool is drained and then refilled, Kubernetes schedules fresh pods — image pull + Hermes startup overhead is the cold cost. The key insight: **the cold start cost is borne during WarmPool refill, not during the user request**. Once the pool is ready, requests are fast regardless of how long the refill took.

### Run the demo

```bash
bash course-code/labs/lab-08/solution/scripts/cold-vs-warm-demo.sh
```

### What to expect

Observed timings from a live KIND cluster run (2026-05-02):

```
[1/4] Warm test — WarmPool replicas=2
  Warm: HTTP 200 in 7.95s
[2/4] Scaling WarmPool to 0 (cold setup)...
[3/4] Scaling WarmPool back to 2 (cold timing)...
  Cold WarmPool refill (0 -> 2 ready): 25.03s
  Cold: HTTP 200 in 2.54s
[4/4] Done. Compare the Warm vs Cold timings above.
Expected: Warm ~= 1-3s (LLM API latency only); Cold ~= 30-90s (image cached + hermes startup).
```

**Reading the numbers:**

- **Warm (7.95s):** The request goes directly to a pre-warmed Hermes pod. The time is pure LLM API round-trip (Groq/Gemini latency + agent reasoning). Slightly above the 1-3s ideal because the agent makes 3 LLM calls for a full triage→lookup→book workflow.
- **Cold refill (25.03s):** Time for 2 fresh pods to reach `readyReplicas=2`. In this run the Hermes image was already cached from Lab-07 pulls — only Hermes startup overhead (~12s each). On a fresh image pull this would be 180-300s.
- **First Cold request (2.54s):** The WarmPool was already at `readyReplicas=2` before the request was sent (the script waits for readiness). So the "cold" request is actually warm from the user's perspective — it hits a pre-warmed pod. The cost was paid during the refill, not the request.

:::tip Visualising events
```bash
kubectl describe sandboxwarmpool hermes-agent-warmpool -n llm-agent | grep -A5 Events
```
This shows the `ScheduleAttempt → PodCreated → PodReady` transitions, where you can observe the cold-start cost broken down by phase.
:::

---

## Verification

Run these checks to confirm everything is working end-to-end:

```bash
# 1. WarmPool has 2 ready replicas
kubectl get sandboxwarmpool/hermes-agent-warmpool -n llm-agent \
  -o jsonpath='{.status.readyReplicas}'
# Expected: 2

# 2. All pods Running
kubectl get pods -n llm-agent
# Expected: 2 hermes-agent + 3 mcp-* + 1 sandbox-router (gcr mode) — all 1/1 Running

# 3. Bookings ConfigMap has at least 1 entry
kubectl get cm bookings -n llm-app -o jsonpath='{.data.bookings}' \
  | python3 -c "import json, sys; data=json.load(sys.stdin); assert len(data)>=1, f'Expected >=1 booking, got {len(data)}'; print(f'OK: {len(data)} booking(s) — {data[0][\"appointment_id\"]}')"
# Expected: OK: 1 booking(s) — SD-YYYYMMDDHHMMSS

# 4. Canonical query calls all 3 tools (port-forward to first hermes pod)
POD=$(kubectl get pod -n llm-agent -l app=hermes-agent -o jsonpath='{.items[0].metadata.name}')
kubectl -n llm-agent port-forward "pod/${POD}" 18642:8642 &
sleep 5
curl -s -X POST http://localhost:18642/v1/chat/completions \
  -H "Authorization: Bearer smile-dental-course-key" \
  -H "Content-Type: application/json" \
  -d '{"model":"hermes","messages":[{"role":"user","content":"severe tooth pain since yesterday"}],"stream":false}' \
  | python3 -m json.tool | grep '"name"'
# Expected: mcp_triage_triage, mcp_treatment_lookup_treatment_lookup, mcp_book_appointment_book_appointment
kill %1 2>/dev/null || true

# 5. Cold-vs-warm demo completed with both timings printed
# (run the script and confirm both "Warm: HTTP 200 in Xs" and "Cold WarmPool refill" lines appear)
```

---

## Common Pitfalls

:::warning kindnet does NOT enforce NetworkPolicy
KIND's default CNI (`kindnet`) does not implement the NetworkPolicy spec. The `60-network-policy.yaml` is applied as a production documentation artifact — it shows the correct egress allow-list pattern, but traffic is not actually filtered on KIND. Real enforcement requires Calico, Cilium, or another NetworkPolicy-capable CNI. If you later deploy to GKE Standard or any cluster with Calico, this same manifest will enforce real egress restrictions without modification.
:::

:::warning Sandbox Router image may fail to pull on restricted networks
If `verify-sandbox-router-image.sh` returned `ROUTER_MODE=port-forward`, the GCR-hosted Router image was blocked. In that case, skip `50-sandbox-router.yaml` and use `kubectl port-forward` to access individual Hermes pods directly (see Part D.5, port-forward tab). Direct pod access bypasses the Router's session-routing header logic but is sufficient for demo purposes.
:::

:::warning book_appointment returns 403 from the K8s API
If the booking confirmation shows an error or the bookings ConfigMap stays empty, the `mcp-booking-sa` ServiceAccount may not have the correct RBAC. Verify:
```bash
kubectl get rolebinding mcp-booking-binding -n llm-app -o yaml | grep serviceAccount
# Expected: name: mcp-booking-sa, namespace: llm-agent

kubectl get pod -n llm-agent -l app=mcp-book-appointment -o jsonpath='{.items[0].spec.serviceAccountName}'
# Expected: mcp-booking-sa
```
If missing, reapply `60-booking-rbac.yaml` and then `60-mcp-book-appointment-deploy.yaml`.
:::

:::warning DNS broken by missing NetworkPolicy UDP rule
If you modify the NetworkPolicy and remove the DNS egress rule (port 53 UDP+TCP), all MCP tool names become unresolvable and Hermes cannot connect to any tool. The `60-network-policy.yaml` already includes DNS egress — do not remove it. This is RESEARCH.md Pitfall 7: NetworkPolicy silently breaks DNS when the DNS egress rule is missing.
:::

:::tip First Hermes pull is slow — pre-pull on the KIND node
If you did not run Lab 07 on this machine, the `nousresearch/hermes-agent:latest` image (2.4 GB) will be pulled from Docker Hub when the WarmPool starts. Pre-pull it on the KIND node before Part D.4 to avoid a 5+ minute wait:
```bash
docker pull nousresearch/hermes-agent:latest
kind load docker-image nousresearch/hermes-agent:latest --name llmops-cluster
```
Replace `llmops-cluster` with your KIND cluster name if different.
:::

---

## After This Lab

| Component | Resource | Namespace | Status |
|-----------|----------|-----------|--------|
| Agent Sandbox controller | `Deployment/agent-sandbox-controller` | `agent-sandbox-system` | Running |
| Hermes Agent | `SandboxWarmPool/hermes-agent-warmpool` (replicas=2) | `llm-agent` | 2 Sandboxes ready |
| MCP tools | `Deployment/mcp-triage`, `mcp-treatment-lookup`, `mcp-book-appointment` | `llm-agent` | Running |
| Sandbox Router | `Deployment/sandbox-router` (gcr mode) | `llm-agent` | Running |
| Bookings store | `ConfigMap/bookings` | `llm-app` | Persists across pod restarts |
| Chainlit (Day-2) | `Deployment/chainlit-ui` (NodePort 30300) | `llm-app` | Routes through Sandbox Router |
| Egress policy | `NetworkPolicy/hermes-agent-egress` | `llm-agent` | Applied (not enforced on KIND) |

The architecture is now: **Chainlit → Sandbox Router → pre-warmed Hermes pod → MCP tools (triage, treatment_lookup, book_appointment) → ConfigMap / RAG retriever / Groq-Gemini API**.

In Lab 09 we add an OpenTelemetry Collector + Grafana Tempo + a Prometheus cost-tracking middleware so the same agent stack becomes observable end-to-end: every tool call, every LLM round-trip, and every USD cent tracked by span.

---

## Tear Down (optional)

Scale the WarmPool to 0 first to avoid orphaned Sandbox CRs, then delete all manifests:

```bash
# Step 1: drain the WarmPool gracefully
kubectl patch sandboxwarmpool hermes-agent-warmpool -n llm-agent \
  --type merge -p '{"spec":{"replicas":0}}'
kubectl wait pod -n llm-agent -l agents.x-k8s.io/warm-pool-sandbox \
  --for=delete --timeout=120s 2>/dev/null || true

# Step 2: remove all Lab 08 manifests
kubectl delete -f course-code/labs/lab-08/solution/k8s/ --ignore-not-found

# Step 3: remove the filled secret (from /tmp, not the repo)
rm -f /tmp/lab08-hermes-secret.yaml /tmp/lab08-router-mode /tmp/lab08-router-pull.log

# Note: the Agent Sandbox controller and CRDs remain installed.
# To fully remove: kubectl delete -f https://github.com/kubernetes-sigs/agent-sandbox/releases/download/v0.4.3/extensions.yaml
#                  kubectl delete -f https://github.com/kubernetes-sigs/agent-sandbox/releases/download/v0.4.3/manifest.yaml
```
