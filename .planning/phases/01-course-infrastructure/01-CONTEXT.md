# Phase 1: Course Infrastructure - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish the complete course scaffolding before any lab content is written: Docusaurus site, companion code repo with starter/solution structure, preflight validation script (Windows + macOS), version pinning, KIND cluster setup lab, and cleanup scripts for resource management between lab phases.

</domain>

<decisions>
## Implementation Decisions

### Repo Structure
- **D-01:** Two repos — separate course-content repo (Docusaurus site at schoolofdevops/302-llmops) and course-code repo (starter/solution code). Keeps docs and code independent.
- **D-02:** Code repo structure: `labs/lab-00/starter/`, `labs/lab-00/solution/`, etc. Each lab has its own starter and solution directory.
- **D-03:** Student flow: Copy starter files to their workspace, follow lab instructions, compare with solution when done. If they fall behind, they can reset from the next lab's starter.

### Docusaurus Site
- **D-04:** Single learner-focused navigation path. No separate instructor/workshop view. During workshops, the instructor demos and explains the same labs that learners follow.
- **D-05:** Clean and modern visual identity. Dark/light toggle. Professional, similar to Kubernetes.io docs aesthetic.
- **D-06:** Use Docusaurus tabs for Windows/Mac command variants within lab pages.

### Preflight & Setup
- **D-07:** Preflight script validates: Docker Desktop memory (>= 8GB), required tools (kind, kubectl, helm, docker), port availability (30000, 32000, 8000, etc.), and OS detection (Windows/Mac/Linux with path adjustments).
- **D-08:** KIND cluster topology: 3 nodes (1 control-plane + 2 workers) — same as current course for realism.
- **D-09:** Preflight script must work on both Windows (PowerShell/Git Bash) and macOS/Linux (bash).

### Lab Naming
- **D-10:** Project directory: `llmops-project/` (generic, not domain-specific). K8s namespaces: `llm-serving`, `llm-app` (by function, not by brand).
- **D-11:** Lab numbering: Sequential Lab 00 through Lab 13. Day boundaries noted in lab titles/descriptions but not in numbering scheme.
- **D-12:** Domain branding: "Smile Dental" for the use case only (data, prompts, UI). Infrastructure naming stays generic.

### Claude's Discretion
- Claude decides the detailed Docusaurus folder structure (docs/, sidebars config, etc.)
- Claude decides the exact code repo directory layout within each lab's starter/solution
- Claude decides the COURSE_VERSIONS.md format and what to pin
- Claude decides cleanup script implementation (bash scripts vs Makefile targets)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Course (Reference Only)
- `llmops-labuide/docs/lab00.md` — Existing KIND setup lab (reference for cluster config, port mappings, namespace creation)
- `llmops-labuide/mkdocs.yml` — Existing site config (reference for navigation structure, metadata)
- `llmops-labuide/docs/index.md` — Existing course homepage (reference for lab index format)

### Research
- `.planning/research/PITFALLS.md` — Critical pitfalls: Docker Desktop memory cap, ImageVolume silent failure, hardcoded paths
- `.planning/research/ARCHITECTURE.md` — Suggested lab progression and Docusaurus dual-delivery structure
- `.planning/research/STACK.md` — Version pinning recommendations, vLLM 0.19.0, KServe 0.14+

### Project Context
- `.planning/PROJECT.md` — Key decisions: Docusaurus, Chainlit, FAISS, Hermes Agent, two-phase LLM strategy
- `.planning/REQUIREMENTS.md` — INFRA-01-05 and K8S-01-03 requirements for this phase
- `.planning/ROADMAP.md` — Phase 1 success criteria

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `llmops-labuide/docs/lab00.md` — KIND config YAML, bootstrap script, namespace creation pattern. Must be rewritten (hardcoded Mac paths, "atharva" naming) but structure is proven.
- `slides/00-LLMOps-with-Kubernetes.pdf` — Conceptual overview material (reference for site homepage content)

### Established Patterns
- Sequential lab numbering (lab00-lab08) — maintaining this pattern
- Lab structure: goal description, file additions list, step-by-step commands, lab summary — good pattern to keep
- Namespace pattern: separate ML and app namespaces — keeping with generic names

### Integration Points
- KIND cluster config becomes the foundation for ALL subsequent phases
- Port mappings in KIND config must accommodate: vLLM (8000), Chainlit, Prometheus (30000s), ArgoCD, Argo Workflows
- The preflight script is the first thing every student runs — it must catch all environment issues

</code_context>

<specifics>
## Specific Ideas

- Learner-first design: the Docusaurus site should feel like the best course docs a student has ever used
- Live cluster verification: every phase is tested against a real KIND cluster on this machine before being marked complete
- Cross-platform: Windows support is first-class, not an afterthought. Every command, path, and script must work on both platforms.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-course-infrastructure*
*Context gathered: 2026-04-12*
