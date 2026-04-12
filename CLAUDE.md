<!-- GSD:project-start source:PROJECT.md -->
## Project

**LLMOps & AgentOps with Kubernetes**

A comprehensive, hands-on course that teaches how to productionize LLM applications and AI agents on Kubernetes. Students build a dental clinic assistant (Smile Dental) from scratch — starting with RAG and fine-tuning, evolving into a multi-tool agent, then deploying it with production-grade observability, autoscaling, GitOps, and Kubernetes Agent Sandbox. Designed for DevOps engineers, ML engineers, and full-stack developers. Delivered as both instructor-led 3-day workshops and a self-paced Udemy course.

**Core Value:** Teach practitioners how to take AI systems (LLMs + agents) from prototype to production on Kubernetes — the only course that covers the full journey from RAG to agentic deployments with K8s Agent Sandbox.

### Constraints

- **Duration**: ~24 hours of content fitting a 3-day workshop format (12-15 labs)
- **Hardware**: Must run on laptops with 16GB RAM, CPU-only (KIND clusters)
- **Platform**: Must work on both Windows AND macOS (Docker Desktop + KIND)
- **Code delivery**: Companion Git repo with starter/ and solution/ per module — no copy-paste walls
- **Site platform**: Docusaurus (replacing MkDocs)
- **Naming**: "Smile Dental" (not "Atharva") — globally accessible branding
- **Model size**: Small models (SmolLM2-135M or similar) that work on CPU for LLMOps labs
- **LLM API for agents**: Free-tier API access required (Google Gemini or Groq) — students must not need to pay
- **No heavy frameworks**: Avoid LangGraph/CrewAI — prefer native LLM tool-calling or lightweight approach
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- **Python** 3.11 - All code generation, training, serving, and utility scripts
- **YAML** - Kubernetes manifests and MkDocs configuration
- **Markdown** - Lab guides and documentation (11 guides covering labs 0-8)
- **Bash** - Deployment and orchestration scripts for KIND, Kubernetes jobs, and local setup
## Runtime
- **Kubernetes 1.34+** - Orchestration platform for LLM workloads
- **KIND (Kubernetes in Docker)** - Local multi-node cluster for development and labs
- **Docker** - Container runtime for all services and jobs
- **pip** - Python package management
- No lockfile detected (uses inline version pinning in requirements sections within Kubernetes manifests)
## Frameworks
- **FastAPI** 0.x - REST API framework for Chat API (`serving/chat_api.py`) and Retriever API (`rag/retriever.py`)
- **Pydantic** - Data validation for FastAPI models (BaseModel definitions in lab guides)
- **Transformers** - HuggingFace library for model loading and inference (SmolLM2-135M, sentence-transformers)
- **PEFT (Parameter-Efficient Fine-Tuning)** - LoRA adapter library for CPU-friendly fine-tuning (`training/train_lora.py`)
- **Sentence-Transformers** `2.7.0` - Embedding model `sentence-transformers/all-MiniLM-L6-v2` for semantic search
- **FAISS** - Vector search library for retrieval index (`rag/build_index.py`)
- **vLLM** `0.9.1` - High-performance LLM serving engine (CPU-optimized image: `schoolofdevops/vllm-cpu-nonuma:0.9.1`)
- **PyTorch** - Deep learning framework for training (CPU-only variant)
- **NumPy** `1.26.4` - Numerical computing
- **SciPy** `1.10.1` - Scientific computing (sparse matrix operations for TF-IDF)
- **scikit-learn** `1.3.2` - ML utilities including TF-IDF vectorization alternative to FAISS
- **joblib** `1.3.2` - Parallelization and persistence (TF-IDF index serialization)
- **Prometheus Client** - Metrics export from FastAPI services (`prometheus_client` library in lab05)
- **Prometheus** (kube-prometheus-stack via Helm) - Time-series metrics collection
- **Grafana** - Metrics visualization (deployed via `prometheus-community/kube-prometheus-stack` Helm chart)
- **MkDocs** `1.x` (implied by mkdocs.yml) - Static site generator for lab documentation
- **ReadTheDocs Theme** - MkDocs theme for documentation site
## Key Dependencies
- **HuggingFace SmolLM2-135M-Instruct** - Fine-tuned model base (135M parameters, CPU-compatible)
- **Sentence-Transformers all-MiniLM-L6-v2** - Embedding model for RAG retrieval (embedding dimension: determined by FAISS IndexFlatIP)
- **vLLM** `0.9.1` - LLM inference engine with OpenAI-compatible API and built-in metrics export
- **FAISS** - Production-grade vector similarity search
- **KServe** - Kubernetes-native model serving framework (`serving.kserve.io/v1beta1` InferenceService)
- **Knative Serving** (implicit via KServe) - Serverless container orchestration
- **KEDA** - Kubernetes Event-Driven Autoscaling (custom metrics from Prometheus)
- **HPA (Horizontal Pod Autoscaler)** - CPU-based and custom metric autoscaling
- **VPA (Vertical Pod Autoscaler)** - Resource request optimization recommendations
- **ArgoCD** - GitOps continuous delivery (`argoproj.io/argoproj-helm`)
- **Argo Workflows** - DAG-based workflow orchestration (alternative to Kubeflow)
- **httpx** - Async HTTP client for inter-service communication (Chat API → Retriever, vLLM calls)
## Configuration
- **Kubernetes ConfigMap** - Configuration mounted as environment variables (e.g., `INDEX_PATH`, `MODEL_NAME` in `rag/retriever.py`)
- **Kubernetes Secret** - For sensitive data (not detailed in public docs)
- **Helm Values** - Cluster-wide config for Prometheus, Grafana, ArgoCD, Argo Workflows
- **Dockerfile** - Containerization for training jobs (Lab 2: `training/Dockerfile`)
- **Dockerfile** - Containerization for RAG/Chat/inference services
- **.gitignore** - Git exclusions for artifacts, model checkpoints, cache (Lab 7: `k8s/70-gitops/`)
- **mkdocs.yml** - Site configuration (`site_name`, `nav`, `theme`, `repo_url`, `copyright`)
- `docs_dir: docs` - MkDocs source directory
- `theme: readthedocs` - ReadTheDocs theme for documentation
- `plugins: [search]` - Search plugin for documentation
- `google_analytics` - Analytics integration (placeholder in mkdocs.yml)
## Platform Requirements
- **macOS / Linux** - Tested on these platforms (shell scripts note compatibility)
- **≥16 GB RAM** - Minimum for KIND cluster + model workloads
- **Docker Desktop** - For KIND cluster creation
- **kubectl** - Kubernetes CLI (`1.34+` compatible)
- **Helm 3.x** - Package manager for Kubernetes charts (kube-prometheus-stack, argo, argocd)
- **Kubernetes 1.34+** - On-premises or cloud Kubernetes clusters
- **Image Registry** - Local (`kind-registry:5001`) for labs, private registry for production
- **Persistent Storage** (optional) - ImageVolumes for model mounting, or PVCs for artifacts
- **CPU-only Infrastructure** - All workloads optimized for CPU (no GPU required)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Project Overview
- **Markdown documentation**: 11 lab guides in `llmops-labuide/docs/`
- **Embedded Python code**: Practical examples embedded in markdown files
- **Kubernetes manifests**: YAML configurations for deployment
- **Shell scripts**: Bash helpers for automation
- **No dedicated source code**: Code examples are within .md files for copy-paste learning
## Naming Patterns
- Lowercase with underscores: `train_lora.py`, `build_index.py`, `prompt_utils.py`
- Descriptive names indicating purpose: `chat_api.py`, `retriever.py`, `merge_lora.py`
- Example files: `llmops-labuide/docs/lab02.md` (lines 50, 128), `lab01.md` (lines 212, 564, 750)
- Lowercase with underscores (snake_case): `build_example()`, `load_jsonl()`, `_normalize_hits()`
- Private/internal helpers prefixed with underscore: `_render_treatment_item()`, `_label()`, `_extract_text()`
- Example: `llmops-labuide/docs/lab01.md` (lines 200-281)
- Lowercase with underscores: `MAX_STEPS`, `BASE_MODEL`, `OUTPUT_ROOT`
- Configuration constants in ALL_CAPS: `LORA_R`, `BATCH_SIZE`, `GRAD_ACCUM`
- Example: `llmops-labuide/docs/lab02.md` (lines 160-172)
- PascalCase: `Collator()`, `ChatRequest()`, `SearchRequest()`
- Example: `llmops-labuide/docs/lab02.md` (lines 251-268), `lab04.md` (line 239)
- Upper case for constants: `BASE_DIR`, `DATA_DIR`, `OUTPUT_ROOT`, `INDEX_PATH`, `META_PATH`
- Used with `Path()` from `pathlib`: `BASE_DIR = Path("/mnt/project/atharva-dental-assistant")`
- Example: `llmops-labuide/docs/lab02.md` (lines 154-155), `lab01.md` (line 705)
## Code Style
- Standard library imports first: `import os, json, time`
- Third-party packages second: `from pathlib import Path`
- Type hints from `typing`: `from typing import List, Dict, Any, Optional, Tuple`
- Local/project imports last: `from common import read_md, normalize_ws`
- Example: `llmops-labuide/docs/lab01.md` (lines 567-573), `lab04.md` (lines 221-228)
- Comments with `# ----` separator lines for section markers
- Example: `llmops-labuide/docs/lab02.md` (lines 157-159, 235-237)
- Comments describe "why" and semantic sections, not obvious code
- Example: `llmops-labuide/docs/lab01.md` (lines 623-633)
- Used in function signatures for clarity in tutorial context
- Example: `def iter_docs(root: Path) -> Iterable[Tuple[str, Dict[str, Any]]]:`
- `list[dict]`, `List[str]` used interchangeably (some Python 3.11+ syntax)
- Example: `llmops-labuide/docs/lab01.md` (lines 625, 714-715)
- f-strings preferred for readability
- Example: `f"Base model: {BASE_MODEL}"` at `llmops-labuide/docs/lab02.md` (line 179)
- `argparse` for CLI tools
- Stores arguments as object attributes (e.g., `args.clinic`, `args.treatments`)
- Example: `llmops-labuide/docs/lab01.md` (lines 331-341)
- Accessed via `os.environ.get(key, default_value)`
- Used for configuration injection (e.g., `BASE_MODEL`, `VLLM_URL`)
- Example: `llmops-labuide/docs/lab02.md` (lines 160-172), `lab04.md` (lines 230-235)
## Error Handling
- Functions return error message strings on failure
- Example pattern from `llmops-labuide/docs/lab01.md` (lines 850-860):
- Check data existence before access
- Example from `llmops-labuide/docs/lab01.md` (lines 820-832):
- Used in merge scripts to verify prerequisite state
- Example from `llmops-labuide/docs/lab02.md` (line 353):
- Used for API responses with status codes
- Example pattern from `llmops-labuide/docs/lab01.md` (line 758):
## Validation and Data Processing
- Read with `encoding="utf-8", errors="ignore"` to skip invalid UTF-8
- Example: `llmops-labuide/docs/lab01.md` (lines 636-661)
- Near-duplicate detection: `SequenceMatcher(None, a.lower(), b.lower()).ratio() >= threshold`
- Use set to track seen items; filter duplicates
- Example from `llmops-labuide/docs/lab01.md` (lines 525-533):
- Regex for whitespace: `re.sub(r"\s+", " ", s).strip()`
- Strip bullets/numbers: Custom regex pattern `_BULLET_PREFIX = re.compile(r'^\s*(?:[-*•]+|\d+[.)])\s*', re.IGNORECASE)`
- Example: `llmops-labuide/docs/lab01.md` (lines 241-281)
## Comments and Documentation
- Complex regex patterns are commented
- Section dividers mark algorithm phases (e.g., "Deduplicate near-identical questions")
- Function docstrings explain non-obvious behavior or parameters
- Example docstring: `llmops-labuide/docs/lab01.md` (lines 798-810)
- Mark temporary workarounds: `# fixed missing ')'` at line 260
- Explain "why" when code is non-obvious
- Guard explanations for defensive coding: `# Guard against out-of-range`
- Comments explain resource decisions
- Example from `llmops-labuide/docs/lab04.md` (lines 64-115)
## Function Design
- Small, focused functions (50-100 lines typical)
- Example: `build_example()` at `llmops-labuide/docs/lab02.md` (lines 204-228) is 25 lines
- Longer functions (250+ lines) are rare and often marked with "demo edition" notes
- Functions accept `Path` objects from `pathlib`
- Optional parameters with clear defaults
- Example: `_render_markdown_snippet(text: str, max_lines: int = 8)`
- Config parameters passed via constructor or globals (e.g., `BACKEND`, `MAX_CTX_SNIPPETS`)
- Explicit types: `Iterable[Tuple[str, Dict]]`, `List[Dict[str, Any]]`, `Optional[str]`
- Generators preferred when iterating large datasets
- Dict returns with predictable keys
- Example: `iter_docs()` yields (text, meta_dict) tuples consistently
- `@dataclass` decorator for simple data containers
- Example: `Collator` class at `llmops-labuide/docs/lab02.md` (lines 251-268)
- Used for collate functions and data structures
## Module Design and Organization
- Not used; imports are direct from source files
- Example: `from prompt_utils import to_chat, simple_template`
- All functions/classes at module level are public
- Private internal functions use `_` prefix
- `if __name__ == "__main__":` guards main entry points
- Example: `llmops-labuide/docs/lab01.md` (line 556)
- Relative imports not used (files are copied into container at `/workspace`)
- Absolute imports from local files
- Example: `from prompt_utils import to_chat` at `llmops-labuide/docs/lab02.md` (line 152)
## Kubernetes and Configuration Conventions
- Four-space indentation
- Namespace explicitly declared in metadata
- Labels use shorthand: `{ app: name }`
- Example from `llmops-labuide/docs/lab04.md` (lines 406-415)
- Shebang: `#!/usr/bin/env bash`
- Set strict mode: `set -euo pipefail`
- Comments in markdown file with intent
- Example from `llmops-labuide/docs/lab04.md` (lines 485-492)
## FastAPI-Specific Conventions
- Pydantic `BaseModel` for request validation
- Field names use snake_case matching URL params
- Example from `llmops-labuide/docs/lab04.md` (lines 239-244)
- Return plain dicts; FastAPI auto-serializes to JSON
- Include metadata in response: `latency_seconds`, `usage`, `citations`
- Debug payload when `debug=True` in request
- Example response structure at lines 371-396
- Health check: `GET /health` returns `{"ok": True}`
- Ready check: `GET /ready` returns `{"ready": bool, "reason": str}`
- Business endpoints use clear method names: `/search`, `/chat`, `/dryrun`
## Data Structures and Format Conventions
- Each line is a complete sample: `{"messages": [{"role": "...", "content": "..."}]}`
- Structure: system → user → assistant message order
- Example: `llmops-labuide/docs/lab01.md` (lines 319-325)
- Consistent keys: `doc_id`, `section`, `path`, `type`, `text`
- `path` format: `"doc_id#section"` (with `#` separator) or just `doc_id`
- Example meta normalization: lines 780-795
- Stored as JSON alongside FAISS/sparse indices
- Can be list or dict with `"items"` or `"hits"` key
- Example: `llmops-labuide/docs/lab01.md` (lines 739-742)
## Numeric Constants and Defaults
- Named explicitly: `LORA_R = 4`, `BATCH_SIZE = 1`
- Comments note conservative/demo values: `# ↓ from 8`
- Example: `llmops-labuide/docs/lab02.md` (lines 160-172)
- Explicit in both code and k8s manifests
- Example: `max_tokens = min(req.max_tokens, 256)` at `llmops-labuide/docs/lab04.md` (line 350)
- Documented in comments why limits exist
## Project Structure Integration
- Data flows through clear stages: load → process → index/train → serve
- Dependencies are explicit and documented
- Path mounting strategy: `/mnt/project/` on k8s nodes
- Environment variables used for configuration injection
- Scripts organized as: `scripts/`, `k8s/`, `tools/`, `rag/`, `training/`, `serving/`
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Linear lab progression (Lab 00 through Lab 08) where each builds artifacts used by subsequent labs
- Two primary content formats: slide decks (PDF/DOCX) for conceptual learning and markdown lab guides for practical execution
- Static documentation site (MkDocs) serving as the primary delivery medium
- Project-based learning with cumulative infrastructure setup
- Focus on real-world GenAI operations patterns on Kubernetes
## Layers
- Purpose: Deliver course material to learners in multiple formats
- Location: `slides/` (presentation materials), `llmops-labuide/site/` (built static site)
- Contains: PDF modules, DOCX documents, compiled HTML/CSS/JS static site
- Depends on: MkDocs build process, markdown source content
- Used by: End-users accessing course materials
- Purpose: Define curriculum structure, learning objectives, and step-by-step instructions
- Location: `llmops-labuide/docs/` (11 markdown files)
- Contains: Lab instructions, code examples, Kubernetes manifests (YAML), shell commands, conceptual explanations
- Depends on: Git version control (`llmops-labuide/.git/`)
- Used by: Learners following labs, MkDocs build system
- Purpose: Configure documentation site structure, navigation, and deployment settings
- Location: `llmops-labuide/mkdocs.yml`
- Contains: Site metadata, navigation structure, theme settings (readthedocs), plugin configuration, analytics, repo links
- Depends on: MkDocs framework
- Used by: MkDocs build process to generate static site
## Data Flow
- Each lab creates artifacts (scripts, YAML manifests, generated data, trained models) that persist on the local filesystem
- Artifacts are mounted into Kubernetes nodes via KIND's volume mounting (`./project` → `/mnt/project`)
- Previous lab outputs become inputs to subsequent labs (e.g., fine-tuned model from Lab 02 → packaged in Lab 03 → served in Lab 04)
## Key Abstractions
- Purpose: Encapsulate a cohesive learning objective with commands and deliverables
- Examples: `llmops-labuide/docs/lab00.md`, `llmops-labuide/docs/lab01.md`, etc.
- Pattern: Each lab contains project directory structure setup, multiple code/config sections, shell commands (copy-paste ready), Kubernetes YAML manifests, and a lab summary
- Purpose: Define deployable infrastructure components
- Location: Inline in lab markdown files under Kubernetes manifest code blocks
- Pattern: YAML files organized by numbering (10-data for data jobs, 40-serve for serving deployments)
- Examples: Job manifests, Deployment manifests, Service manifests, KServe InferenceService definitions
- Purpose: Organize learner workspace across data, training, serving, and orchestration concerns
- Pattern: Nested directory structure (datasets/, tools/, rag/, k8s/, scripts/) created progressively as labs advance
- Consistent across labs for navigation and artifact reuse
## Entry Points
- Location: `llmops-labuide/site/index.html`
- Triggers: User visits documentation site at `http://llmops-tutorial.schoolofdevops.com/`
- Responsibilities: Presents course homepage with learning objectives and lab index
- Location: `llmops-labuide/docs/index.md` + individual `lab00.md` through `lab08.md`
- Triggers: User navigates to specific lab
- Responsibilities: Provide step-by-step instructions, code examples, conceptual explanations
- Location: `llmops-labuide/mkdocs.yml`
- Triggers: MkDocs build command (`mkdocs build`)
- Responsibilities: Compile markdown source into static HTML site in `site/` directory
## Error Handling
- Prerequisite checks (e.g., verify KIND cluster is running before deploying)
- Notes and warnings embedded in lab content (e.g., "> 🔎 Notes" sections in Lab 00)
- Copy-paste-ready commands designed to succeed given proper setup
- Optional labs (Lab 04.0 for macOS-specific vLLM testing) for variant workflows
## Cross-Cutting Concerns
- Kubernetes 1.34+ requirement (KIND node image pinned to v1.34.0)
- SmolLM2-135M model pinned for fine-tuning consistency
- Feature gates explicitly enabled (ImageVolume) for hardware-specific capabilities
- Lab files: `lab{NN}.md` (sequential numbering lab00-lab08)
- Project structure: `atharva-dental-assistant/` (domain-specific example)
- Kubernetes namespaces: `atharva-ml` (ML workloads), `atharva-app` (application), `monitoring` (observability)
- Markdown format with embedded code blocks for all executable content
- Headings structured for clear navigation through MkDocs
- Hyperlinks between labs and to external resources (GitHub, Kubernetes docs, tools)
- Lab summaries at end of each document recap achieved objectives
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
