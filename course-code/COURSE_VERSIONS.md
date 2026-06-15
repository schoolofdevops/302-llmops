# Course Versions

Tested combination for this course delivery.
All versions verified on macOS Apple Silicon; Windows x86-64 verification follows the same Docker Desktop + KIND path documented per-lab.

**Last verified:** 2026-06-15 (v1.0.0 Phase 03)
**Workshop delivery:** v1.0.0

## Core Infrastructure

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| kindest/node | v1.34.0 | ImageVolume beta available; v1.33 requires manual gate enable; v1.35 not yet tested |
| KIND CLI | 0.27.0 | Supports kind config v1alpha4; tested on macOS Apple Silicon + x86 |
| kubectl | 1.34.x | Server version match; avoid skew beyond ±1 minor version |
| Helm | 3.x | 3.18+ preferred; any 3.x works |
| Docker Desktop | 4.x (engine 28+) | Set Resources > Memory >= 12GB for Labs 04-09 |

## ML / LLM Stack

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| Python | 3.11 | PEFT + PyTorch + Transformers tested on 3.11; 3.12 has edge cases with some PEFT versions |
| PyTorch | 2.4+ (CPU) | MKL included in x86_64 wheels; required for NumPy 2.x compatibility |
| Transformers | 4.50+ | Required by vLLM 0.19.0; SmolLM2-135M tokenizer compatibility |
| PEFT | 0.14+ | LoRA CPU training on SmolLM2-135M; 0.14 adds stable merge_and_unload |
| Sentence-Transformers | 3.x | all-MiniLM-L6-v2 embeddings; 22MB, 14.7ms/1K tokens on CPU |
| FAISS | faiss-cpu latest | In-process vector search; no version constraint beyond Python 3.11 compat |
| NumPy | 1.26.4 | Pin to avoid NumPy 2.x breaking changes with older scipy/faiss |
| HuggingFace SmolLM2-135M-Instruct | main | Base model for fine-tuning; 135M params, CPU-compatible |

## Serving & Deployment

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| vLLM | 0.9.1 | Custom CPU image: `schoolofdevops/vllm-cpu-nonuma:0.9.1` — stripped-down, no NUMA, CPU-only inference on mac/windows |
| KServe | N/A (Phase 2) | Not used in Day 1 labs; plain K8s Deployment used for vLLM serving (Phase 3+ only) |
| kube-prometheus-stack | 83.4.2 (Helm chart) | Reproducibility for workshop delivery; verified on KIND 1.34.0 |

## Object Storage (Phase 03+)

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| MinIO Helm chart (minio-official/minio) | 5.4.0 (app: RELEASE.2024-12-18T13-15-44Z) | Standalone mode confirmed; Deployment (not StatefulSet) with mode=standalone, replicas=1; multi-arch arm64+amd64 |
| MinIO client (mc) | quay.io/minio/mc:RELEASE.2024-11-21T17-21-54Z | Used in initContainer + model-uploader Job; 78 MB, multi-arch arm64+amd64 verified |

## Web UI

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| Chainlit | 2.11.0 | Requires `--host 0.0.0.0` for K8s NodePort access; 2.11 has stable WebSocket streaming |
| FastAPI | 0.x (latest) | Pydantic v2 compatible; use fastapi[standard] for uvicorn inclusion |

## Documentation Site

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| Docusaurus | 3.10.0 | npm latest as of 2026-04-12; MDX 3, dark/light toggle, versioning |
| Node.js | 22.x LTS | For Docusaurus build only; 18+ required by Docusaurus 3 |

## Production Ops + Capstone (Day 3)

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| KEDA (Helm chart `kedacore/keda`) | 2.19.0 | Latest stable as of 2026-05-03; supports Prometheus scaler; works with K8s 1.30+ (we run 1.34). Controller image v2.19.x. Footprint ~150 MB across operator + metrics-apiserver + admission-webhooks pods. |
| metrics-server | latest from `https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml` | Required for SCALE-01 HPA on CPU. Patch with `--kubelet-insecure-tls` for KIND. |
| ArgoCD (Helm chart `argo/argo-cd`) | 9.5.11 (deploys ArgoCD v3.3.9) | Latest stable as of 2026-05-01. Supports K8s 1.32-1.35. Default values overridden: `dex.enabled=false`, `notifications.enabled=false`, `applicationSet.enabled=false`, `server.service.type=NodePort`, `server.service.nodePortHttp=30700`, `configs.params."server\.insecure"=true`. |
| `argocd` CLI | matches server (3.3.x) | Optional; lab uses `kubectl apply -f` for Application CRs. |
| Argo Workflows (Helm chart `argo/argo-workflows`) | 1.0.13 (deploys Argo Workflows v4.0.5) | Latest stable as of 2026-04-23. v4 line is the default new-install track. Default values: `server.serviceType=NodePort`, `server.serviceNodePort=30800`, `server.authModes={server}`. |
| `argo` CLI | matches server (4.0.x) | Optional; lab uses `kubectl create -f` for Workflow CRs. |
| `williamyeh/hey:latest` (Docker Hub) | latest | scratch-based Go binary (rakyll/hey 0.1.4); image last updated ~7y but stable. Entrypoint `/hey`. Fallback: build from `https://github.com/rakyll/hey/blob/master/Dockerfile` and push to `kind-registry:5001/hey:v1.0.0`. |
| `alpine/git:latest` (Docker Hub) | latest | Used by Argo Workflows git-commit-step. Includes ssh-keyscan, git, openssh-client. |
| `python:3.11-slim` (Docker Hub) | latest | Base for data-gen, train, merge, package, eval Python steps. Already used in Phase 2. |

## Notes

- vLLM CPU image: `schoolofdevops/vllm-cpu-nonuma:0.9.1` — custom stripped-down image for CPU-only inference without GPU on mac/windows
- KIND node image: always pin to `v1.34.0` — `latest` is not a valid KIND image tag
- KEDA Prometheus trigger uses Service name `kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090`. Project Helm release name is `kps` (per Lab 05 ServiceMonitor `release: kps` selector); verify with `kubectl get svc -n monitoring -l app.kubernetes.io/name=prometheus -o name` before writing the ScaledObject.
- Day 3 (Phase 06) installs KEDA + metrics-server + ArgoCD + Argo Workflows on top of the Day 1 spine. Verify Docker Desktop allocation is at least 14 GB before starting Phase 06 — combined footprint is ~12-14 GB.
- ArgoCD default sync interval is 3 minutes; instructor can force with `argocd app sync <name>` for live demos. GitHub webhook setup requires public ingress and is OUT OF SCOPE for the workshop.
- Argo Workflows artifact passing on KIND uses a shared PVC at `/workspace` mounted into every DAG step — NO MinIO/S3.
- `kind load docker-image` is required for every new local-built image — KIND worker nodes cannot resolve `localhost:5001`.
- MinIO standalone install: `helm install minio minio-official/minio --namespace minio -f k8s/10-minio-values.yaml`. Must pass `mode=standalone` AND `replicas=1` to get a single-pod Deployment (not a 16-pod StatefulSet, chart v5.4.0 default).
