# Phase 1: Course Infrastructure - Research

**Researched:** 2026-04-12
**Domain:** Docusaurus site scaffolding, companion code repo structure, cross-platform preflight scripts, KIND cluster setup with ImageVolume feature gates, version pinning, cleanup scripts
**Confidence:** HIGH (most claims verified via npm registry, Docker info, official docs, and existing lab00.md reference)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Two repos — course-content repo (Docusaurus site at schoolofdevops/302-llmops) and course-code repo (starter/solution code). Keeps docs and code independent.
- **D-02:** Code repo structure: `labs/lab-00/starter/`, `labs/lab-00/solution/`, etc. Each lab has its own starter and solution directory.
- **D-03:** Student flow: Copy starter files to their workspace, follow lab instructions, compare with solution when done. If they fall behind, they can reset from the next lab's starter.
- **D-04:** Single learner-focused navigation path. No separate instructor/workshop view.
- **D-05:** Clean and modern visual identity. Dark/light toggle. Professional, similar to Kubernetes.io docs aesthetic.
- **D-06:** Use Docusaurus tabs for Windows/Mac command variants within lab pages.
- **D-07:** Preflight script validates: Docker Desktop memory (>= 8GB), required tools (kind, kubectl, helm, docker), port availability (30000, 32000, 8000, etc.), and OS detection (Windows/Mac/Linux with path adjustments).
- **D-08:** KIND cluster topology: 3 nodes (1 control-plane + 2 workers).
- **D-09:** Preflight script must work on both Windows (PowerShell/Git Bash) and macOS/Linux (bash).
- **D-10:** Project directory: `llmops-project/` (generic). K8s namespaces: `llm-serving`, `llm-app`.
- **D-11:** Lab numbering: Sequential Lab 00 through Lab 13. Day boundaries in titles/descriptions only.
- **D-12:** Domain branding: "Smile Dental" for use case only. Infrastructure naming stays generic.

### Claude's Discretion

- Detailed Docusaurus folder structure (docs/, sidebars config, etc.)
- Exact code repo directory layout within each lab's starter/solution
- COURSE_VERSIONS.md format and what to pin
- Cleanup script implementation (bash scripts vs Makefile targets)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INFRA-01 | Companion code repo with starter/ and solution/ directories per lab module | D-02 structure; labs/lab-00 through labs/lab-13 pattern |
| INFRA-02 | Docusaurus site supporting dual delivery (workshop schedule + Udemy self-paced) | D-04 single path decision; Docusaurus 3.10.0 sidebar config; existing mkdocs.yml as nav reference |
| INFRA-03 | Cross-platform preflight validation script (Windows + macOS Docker Desktop checks) | D-07, D-09; Docker system info API; PowerShell + bash dual-script pattern |
| INFRA-04 | Version pinning strategy (COURSE_VERSIONS.md) for all dependencies | STACK.md pinned versions; PITFALLS.md time-bomb analysis; existing kindest/node:v1.34.0 baseline |
| INFRA-05 | Lab phase resource management — cleanup scripts between resource-heavy sections | PITFALLS.md performance traps; bash scripts pattern preferred (no Makefile required) |
| K8S-01 | KIND cluster setup with ImageVolume feature gates (Windows + macOS) | Existing lab00.md KIND config YAML; PITFALLS.md Pitfall 3 (dual gate requirement) |
| K8S-02 | Namespace strategy for ML, app, monitoring, and agent workloads | D-10 namespaces: llm-serving, llm-app; monitoring; argocd; argo-workflows |
| K8S-03 | Preflight script validates Docker Desktop memory allocation, disk, and K8s version | docker system info approach; 8GB minimum (9.7GB currently on this machine — borderline) |

</phase_requirements>

---

## Summary

Phase 1 establishes the complete course scaffolding before any lab content is written. It has five distinct deliverable areas: (1) a Docusaurus 3.10.0 documentation site in the course-content repo, (2) a companion code repo with starter/solution directories for all 14 labs, (3) a cross-platform preflight script (bash for macOS/Linux, PowerShell for Windows), (4) a COURSE_VERSIONS.md pin file and KIND cluster setup lab (Lab 00), and (5) cleanup scripts for resource-heavy phase transitions.

The existing `llmops-labuide/docs/lab00.md` provides a working reference for the KIND config YAML — including the critical dual-gate pattern (kubeadmConfigPatches AND KubeletConfiguration) — but it has three problems that must be fixed: hardcoded Mac paths (`/Users/gshah/work/llmops/code/project`), old namespace names (`atharva-ml`, `atharva-app`), and the course-content repo is MkDocs (readthedocs theme), not Docusaurus. None of these are blockers; they are known starting-point corrections.

The Docker Desktop memory situation on this machine (9.7GB allocated) is borderline — above the 8GB validation threshold in D-07 but below the 12GB recommended in PITFALLS.md Pitfall 2. The preflight script should warn (not fail) at 8–12GB and recommend 12GB for later resource-heavy labs, with a hard fail below 8GB.

**Primary recommendation:** Build in this order — (1) code repo skeleton with all 14 lab directories, (2) Docusaurus site scaffold, (3) preflight scripts, (4) Lab 00 content (KIND cluster setup), (5) COURSE_VERSIONS.md, (6) cleanup scripts. Each deliverable is independent and can be verified in isolation.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Docusaurus | 3.10.0 | Course documentation site | Meta-maintained; React-based; versioning, MDX, dark/light toggle, Algolia search; npm latest as of 2026-04-12 |
| Node.js | 22.21.1 (LTS) | Docusaurus build runtime | Already installed on this machine; LTS line matches Docusaurus requirements |
| kindest/node | v1.34.0 | KIND cluster node image | Existing course pins this; ImageVolume beta is enabled in 1.34; students on 1.34.x all compatible |
| KIND | 0.27.0 | Local K8s cluster | Already installed on this machine; 0.27 supports KIND config v1alpha4 |
| kubectl | 1.34-compatible | K8s CLI | Already installed on this machine |
| Helm | 3.18.4 | K8s package manager | Already installed on this machine |
| Docker Desktop | 28.4.0 | Container runtime for KIND | Already installed (9.7GB RAM allocated) |
| Bash | system | Preflight + bootstrap scripts | macOS/Linux target; pair with PowerShell for Windows |
| PowerShell | 5.1+ (Win) / 7.x (cross-platform) | Windows preflight script | `Get-CimInstance`, `Test-NetConnection` available |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @docusaurus/plugin-content-docs | 3.10.0 | Sidebar, versioning | Default with classic preset |
| @docusaurus/theme-classic | 3.10.0 | Dark/light, navbar | Default; provides Kubernetes.io-like aesthetic |
| prism-react-renderer | bundled | Code syntax highlighting | Included in classic theme |
| clsx | bundled | CSS class utilities | Included in classic theme |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Docusaurus 3.10.0 | MkDocs Material | MkDocs is existing stack but cannot do versioning, MDX, or React components — ruled out by project decision |
| bash + PowerShell dual scripts | Python single script | Python not guaranteed installed before preflight; bash + PS ensures no runtime dependency |
| bash cleanup scripts | Makefile targets | Makefile requires make installed on Windows (extra friction); bash scripts are universally runnable via Git Bash on Windows |

**Installation (Docusaurus site):**
```bash
npx create-docusaurus@3.10.0 course-content classic --typescript
cd course-content
npm install
npm run start
```

**Version verification performed:**
```
npm view @docusaurus/core dist-tags  → latest: 3.10.0  (verified 2026-04-12)
kind --version                        → kind version 0.27.0
helm version --short                  → v3.18.4
docker --version                      → 28.4.0
node --version                        → v22.21.1
```

---

## Architecture Patterns

### Recommended Project Structure — course-content repo

```
course-content/                     # schoolofdevops/302-llmops-docs (Docusaurus site)
├── docs/
│   ├── index.md                    # Course homepage — value prop, prerequisites, how to use
│   ├── setup/
│   │   ├── prerequisites.md        # What to install before Lab 00
│   │   └── preflight.md            # How to run the preflight script
│   ├── labs/
│   │   ├── lab-00-cluster-setup.md
│   │   ├── lab-01-synthetic-data.md
│   │   ├── lab-02-rag-retriever.md
│   │   ├── lab-03-finetuning.md
│   │   ├── lab-04-model-packaging.md
│   │   ├── lab-05-model-serving.md
│   │   ├── lab-06-web-ui.md
│   │   ├── lab-07-agent-core.md
│   │   ├── lab-08-agent-sandbox.md
│   │   ├── lab-09-observability.md
│   │   ├── lab-10-autoscaling.md
│   │   ├── lab-11-gitops.md
│   │   ├── lab-12-pipelines.md
│   │   └── lab-13-capstone.md
│   └── reference/
│       ├── troubleshooting.md      # Top 3 errors per lab
│       ├── course-versions.md      # Links to COURSE_VERSIONS.md in code repo
│       └── cleanup.md              # When and how to run cleanup scripts
├── static/
│   └── img/
│       └── logo.svg                # Smile Dental or course logo
├── src/
│   └── css/
│       └── custom.css              # Kubernetes.io-like overrides (dark sidebar, accent color)
├── sidebars.ts                     # Single sidebar, sequential lab order
├── docusaurus.config.ts
└── package.json
```

### Recommended Project Structure — course-code repo

```
course-code/                        # schoolofdevops/302-llmops (companion code)
├── labs/
│   ├── lab-00/
│   │   ├── starter/
│   │   │   ├── setup/
│   │   │   │   └── kind-config.yaml      # Template with REPLACE_HOST_PATH placeholder
│   │   │   └── scripts/
│   │   │       ├── preflight-check.sh    # cross-platform preflight (bash)
│   │   │       ├── preflight-check.ps1   # Windows PowerShell variant
│   │   │       └── bootstrap-kind.sh     # Creates cluster + namespaces
│   │   └── solution/
│   │       ├── setup/
│   │       │   └── kind-config.yaml      # Fully working config
│   │       └── scripts/
│   │           ├── preflight-check.sh
│   │           ├── preflight-check.ps1
│   │           └── bootstrap-kind.sh
│   ├── lab-01/
│   │   ├── starter/
│   │   └── solution/
│   │   ... (labs 02-13 same pattern)
├── shared/
│   ├── k8s/
│   │   ├── namespaces.yaml         # llm-serving, llm-app, monitoring, argocd, argo-workflows
│   │   └── kind-config.yaml        # canonical 3-node config (reference copy)
│   └── scripts/
│       ├── cleanup-phase1.sh       # After labs 00-05 (remove KServe + models)
│       ├── cleanup-phase2.sh       # After labs 06-08 (remove agents + sandbox)
│       └── cleanup-phase3.sh       # After labs 09-13 (remove observability + gitops)
├── COURSE_VERSIONS.md
├── config.env                      # Central artifact config (MODEL_IMAGE_TAG, CLUSTER_NAME, etc.)
└── README.md
```

### Pattern 1: Docusaurus Single Sidebar with Sequential Lab Order

**What:** One `sidebars.ts` listing setup pages then lab-00 through lab-13 in order. No nested categories beyond a "Setup" group and "Labs" group. Dark/light toggle via `colorMode.defaultMode: 'dark'`.

**When to use:** All lab pages. The single-path constraint (D-04) means no conditional navigation.

**Example:**
```typescript
// sidebars.ts
import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  courseSidebar: [
    {
      type: 'category',
      label: 'Setup',
      items: ['setup/prerequisites', 'setup/preflight'],
    },
    {
      type: 'category',
      label: 'Labs',
      items: [
        'labs/lab-00-cluster-setup',
        'labs/lab-01-synthetic-data',
        'labs/lab-02-rag-retriever',
        'labs/lab-03-finetuning',
        'labs/lab-04-model-packaging',
        'labs/lab-05-model-serving',
        'labs/lab-06-web-ui',
        'labs/lab-07-agent-core',
        'labs/lab-08-agent-sandbox',
        'labs/lab-09-observability',
        'labs/lab-10-autoscaling',
        'labs/lab-11-gitops',
        'labs/lab-12-pipelines',
        'labs/lab-13-capstone',
      ],
    },
  ],
};

export default sidebars;
```

### Pattern 2: Docusaurus Tabs for OS-Specific Commands (D-06)

**What:** Use `<Tabs>` and `<TabItem>` MDX components for any command that differs between Windows and macOS. Apply consistently to: path formats, tool installation commands, Docker Desktop settings navigation.

**When to use:** Any lab step with OS-specific behavior. Every KIND path mount section, every preflight invocation.

**Example:**
```mdx
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

<Tabs groupId="operating-systems">
  <TabItem value="macos" label="macOS">
    ```bash
    bash scripts/preflight-check.sh
    ```
  </TabItem>
  <TabItem value="windows" label="Windows">
    ```powershell
    .\scripts\preflight-check.ps1
    ```
  </TabItem>
</Tabs>
```

Note: `groupId="operating-systems"` persists the selected tab across the entire session — students select their OS once and all tabs sync.

### Pattern 3: KIND Config with Dual ImageVolume Gate

**What:** The KIND config YAML must enable ImageVolume in TWO places: `kubeadmConfigPatches` (for API server, controller manager, scheduler) AND `KubeletConfiguration` (for the node-level kubelet). Enabling only one silently fails.

**When to use:** Required for Lab 00. This is the proven working pattern from the existing lab00.md.

**Example:**
```yaml
# setup/kind-config.yaml
# Source: llmops-labuide/docs/lab00.md (adapted — removed hardcoded paths)
kubeadmConfigPatches:
  - |
    apiVersion: kubeadm.k8s.io/v1beta3
    kind: ClusterConfiguration
    apiServer:
      extraArgs:
        feature-gates: "ImageVolume=true"
    controllerManager:
      extraArgs:
        feature-gates: "ImageVolume=true"
    scheduler:
      extraArgs:
        feature-gates: "ImageVolume=true"
  - |
    apiVersion: kubelet.config.k8s.io/v1beta1
    kind: KubeletConfiguration
    featureGates:
      ImageVolume: true

kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: llmops-kind
nodes:
- role: control-plane
  image: kindest/node:v1.34.0
  extraMounts:
    - hostPath: REPLACE_HOST_PATH   # students replace with absolute path
      containerPath: /mnt/project
  extraPortMappings:
  - containerPort: 30000
    hostPort: 30000
    listenAddress: "0.0.0.0"
    protocol: tcp
  - containerPort: 32000
    hostPort: 32000
    listenAddress: "0.0.0.0"
    protocol: tcp
  - containerPort: 8000
    hostPort: 8000
    listenAddress: "0.0.0.0"
    protocol: tcp
  # ... remaining port mappings
- role: worker
  image: kindest/node:v1.34.0
  extraMounts:
    - hostPath: REPLACE_HOST_PATH
      containerPath: /mnt/project
- role: worker
  image: kindest/node:v1.34.0
  extraMounts:
    - hostPath: REPLACE_HOST_PATH
      containerPath: /mnt/project
```

### Pattern 4: Preflight Script — Bash + PowerShell Pair

**What:** Two separate scripts that mirror each other's checks. The bash script handles macOS and Linux (and Windows Git Bash). The PowerShell script handles native Windows. Both produce identical pass/warn/fail output format.

**Checks to implement (D-07, K8S-03):**
1. OS detection
2. Docker Desktop running (`docker info`)
3. Docker memory >= 8GB (warn if < 12GB, fail if < 8GB)
4. Docker disk space >= 20GB free
5. Tools present: `kind`, `kubectl`, `helm`, `docker`
6. Port availability: 30000, 32000, 8000, 80, 443
7. K8s version check after cluster creation (>= 1.31 for ImageVolumes)

**When to use:** First thing every student runs, before creating the KIND cluster.

**Example (bash):**
```bash
#!/usr/bin/env bash
# scripts/preflight-check.sh
set -euo pipefail

PASS=0; WARN=0; FAIL=0
pass() { echo "[PASS] $1"; ((PASS++)); }
warn() { echo "[WARN] $1"; ((WARN++)); }
fail() { echo "[FAIL] $1"; ((FAIL++)); }

# OS detection
OS=$(uname -s 2>/dev/null || echo "Windows")
echo "==> OS: $OS"

# Docker running?
if ! docker info >/dev/null 2>&1; then
  fail "Docker is not running. Start Docker Desktop first."
else
  pass "Docker is running"
  # Memory check
  MEM_BYTES=$(docker system info --format '{{.MemTotal}}' 2>/dev/null || echo 0)
  MEM_GB=$((MEM_BYTES / 1073741824))
  if [ "$MEM_GB" -ge 12 ]; then
    pass "Docker memory: ${MEM_GB}GB (recommended)"
  elif [ "$MEM_GB" -ge 8 ]; then
    warn "Docker memory: ${MEM_GB}GB (minimum met; recommend 12GB for later labs)"
  else
    fail "Docker memory: ${MEM_GB}GB (below 8GB minimum — increase in Docker Desktop > Resources)"
  fi
fi

# Required tools
for tool in kind kubectl helm docker; do
  if command -v "$tool" >/dev/null 2>&1; then
    pass "$tool found: $(command -v "$tool")"
  else
    fail "$tool not found. See prerequisites page."
  fi
done

# Port availability
for port in 80 8000 30000 32000; do
  if ! lsof -i ":$port" >/dev/null 2>&1; then
    pass "Port $port is available"
  else
    warn "Port $port is in use — may conflict with lab services"
  fi
done

echo ""
echo "==> Preflight summary: $PASS passed, $WARN warnings, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  echo "Fix the FAIL items above before proceeding."
  exit 1
fi
```

### Pattern 5: Namespace Strategy

**What:** Five namespaces created at cluster bootstrap. Generic functional names (D-10), not brand-specific.

```yaml
# shared/k8s/namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: llm-serving    # vLLM, KServe InferenceService
---
apiVersion: v1
kind: Namespace
metadata:
  name: llm-app        # Chat UI (Chainlit), Agent API, RAG Retriever
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring     # Prometheus, Grafana
---
apiVersion: v1
kind: Namespace
metadata:
  name: argocd         # ArgoCD controller
---
apiVersion: v1
kind: Namespace
metadata:
  name: argo-workflows # Argo Workflows controller
```

### Pattern 6: COURSE_VERSIONS.md Format

**What:** A pinned version table with compatibility reason per entry. Lives in the course-code repo root. Claude's discretion on format — this pattern is the recommendation.

```markdown
# Course Versions

Tested combination as of: 2026-04-12
Workshop delivery: v1.0

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| kindest/node | v1.34.0 | ImageVolume beta available; v1.33 requires manual gate enable; v1.35 not yet tested |
| KIND CLI | 0.27.0 | Supports kind config v1alpha4; tested on macOS Apple Silicon + x86 |
| kubectl | 1.34.x | Server version match; avoid skew beyond ±1 |
| Helm | 3.x | 3.18+ preferred; any 3.x works |
| Docker Desktop | 4.x | Docker engine 28+; set Resources > Memory >= 12GB |
| vLLM | v0.19.0 | Official CPU Docker image: vllm/vllm-openai-cpu:v0.19.0-x86_64 |
| KServe | 0.14+ | RawDeployment mode for KIND (no Knative) |
| kube-prometheus-stack | latest Helm | Pin at time of workshop delivery |
| Python | 3.11 | PEFT + PyTorch + Transformers tested on 3.11; 3.12 has edge cases |
| PyTorch | 2.4+ (CPU) | MKL included in x86_64 wheels; required for NumPy 2.x compat |
| Transformers | 4.50+ | Required by vLLM 0.19.0 |
| PEFT | 0.14+ | LoRA CPU training on SmolLM2-135M |
| Sentence-Transformers | 3.x | all-MiniLM-L6-v2 embeddings; 22MB, 14.7ms/1K tokens CPU |
| FAISS | latest | In-process; no version constraint beyond Python 3.11 compat |
| Chainlit | 2.11.0 | Chat UI; requires --host 0.0.0.0 for K8s NodePort |
| Docusaurus | 3.10.0 | npm latest; Node.js 18+ required |
| Node.js | 22.x LTS | For Docusaurus build only |
```

### Pattern 7: Cleanup Script Structure

**What:** Three bash scripts corresponding to resource-heavy lab phase transitions (INFRA-05). Students run these between heavy sections to reclaim cluster memory.

**Cleanup scope by phase:**
- `cleanup-phase1.sh` — After labs 00-05: delete KServe InferenceService, vLLM pod, any model artifacts from cluster. Keeps namespaces and infrastructure.
- `cleanup-phase2.sh` — After labs 06-09: delete Chainlit, Agent API, Agent Sandbox controller. Keeps monitoring.
- `cleanup-phase3.sh` — After labs 10-13: full teardown including Prometheus/Grafana, ArgoCD, Argo Workflows.

**Why bash over Makefile:** Makefile requires `make` installed on Windows — extra friction. Git Bash on Windows runs bash scripts without additional tools.

### Anti-Patterns to Avoid

- **Hardcoded host paths in kind-config.yaml:** Use `REPLACE_HOST_PATH` placeholder with clear instruction. The existing lab00.md has `/Users/gshah/work/llmops/code/project` hardcoded — this must not be repeated.
- **Old namespace names (atharva-ml, atharva-app):** Every reference to the old names must be replaced with `llm-serving`, `llm-app`.
- **`latest` image tag in kindest/node:** Always pin to `v1.34.0` — `latest` is not a valid KIND image tag and will pull an unexpected version.
- **Cluster name with brand in it:** Use `llmops-kind` (already in existing lab, keep it — generic enough).
- **Enabling ImageVolume in only one place:** Must be in BOTH kubeadmConfigPatches AND KubeletConfiguration — single-location enable silently fails.
- **Docusaurus `docs/` directory conflict:** Docusaurus 3.x expects docs in `docs/` by default. Do not name the repo root folder `docs/` — use `course-content/` for the Docusaurus site repo.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| OS tab switching in docs | Custom MDX component | Docusaurus `<Tabs groupId>` | groupId persists selection; built-in, zero maintenance |
| Site search | Custom search backend | Docusaurus local search (default) or Algolia DocSearch | Local search works offline; Algolia optional upgrade |
| Dark/light toggle | CSS media query hack | Docusaurus `colorMode` config | Built-in, React context, no custom code |
| Port availability check on Windows | Custom WMI query | `Test-NetConnection -Port` in PowerShell | Standard cmdlet; no admin required |
| Docker memory check | Parse `/proc/meminfo` | `docker system info --format '{{.MemTotal}}'` | Cross-platform Docker API; works on macOS and Linux |
| K8s version check | Parse kubectl output manually | `kubectl version -o json | jq -r '.serverVersion.minor'` | Structured JSON output; jq available after tool install |
| Cleanup ordering | Custom dependency solver | Explicit `kubectl delete` in reverse-creation order | K8s garbage collection handles most dependencies; explicit order for operators |

**Key insight:** For a course infrastructure phase, the most expensive thing to hand-roll is the documentation site itself. Docusaurus 3.10.0 gives dark/light toggle, sidebar, tabs, search, code highlighting, and versioning for free — zero CSS required for a professional result with the `classic` preset.

---

## Common Pitfalls

### Pitfall 1: ImageVolume Silent Failure

**What goes wrong:** KIND cluster is created but ImageVolume feature gate is only set in `kubeadmConfigPatches` (API server level) and not in `KubeletConfiguration`. Pods appear Running, but the model directory mounted via ImageVolume is empty.

**Why it happens:** The two-location requirement is not obvious. The Kubernetes docs show one place; the KIND-specific requirement adds the kubelet config.

**How to avoid:** The `kind-config.yaml` in this phase (starter and solution) must include BOTH blocks. Add a Lab 00 validation step: after cluster creation, apply a test pod that mounts a known public image as a volume and verifies the mount is non-empty.

**Warning signs:** Pod is Running, but `kubectl exec` shows empty directory at the mount path. No `imagevolume` in `kubectl describe pod` events.

### Pitfall 2: Docker Desktop Memory Borderline

**What goes wrong:** This machine currently has 9.7GB allocated to Docker Desktop. The preflight passes the 8GB minimum. But labs 04-09 running vLLM + KServe + Prometheus simultaneously will hit memory pressure.

**Why it happens:** 9.7GB was likely set once and forgotten. Students in the same situation will proceed and hit OOM failures mid-lab.

**How to avoid:** The preflight script must warn (not fail) at 8–12GB range with a specific message: "Memory is at XGB. Later labs (vLLM + monitoring stack) need 12GB. Open Docker Desktop > Resources > Memory and increase to 12GB before Lab 04."

**Warning signs:** Pods stuck in Pending with `0/1 nodes available: Insufficient memory`.

### Pitfall 3: Hardcoded Host Paths Survive into Student Machines

**What goes wrong:** The existing lab00.md has `/Users/gshah/work/llmops/code/project` hardcoded in the KIND config. Students copy it, the path doesn't exist on their machine, and the volume mount silently fails.

**Why it happens:** Authors test on their own machine and don't parameterize.

**How to avoid:** Use `REPLACE_HOST_PATH` as the placeholder string. The bootstrap script (`bootstrap-kind.sh`) should detect this and prompt the student: `"Enter the absolute path to your project directory: "`. On Windows, the script can also auto-detect `$PWD` and offer it as the default.

**Warning signs:** `kubectl exec` to a pod shows `/mnt/project/` is empty even when files exist locally.

### Pitfall 4: Windows Path Separators in KIND Config

**What goes wrong:** On Windows, absolute paths use backslashes (`C:\Users\...`). KIND config YAML on Windows via Docker Desktop requires forward slashes or WSL2 paths. Students copy the macOS path format instructions and their KIND cluster fails to mount.

**Why it happens:** The existing course has no Windows-specific path guidance for KIND mounts.

**How to avoid:** In the Docusaurus tabs (D-06), show the Windows tab with: use `./llmops-project` (relative path, works in Git Bash) OR use WSL2 path format (`/mnt/c/Users/.../llmops-project`). Document the restriction explicitly in Lab 00.

**Warning signs:** KIND cluster creation succeeds but `kubectl exec` shows empty `/mnt/project/`.

### Pitfall 5: Docusaurus Build Fails Due to MDX Parse Errors

**What goes wrong:** Lab pages use code fences with special characters (backticks inside code, angle brackets in YAML comments). Docusaurus 3.x uses MDX 3, which is stricter than MDX 2. A single MDX parse error causes the entire build to fail, not just that page.

**Why it happens:** MDX 3 treats `{` and `<` as JSX syntax delimiters. YAML/bash code blocks that contain these characters must be inside triple-backtick code fences (not inline code). Lab authors familiar with plain Markdown may use `<your-value>` in prose text, which breaks MDX.

**How to avoid:** Always wrap placeholder values in code fences. In prose, use `**bold**` for placeholder names. Run `npm run build` (not just `npm run start`) before declaring a lab page complete — build is stricter than dev mode.

**Warning signs:** `MDXError: Unexpected token` in npm build output. Dev server `npm run start` works but `npm run build` fails.

### Pitfall 6: Port Conflicts from Previous KIND Clusters

**What goes wrong:** Students who previously ran the existing course (lab00.md uses same ports 30000, 32000, 8000) may have residual KIND clusters or Docker networks occupying those ports.

**Why it happens:** KIND cluster deletion doesn't always release all port mappings immediately.

**How to avoid:** The preflight script should check ports AND check for running KIND clusters (`kind get clusters`). If a stale cluster exists with the same name (`llmops-kind`), warn the student to delete it first.

**Warning signs:** `kind create cluster` fails with `bind: address already in use` or the cluster creates but NodePort services don't respond.

---

## Code Examples

Verified patterns from official sources and existing lab00.md:

### Docusaurus Config (docusaurus.config.ts)

```typescript
// Source: Docusaurus 3.10.0 official template (create-docusaurus classic)
import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';

const config: Config = {
  title: 'LLMOps & AgentOps with Kubernetes',
  tagline: 'From RAG to production agents on Kubernetes',
  url: 'https://llmops.schoolofdevops.com',
  baseUrl: '/',
  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',
  favicon: 'img/favicon.ico',
  organizationName: 'schoolofdevops',
  projectName: '302-llmops',

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          routeBasePath: '/',    // docs at root, not /docs/
          editUrl: 'https://github.com/schoolofdevops/302-llmops-docs/edit/main/',
        },
        blog: false,             // no blog for course site
        theme: {
          customCss: './src/css/custom.css',
        },
      },
    ],
  ],

  themeConfig: {
    colorMode: {
      defaultMode: 'dark',
      disableSwitch: false,
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'LLMOps with Kubernetes',
      logo: {
        alt: 'LLMOps Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          href: 'https://github.com/schoolofdevops/302-llmops',
          label: 'Code Repo',
          position: 'right',
        },
      ],
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'yaml', 'python', 'powershell'],
    },
  },
};

export default config;
```

### Bootstrap Script Pattern (adapted from lab00.md, fixed)

```bash
#!/usr/bin/env bash
# labs/lab-00/solution/scripts/bootstrap-kind.sh
set -euo pipefail

CLUSTER_NAME="llmops-kind"
KIND_CONFIG="setup/kind-config.yaml"

# Detect host path for volume mount
if [[ -z "${LLMOPS_PROJECT_PATH:-}" ]]; then
  echo "Enter the absolute path to your project directory"
  echo "(On macOS: /Users/yourname/llmops-project)"
  echo "(On Windows Git Bash: use ./llmops-project)"
  read -rp "Project path: " LLMOPS_PROJECT_PATH
fi

# Substitute placeholder in kind-config template
TMP_CONFIG=$(mktemp)
sed "s|REPLACE_HOST_PATH|${LLMOPS_PROJECT_PATH}|g" "$KIND_CONFIG" > "$TMP_CONFIG"

echo "==> Creating KIND cluster: $CLUSTER_NAME"
kind create cluster --name "$CLUSTER_NAME" --config "$TMP_CONFIG"
rm "$TMP_CONFIG"

echo "==> Verifying K8s version"
SERVER_MINOR=$(kubectl version -o json | jq -r '.serverVersion.minor' | sed 's/[^0-9].*//')
if [ "$SERVER_MINOR" -lt 31 ]; then
  echo "ERROR: K8s >= 1.31 required for ImageVolumes. Got: 1.${SERVER_MINOR}"
  exit 1
fi

echo "==> Creating namespaces"
kubectl apply -f ../../shared/k8s/namespaces.yaml

echo "==> Cluster ready. Namespaces: llm-serving, llm-app, monitoring, argocd, argo-workflows"
```

### ImageVolume Validation Pod

```yaml
# labs/lab-00/solution/test-imagevolume.yaml
# Run: kubectl apply -f test-imagevolume.yaml
# Verify: kubectl exec test-imagevolume -- ls /mnt/test (should show files, not empty dir)
apiVersion: v1
kind: Pod
metadata:
  name: test-imagevolume
spec:
  restartPolicy: Never
  containers:
  - name: test
    image: busybox:stable
    command: ["sh", "-c", "ls /mnt/test && echo 'ImageVolume OK' || echo 'ImageVolume EMPTY - check feature gates'"]
    volumeMounts:
    - name: test-vol
      mountPath: /mnt/test
  volumes:
  - name: test-vol
    image:
      reference: "busybox:stable"    # uses itself as an image volume
      pullPolicy: IfNotPresent
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| MkDocs readthedocs | Docusaurus 3.10.0 | Project decision 2026-04-12 | React components, MDX, versioning, dark mode |
| `schoolofdevops/vllm-cpu-nonuma:0.9.1` | `vllm/vllm-openai-cpu:v0.19.0-x86_64` | Jan 2026 (official Docker Hub) | Official support, 48.9% CPU throughput improvement |
| `atharva-ml`, `atharva-app` namespaces | `llm-serving`, `llm-app` | This phase | Generic, globally accessible branding |
| `atharva-dental-assistant/` project dir | `llmops-project/` | This phase | Generic per D-10 |
| Inline code in docs (copy-paste walls) | starter/solution in companion repo | This phase | Eliminates copy-paste errors, enables lab jump-in |
| Single lab file (1400+ lines) | Split docs + code repo | This phase | Navigable, maintainable |
| Docusaurus 3.9.2 (STACK.md) | Docusaurus 3.10.0 (npm latest) | ~2026 | Latest stable; STACK.md was slightly stale |

**Deprecated/outdated:**
- `theme: readthedocs` in mkdocs.yml: Replaced by Docusaurus classic theme
- `atharva` in any file name, namespace, or directory: Replaced by generic names
- Inline YAML manifests in lab docs: Move to `starter/` files in code repo

---

## Open Questions

1. **Does Docusaurus 3.10.0 have any breaking changes from 3.9.2?**
   - What we know: STACK.md recommends 3.9.2; npm latest is 3.10.0 (verified 2026-04-12)
   - What's unclear: Minor version upgrade notes not checked in detail
   - Recommendation: Use 3.10.0 (latest stable). Check official changelog if build fails.

2. **Windows PowerShell: `docker system info --format` available on all Windows Docker versions?**
   - What we know: The `--format` flag has been in Docker since v20; Docker Desktop 28 is installed on this machine
   - What's unclear: Whether students with Docker Desktop < 24 will have issues
   - Recommendation: Use `docker system info` and parse with `Select-String` as fallback; set minimum Docker Desktop requirement to 24+

3. **kind-config.yaml Windows path format for hostPath?**
   - What we know: Docker Desktop on Windows with WSL2 backend accepts Linux-style paths; Git Bash translates `./relative` paths
   - What's unclear: Edge case behavior with spaces in Windows paths
   - Recommendation: Document to use relative path `./llmops-project` on Windows, which avoids the backslash/space problem entirely. Absolute path is macOS-only guidance.

4. **Should COURSE_VERSIONS.md live in course-content repo or course-code repo?**
   - What we know: It pins software versions; Claude's discretion applies
   - Recommendation: Primary in course-code repo root (where the code is). Mirror a summary/link in the Docusaurus reference section.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker Desktop | KIND cluster, all labs | YES | 28.4.0 | — |
| Docker memory >= 8GB | K8S-03 preflight | YES (borderline) | 9.7GB allocated | Warn students to increase to 12GB |
| kind CLI | K8S-01 cluster creation | YES | 0.27.0 | — |
| kubectl | All K8s operations | YES | present | — |
| helm | Monitoring stack install | YES | 3.18.4 | — |
| node / npm | Docusaurus build | YES | node 22.21.1 / npm 10.9.4 | — |
| Python 3.x | Lab scripts | YES (3.13.7) | 3.13.7 | Note: course targets 3.11; 3.13 may work but untested with PEFT |
| jq | K8s version check in scripts | UNKNOWN | — | Use `kubectl version -o json \| python3 -c "import sys,json; ..."` as fallback |
| lsof | Port check in preflight | YES (macOS) | system | Windows: use `Test-NetConnection` in PS script |

**Missing dependencies with no fallback:**
- None that block Phase 1 execution.

**Missing dependencies with fallback:**
- `jq`: Script should detect presence with `command -v jq` and fall back to Python for JSON parsing if absent.
- Python 3.11 (course target): 3.13 is installed; Phase 1 scripts are bash only — no Python dependency in this phase.

**Note on Docker memory:** 9.7GB is currently allocated. This is above the 8GB hard minimum for Lab 00, but students should be warned proactively to increase to 12GB before labs 04-09 (vLLM + monitoring).

---

## Project Constraints (from CLAUDE.md)

The following directives from the global `~/.claude/CLAUDE.md` apply to implementation:

- **Semantic versioning:** Tag releases with semver (applies to COURSE_VERSIONS.md tagging strategy)
- **Update changelog before releases:** COURSE_VERSIONS.md update before any release tag
- **Tooling:** Use `fd` for file search, `rg` for text search, `ast-grep` for code structure, `jq` for JSON, `yq` for YAML in scripts
- **TDD:** No production code without a failing test first (applies to preflight scripts — write a test harness that verifies preflight output before writing the script body)
- **Verification:** Before claiming "script works," run it and show output
- **No Tauri or React portal patterns** — not applicable to this phase

---

## Sources

### Primary (HIGH confidence)
- `llmops-labuide/docs/lab00.md` — Existing KIND config YAML with ImageVolume gates (direct read)
- `llmops-labuide/mkdocs.yml` — Existing navigation structure (direct read)
- `.planning/research/PITFALLS.md` — Critical pitfalls: ImageVolume silent failure, Docker Desktop memory, hardcoded paths (direct read)
- `.planning/research/STACK.md` — Version recommendations for the full course stack (direct read)
- `.planning/research/ARCHITECTURE.md` — Lab progression and Docusaurus structure patterns (direct read)
- npm registry: `@docusaurus/core` dist-tags → latest: 3.10.0 (verified 2026-04-12 via `npm view`)
- Docker Desktop on this machine: 9.7GB RAM allocated (verified via `docker system info`)
- KIND CLI: 0.27.0 (verified via `kind --version`)
- Helm: 3.18.4 (verified via `helm version`)
- Node.js: 22.21.1 (verified via `node --version`)

### Secondary (MEDIUM confidence)
- Docusaurus 3.x MDX 3 strictness: verified by Docusaurus blog + multiple community reports of `{` parse errors
- KIND hostPath + Windows path format: verified by KIND docs and multiple GitHub issues

### Tertiary (LOW confidence)
- PowerShell `Test-NetConnection` behavior on Windows Docker Desktop: based on training knowledge, not verified on Windows machine in this session

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all versions verified against npm registry and local tool installations
- Architecture patterns: HIGH — Docusaurus structure from official docs; KIND config from working existing lab00.md
- Pitfalls: HIGH — ImageVolume pitfall from existing lab, Docker memory from direct inspection, Windows paths from existing course knowledge
- Environment: HIGH — direct `docker system info` and CLI checks

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable stack; Docusaurus version may increment but 3.10.x will remain compatible)
