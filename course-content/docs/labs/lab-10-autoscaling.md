---
sidebar_position: 11
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 10: Autoscaling

**Day 3 | Duration: ~45 minutes**

{/* Lab 10 — Autoscaling. Production-grade scaling for the LLM serving layer.
    Phase 4 D-01..D-05; satisfies SCALE-01 (HPA on RAG retriever as contrast),
    SCALE-02 (KEDA on vllm:num_requests_waiting), SCALE-03 (hey loadgen Job). */}

## Learning Objectives

By the end of this lab you will:

- Install KEDA 2.19 and metrics-server on your KIND cluster
- Add a KEDA `ScaledObject` that scales the vLLM Deployment based on `vllm:num_requests_waiting` (queue depth — the right signal for LLM serving)
- Add a `HorizontalPodAutoscaler` on the RAG retriever as a contrast moment (CPU-based HPA is the right tool for stateless web services, the wrong tool for vLLM)
- Run a load generator (`hey` as a Kubernetes Job) and observe live scale-up and cooldown events in Grafana
- Understand WHY queue depth beats CPU for autoscaling LLM workloads

## Prerequisites

- [ ] Lab 09 complete (Tempo + OTEL collector + Grafana dashboard live in `monitoring`)
- [ ] Docker Desktop set to at least 14 GB memory (16 GB preferred); KIND cluster `llmops-kind` healthy
- [ ] A free moment of patience — KEDA scale events take 15-60 seconds to react (configured `pollingInterval: 15`)

:::warning Resource budget (D-21)
Day 3 stacks several controllers on top of Day 1 and Day 2. If `kubectl top nodes` shows above 85% memory before starting, scale the agent SandboxWarmPool down to 1 replica first:

```bash
kubectl scale sandboxwarmpool hermes-agent-pool --replicas=1 -n llm-agent
```

You can scale it back to 2 after Day 3 if your laptop has headroom.
:::

## Lab Files

```text
course-code/labs/lab-10/solution/
├── scripts/
│   ├── 00-prereq-scale-vllm-up.sh       # First action — undoes Phase 3 vLLM wind-down
│   ├── install-keda.sh                   # helm install kedacore/keda 2.19.0
│   ├── install-metrics-server.sh         # kubectl apply + --kubelet-insecure-tls patch
│   ├── verify-prometheus-svc.sh          # Resolves the actual Prometheus Service name on your cluster
│   └── run-loadgen.sh                    # kubectl apply hey Job + tail replica count
└── k8s/
    ├── 80-keda-scaledobject-vllm.yaml         # ScaledObject on vllm:num_requests_waiting
    ├── 80-hpa-rag-retriever.yaml              # HPA on CPU (SCALE-01 contrast)
    ├── 81-loadgen-job-hey.yaml                # hey loadgen Job (SCALE-03)
    └── 82-grafana-dashboard-autoscaling-cm.yaml  # 4-panel Grafana dashboard, auto-discovered
```

---

## Part A — Bring vLLM back up (D-05)

At the end of Lab 06 we scaled the `vllm-smollm2` Deployment to `replicas=0` (Phase 3 D-19/D-20) so Day 2 labs could run without carrying the extra memory load. Lab 10 needs vLLM running, so the first thing you do is reverse that wind-down.

```bash
cd course-code/labs/lab-10/solution
bash scripts/00-prereq-scale-vllm-up.sh
```

The script scales the Deployment back to 1 replica and waits up to 4 minutes for `kubectl rollout status` to confirm the pod is Ready. On this hardware the SmolLM2-135M model loads off the OCI image in 60-180 seconds on CPU, depending on whether the image is cached in the KIND node.

Confirm:
```bash
kubectl get deploy vllm-smollm2 -n llm-serving
# NAME           READY   UP-TO-DATE   AVAILABLE   AGE
# vllm-smollm2   1/1     1            1           ...
```

:::tip If vLLM is already running at replicas=1
If you ran the loadgen demo outside of Lab 10 order, vLLM may already be up. The script is idempotent — scaling from 1 to 1 is a no-op and `kubectl rollout status` exits immediately.
:::

---

## Part B — Install metrics-server and KEDA

Order matters: install metrics-server first. KEDA's own metrics-apiserver coexists with metrics-server, but installing them in the right order surfaces fewer transient errors.

### Step B1: Install metrics-server

```bash
bash scripts/install-metrics-server.sh
```

The script applies the upstream `kubernetes-sigs/metrics-server` manifest and then patches the Deployment to add `--kubelet-insecure-tls`. KIND uses self-signed kubelet certificates, so without this patch metrics-server cannot scrape node metrics.

Validate:
```bash
kubectl top nodes
# NAME                          CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
# llmops-kind-control-plane     274m         3%     1272Mi          12%
# llmops-kind-worker            119m         1%     625Mi           6%
# llmops-kind-worker2           241m         3%     2709Mi          27%
```

If `kubectl top nodes` returns "metrics not available yet", wait 30 seconds and try again — the first scrape takes about 15 seconds.

### Step B2: Install KEDA

```bash
bash scripts/install-keda.sh
```

:::note Slow GHCR pulls on some networks
KEDA images come from `ghcr.io/kedacore`. On networks with GHCR rate-limits, the Helm install may time out after 5 minutes even though the images are still pulling. The script handles this: if `helm install --wait` times out, use `kind load docker-image` to push the cached image directly into the KIND node, then re-run the script (it is idempotent via `helm status` guard).
:::

Confirm KEDA is running:
```bash
kubectl get pods -n keda
# keda-admission-webhooks-...          1/1   Running
# keda-operator-...                    1/1   Running
# keda-operator-metrics-apiserver-...  1/1   Running

kubectl get crd scaledobjects.keda.sh
# NAME                       CREATED AT
# scaledobjects.keda.sh      ...
```

---

## Part C — Resolve the Prometheus Service name

Before applying the ScaledObject, confirm the Prometheus Service name on your cluster. The kube-prometheus-stack Helm release in this course uses release name `kps`, which produces the conventional name `kps-kube-prometheus-stack-prometheus`. The script verifies this is correct on your cluster:

```bash
bash scripts/verify-prometheus-svc.sh
```

Expected output when the name matches:
```text
Expected Prometheus Service name: kps-kube-prometheus-stack-prometheus
Actual   Prometheus Service name: kps-kube-prometheus-stack-prometheus
OK — matches RESEARCH.md convention. ScaledObject can use the convention name verbatim.
```

{/* Live verified 2026-05-04: actual name on this cluster is kps-kube-prometheus-stack-prometheus.
    serverAddress = http://kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090 */}

If the actual name differs, the script exits with a non-zero code and prints the correct `serverAddress` to use. Update `k8s/80-keda-scaledobject-vllm.yaml` before continuing.

:::note kube-prometheus-stack label note
The verify script uses the label `app=kube-prometheus-stack-prometheus` (not `app.kubernetes.io/name=prometheus`). Chart version 83.4.2 uses the older non-namespaced label form. If you installed kube-prometheus-stack with a different version, run `kubectl get svc -n monitoring --show-labels` to find the correct label.
:::

---

## Part D — Apply the ScaledObject and the HPA

### The headline: KEDA ScaledObject on queue depth

```bash
kubectl apply -f k8s/80-keda-scaledobject-vllm.yaml
```

The manifest, annotated:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: vllm-smollm2
  namespace: llm-serving
spec:
  scaleTargetRef:
    name: vllm-smollm2          # The Deployment to scale (from lab-04)
  pollingInterval: 15           # KEDA queries Prometheus every 15 seconds
  cooldownPeriod: 300           # After triggers go quiet, wait 5 min before scaling down
  minReplicaCount: 1            # NEVER scale to 0 — vLLM cold start is 60-180s on CPU
  maxReplicaCount: 3            # Bound by the 12-16 GB Docker Desktop memory budget
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
      threshold: '1'             # Sustained 1+ requests waiting triggers a scale-up
      query: vllm:num_requests_waiting
```

:::tip Why queue depth, not CPU? (D-02)
vLLM keeps CPU pegged near 100% even when idle — background KV-cache management, tokenizer warm-up, and model scheduling all consume CPU continuously. HPA on CPU would either (a) add replicas immediately on startup because CPU is already high, or (b) thrash replicas as CPU oscillates for reasons unrelated to actual load.

The right saturation signal for an LLM serving engine is the **request queue**: when requests pile up faster than the engine can finish them, you need more replicas. `vllm:num_requests_waiting` measures exactly that — it is zero when vLLM is keeping up and non-zero when it is falling behind. KEDA's Prometheus scaler reads this metric directly.

This is the D-02 reasoning you carry forward into every LLM deployment you build.
:::

Wait 30 seconds then confirm KEDA accepted the ScaledObject:
```bash
kubectl get scaledobject vllm-smollm2 -n llm-serving
# NAME           SCALETARGETKIND      READY   ACTIVE   FALLBACK   PAUSED
# vllm-smollm2   apps/v1.Deployment   True    False    Unknown    False
```

`READY=True` means KEDA connected to Prometheus and the PromQL query parsed correctly. `ACTIVE=False` is correct right now — there is no load, so the trigger has not fired.

### The contrast: HPA on CPU for the RAG retriever (SCALE-01)

```bash
kubectl apply -f k8s/80-hpa-rag-retriever.yaml
```

After about 30 seconds, metrics-server has scraped the pod:
```bash
kubectl get hpa rag-retriever -n llm-app
# NAME            REFERENCE                  TARGETS    MINPODS   MAXPODS   REPLICAS
# rag-retriever   Deployment/rag-retriever   0%/60%     1         2         1
```

The `0%/60%` line is HPA reading the actual CPU usage from metrics-server. CPU-based HPA is the correct tool for the RAG retriever — it is a stateless FastAPI service with predictable CPU behavior under load. The contrast with the ScaledObject above is intentional: same cluster, different scaling primitives, different reasons.

If `TARGETS` shows `<unknown>/60%`, metrics-server has not scraped the pod yet. Wait another 30 seconds.

---

## Part E — Apply the autoscaling Grafana dashboard

```bash
kubectl apply -f k8s/82-grafana-dashboard-autoscaling-cm.yaml
```

The ConfigMap carries the label `grafana_dashboard: "1"` — the kube-prometheus-stack Grafana sidecar watches for ConfigMaps with this label across all namespaces and auto-loads any dashboard JSON it finds. Within 30 seconds the dashboard appears in Grafana under **"Smile Dental — Autoscaling (Lab 10)"**.

Open Grafana (NodePort 30500 from Lab 06):
```bash
open http://localhost:30500/d/smile-dental-autoscaling
```

You should see four panels:

| Panel | Metric | Datasource |
|-------|--------|------------|
| vLLM replicas (KEDA scale events) | `kube_deployment_status_replicas{deployment="vllm-smollm2"}` | Prometheus |
| vLLM queue depth (KEDA trigger) | `vllm:num_requests_waiting` + `vllm:num_requests_running` | Prometheus |
| RAG retriever CPU | `container_cpu_usage_seconds_total` for rag-retriever pods | Prometheus |
| RAG retriever replicas | `kube_deployment_status_replicas{deployment="rag-retriever"}` | Prometheus |

Right now everything is flat — that is correct. You will populate the panels in Part F.

:::info Grafana admin credentials
```bash
kubectl -n monitoring get secret kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d && echo
```
Username is `admin`. The password is cluster-generated.
:::

---

## Part F — Run the loadgen and watch KEDA react (D-04 demo win)

Open Grafana split-screen alongside your terminal. The split-screen view — watching replica count climb in real time as `hey` fires requests — is the demo moment for this lab.

```bash
bash scripts/run-loadgen.sh
```

The script applies a `Job` that runs `williamyeh/hey:latest` for **180 seconds** at **8 RPS** (4 concurrent workers × 2 RPS each), POSTing to vLLM:

```json
{"model":"smollm2-135m-finetuned","prompt":"What treatments does Smile Dental offer?","max_tokens":32}
```

:::warning Pitfall — model name must match exactly
The `model` field MUST be `smollm2-135m-finetuned`. This is the value of `--served-model-name` set in `course-code/labs/lab-04/solution/k8s/30-deploy-vllm.yaml`. Using `smollm2` (without the suffix) returns HTTP 404. The Job manifest already has the correct value.
:::

While the loadgen runs, the script tails the replica count and ScaledObject Active status every 15 seconds. Watch the Grafana panels as the sequence unfolds:

1. **Queue depth climbs** as `hey` sends requests faster than vLLM can complete them (SmolLM2-135M on CPU handles about 1-2 RPS)
2. **KEDA polls Prometheus** every 15 seconds — the `vllm:num_requests_waiting` query crosses threshold 1
3. **KEDA sets ScaledObject Active=True** and creates a second (and in this case third) vLLM pod
4. **The new pods take 60-180 seconds** to load the model and become Ready
5. **Once replicas are serving**, the queue depth drops back toward zero
6. **After loadgen ends**, queue depth stays at 0 — KEDA waits out the 5-minute cooldown
7. **KEDA scales back to 1 replica** after `cooldownPeriod` expires

### What we observed live (04-02 verification, 2026-05-04)

| Observation | Value |
|-------------|-------|
| Loadgen parameters | `-z 180s -c 4 -q 2` (180 seconds, 4 workers, 2 RPS each = 8 RPS sustained) |
| Peak replica count | **3 replicas** (direct 1→3 jump — queue saturated immediately at 8 RPS with a single CPU pod and `max-num-seqs=1`) |
| Time from loadgen start to KEDA Active | **~46 seconds** |
| Scale-down cooldown | **300 seconds** after queue depth returned to 0 |
| ScaledObject state during loadgen | `ACTIVE=True`, `READY=True` |

The 1→3 jump (bypassing 2) is expected behavior: with `max-num-seqs=1` (the vLLM configuration for this demo) and 8 RPS hitting a single CPU pod, the queue depth immediately saturates and KEDA drives replicas directly to `maxReplicaCount=3`.

### kubectl events for the scale action

```bash
kubectl get events -n llm-serving \
  --field-selector involvedObject.name=vllm-smollm2 \
  --sort-by=.lastTimestamp | tail -10
# Normal  ScaledObjectReady  ScaledObject is ready for scaling
# Normal  ScalingReplicaSet  Scaled up replica set vllm-smollm2 from 1 to 3
```

---

## Part G — Inspect the managed HPA and ScaledObject state

KEDA creates a managed HPA under the hood (named `keda-hpa-vllm-smollm2`). You applied a `ScaledObject` — the higher-level KEDA resource — and KEDA translated it into a standard Kubernetes HPA for you. You can inspect both:

```bash
# The KEDA-managed HPA (DO NOT edit this directly — KEDA owns it):
kubectl get hpa keda-hpa-vllm-smollm2 -n llm-serving
# NAME                    REFERENCE             TARGETS     MINPODS   MAXPODS   REPLICAS
# keda-hpa-vllm-smollm2   Deployment/vllm-smollm2   0/1 (avg)   1         3         3

# ScaledObject conditions and last active time:
kubectl describe scaledobject vllm-smollm2 -n llm-serving | tail -20
# Look for:
#   Conditions:
#     Active:  True/False (True during loadgen, False after cooldown)
#     Ready:   True
#   Last Active Time: <timestamp of last scale event>
```

### The contrast at rest

At this point in the lab, the RAG retriever HPA has not scaled because the loadgen only hit the vLLM endpoint. The retriever's CPU stayed near 0%. That is the point:

```bash
kubectl get hpa rag-retriever -n llm-app
# NAME            REFERENCE                  TARGETS   MINPODS   MAXPODS   REPLICAS
# rag-retriever   Deployment/rag-retriever   0%/60%    1         2         1
```

CPU-based HPA is the right primitive for the retriever — it just has nothing to scale right now because retriever traffic is zero. If you want to see the retriever HPA fire, you can drive it directly:

```bash
# Optional: drive the RAG retriever directly (not part of graded walkthrough)
kubectl run retriever-load --image=williamyeh/hey:latest --restart=Never -n llm-app -- \
  -z 60s -c 4 -m POST \
  -H "Content-Type: application/json" \
  -d '{"query":"what treatments does Smile Dental offer","top_k":3}' \
  http://rag-retriever.llm-app.svc.cluster.local:8001/search
```

---

## Common Pitfalls

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| `ScaledObject READY=False`, KEDA logs show "connection refused" or "i/o timeout" | Wrong Prometheus Service name in `serverAddress` | Re-run `scripts/verify-prometheus-svc.sh`, update `serverAddress` in `80-keda-scaledobject-vllm.yaml`, then `kubectl apply` again |
| `hey` Job pod returns HTTP 404 on all requests | Model name in JSON body is wrong — must be `smollm2-135m-finetuned`, not `smollm2` | The Job manifest already has the correct name; if you edited it, revert and re-apply `81-loadgen-job-hey.yaml` |
| `kubectl top nodes` returns "metrics not available" indefinitely | metrics-server did not receive the `--kubelet-insecure-tls` patch | Re-run `scripts/install-metrics-server.sh` (idempotent), or manually: `kubectl edit deploy metrics-server -n kube-system` and add the flag to the container args |
| KEDA scales up to `maxReplicaCount: 3` and one pod stays `Pending` forever | Docker Desktop hit the memory ceiling — the third vLLM pod cannot be scheduled | Either reduce `maxReplicaCount` to `2` in `80-keda-scaledobject-vllm.yaml` and re-apply, OR increase Docker Desktop memory allocation |
| Grafana dashboard never appears under "Smile Dental — Autoscaling" | ConfigMap label `grafana_dashboard` is wrong value or type | Run: `kubectl get cm grafana-autoscaling-dashboard -n monitoring -o yaml` — confirm label is string `"1"` not integer `1`; reapply `82-grafana-dashboard-autoscaling-cm.yaml` if incorrect |
| `ScaledObject READY=False` with "parsing prometheus metadata: query is required" | YAML indentation error in the `triggers[0].metadata` block | Re-apply from disk — `kubectl apply -f k8s/80-keda-scaledobject-vllm.yaml` — verify indentation matches the repo file exactly |

---

## Summary

You now have:

- **KEDA 2.19** installed in the `keda` namespace
- **metrics-server** installed in `kube-system` with the KIND-specific `--kubelet-insecure-tls` patch
- A **ScaledObject** driving vLLM replicas based on the Prometheus metric `vllm:num_requests_waiting` — the saturation signal that actually predicts the need for more LLM serving capacity
- An **HPA on the RAG retriever** as a contrast moment — CPU-based HPA is the right tool for stateless FastAPI services; it is the wrong tool for vLLM
- A **Grafana dashboard** showing scale events live, auto-discovered from a labeled ConfigMap
- **Live proof**: 3 minutes of `hey` loadgen at 8 RPS drove KEDA to scale vLLM from 1 replica to 3 replicas in 46 seconds; the 5-minute cooldown brought it back to 1

The contrast (queue depth for LLMs vs CPU for stateless) is the key idea to take into every LLM-serving deployment you build from here on. Before reaching for HPA-on-CPU as the default, ask: what is my saturation signal?

---

## After This Lab

| Component | Namespace | State |
|-----------|-----------|-------|
| KEDA operator | `keda` | Running (3 pods) |
| metrics-server | `kube-system` | Running |
| ScaledObject `vllm-smollm2` | `llm-serving` | Ready=True, Active=False (idle) |
| HPA `rag-retriever` | `llm-app` | Targeting 60% CPU |
| Grafana autoscaling dashboard | `monitoring` | Auto-discovered |
| vLLM Deployment | `llm-serving` | Back at 1 replica (post-cooldown) |

---

## Next Step

Lab 11 introduces ArgoCD and reorganizes the imperatively-applied stack into an App-of-Apps GitOps tree. The KEDA ScaledObject and HPA you just applied stay imperative (they are "infrastructure of the infrastructure" — KEDA owns the managed HPA internally; onboarding the ScaledObject into ArgoCD would cause KEDA and ArgoCD to fight over replica count ownership). The workloads they target — vLLM, RAG retriever, Chainlit, and the agent Sandbox — get adopted under ArgoCD.

Continue to [Lab 11: GitOps with ArgoCD](./lab-11-gitops.md).
