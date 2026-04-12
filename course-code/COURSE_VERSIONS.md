# Course Versions

Tested combination for this course delivery.
All versions verified on macOS Apple Silicon and x86-64 Windows.

**Last verified:** 2026-04-12
**Workshop delivery:** v1.0

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
| vLLM | v0.19.0 | Official CPU image: schoolofdevops/vllm-cpu-nonuma:0.9.1; use this image tag |
| KServe | 0.14+ | RawDeployment mode for KIND (no Knative required); 0.14 adds stable ImageVolume support |
| kube-prometheus-stack | latest Helm chart | Pin chart version at workshop delivery time |

## Web UI & Agent

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| Chainlit | 2.11.0 | Requires `--host 0.0.0.0` for K8s NodePort access; 2.11 has stable WebSocket streaming |
| FastAPI | 0.x (latest) | Pydantic v2 compatible; use fastapi[standard] for uvicorn inclusion |

## Documentation Site

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| Docusaurus | 3.10.0 | npm latest as of 2026-04-12; MDX 3, dark/light toggle, versioning |
| Node.js | 22.x LTS | For Docusaurus build only; 18+ required by Docusaurus 3 |

## Notes

- vLLM CPU image: use `schoolofdevops/vllm-cpu-nonuma:0.9.1` — the official `vllm/vllm-openai-cpu` variant requires NUMA-capable hardware
- KIND node image: always pin to `v1.34.0` — `latest` is not a valid KIND image tag
- For Hermes Agent (Lab 07): requires free-tier API key for Gemini (https://aistudio.google.com) or Groq (https://console.groq.com)
