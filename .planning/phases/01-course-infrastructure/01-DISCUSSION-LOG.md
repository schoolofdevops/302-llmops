# Phase 1: Course Infrastructure - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 01-course-infrastructure
**Areas discussed:** Repo structure, Docusaurus site, Preflight & setup, Lab naming

---

## Repo Structure

### Q1: How should the companion code repo be organized?

| Option | Description | Selected |
|--------|-------------|----------|
| Single repo, flat | labs/lab-00/starter/, labs/lab-00/solution/ per lab | |
| Single repo, nested | starter/ has growing project per checkpoint | |
| Two repos | Separate course-content and course-code repos | |
| You decide | Claude picks the best structure | ✓ |

**User's choice:** You decide
**Notes:** Claude decided on two repos (content + code) based on independence benefit

### Q2: How do students progress through labs?

| Option | Description | Selected |
|--------|-------------|----------|
| Copy starter, build on it | Copy starter files, follow instructions, compare with solution | ✓ |
| Cumulative workspace | Build one project across all labs, starter = prior solution | |
| Fresh each lab | Each lab self-contained, no dependency | |

**User's choice:** Copy starter, build on it

---

## Docusaurus Site

### Q1: How should Docusaurus handle dual delivery?

| Option | Description | Selected |
|--------|-------------|----------|
| Single path + tags | One linear sequence with info boxes for pacing | |
| Two navigation paths | Separate Workshop and Self-Paced sidebars | |
| You decide | Claude picks | |

**User's choice:** Other — "Create just one path. No need for anything specific to workshop/instructors. Designed with learners as audience. During workshop, instructor demos and explains the same, followed by learners following lab guides."

### Q2: Visual identity for the course site?

| Option | Description | Selected |
|--------|-------------|----------|
| Clean and modern | Minimal, dark/light toggle, professional. Kubernetes.io style. | ✓ |
| Developer-friendly | Playful but technical. Docusaurus default with custom colors. | |
| School of DevOps brand | Match existing schoolofdevops.com | |
| You decide | Claude picks | |

**User's choice:** Clean and modern

---

## Preflight & Setup

### Q1: What should the preflight script validate?

| Option | Description | Selected |
|--------|-------------|----------|
| Docker Desktop memory | Check Docker VM >= 8GB | ✓ |
| Required tools | Check kind, kubectl, helm, docker installed | ✓ |
| Port availability | Check key ports are free | ✓ |
| OS detection | Detect OS and adjust paths/commands | ✓ |

**User's choice:** All four selected (multiSelect)

### Q2: Cluster topology?

| Option | Description | Selected |
|--------|-------------|----------|
| 3 nodes (current) | 1 control-plane + 2 workers. More realistic. | ✓ |
| 2 nodes | 1 control-plane + 1 worker. Lighter. | |
| You decide | Claude picks | |

**User's choice:** 3 nodes (current)

---

## Lab Naming

### Q1: Project directory and K8s namespaces?

| Option | Description | Selected |
|--------|-------------|----------|
| smile-dental | smile-dental-assistant/, smile-ml, smile-app | |
| smile | smile-assistant/, smile-ml, smile-app | |
| By function | llmops-project/, llm-serving, llm-app | ✓ |
| You decide | Claude picks | |

**User's choice:** By function

### Q2: Lab numbering scheme?

| Option | Description | Selected |
|--------|-------------|----------|
| Sequential (00-13) | Simple: Lab 00, Lab 01, ... Lab 13. Day boundaries in titles. | ✓ |
| By day (1.1, 2.1) | Day.Lab format: 1.1, 1.2, ... 2.1, etc. | |
| You decide | Claude picks | |

**User's choice:** Sequential (00-13)

---

## Claude's Discretion

- Docusaurus folder structure (docs/, sidebars config)
- Code repo directory layout within starter/solution
- COURSE_VERSIONS.md format
- Cleanup script implementation approach

## Deferred Ideas

None
