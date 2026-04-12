---
phase: 01-course-infrastructure
plan: 02
subsystem: infra
tags: [docusaurus, nodejs, mdx, documentation, course-site]

requires: []
provides:
  - Docusaurus 3.10.0 site scaffold with dark-mode-first Kubernetes.io-like theme
  - Single courseSidebar (Setup + Labs + Reference) with all 14 lab pages wired
  - 14 placeholder MDX lab pages (lab-00 through lab-13) with learning objectives
  - Setup documentation (prerequisites, preflight) with OS-specific Tabs
  - Reference docs (troubleshooting, cleanup)
affects:
  - 01-03-PLAN.md (preflight scripts live in lab-00 companion code)
  - All content-authoring plans (lab placeholder files are the scaffold)

tech-stack:
  added:
    - Docusaurus 3.10.0 (Node 22.21.1 LTS)
    - "@docusaurus/preset-classic 3.10.0"
    - prism-react-renderer (bundled)
    - MDX 3 (bundled with Docusaurus)
  patterns:
    - courseSidebar with Setup/Labs/Reference category hierarchy
    - OS-specific commands via Docusaurus Tabs (groupId=operating-systems)
    - Docs-only site (blog: false, redirect from / to /docs)
    - Dark mode default with light mode toggle available

key-files:
  created:
    - course-content/docusaurus.config.ts
    - course-content/sidebars.ts
    - course-content/src/css/custom.css
    - course-content/src/pages/index.tsx
    - course-content/docs/index.md
    - course-content/docs/setup/prerequisites.md
    - course-content/docs/setup/preflight.md
    - course-content/docs/labs/lab-00-cluster-setup.md
    - course-content/docs/labs/lab-01-synthetic-data.md
    - course-content/docs/labs/lab-02-rag-retriever.md
    - course-content/docs/labs/lab-03-finetuning.md
    - course-content/docs/labs/lab-04-model-packaging.md
    - course-content/docs/labs/lab-05-model-serving.md
    - course-content/docs/labs/lab-06-web-ui.md
    - course-content/docs/labs/lab-07-agent-core.md
    - course-content/docs/labs/lab-08-agent-sandbox.md
    - course-content/docs/labs/lab-09-observability.md
    - course-content/docs/labs/lab-10-autoscaling.md
    - course-content/docs/labs/lab-11-gitops.md
    - course-content/docs/labs/lab-12-pipelines.md
    - course-content/docs/labs/lab-13-capstone.md
    - course-content/docs/reference/troubleshooting.md
    - course-content/docs/reference/cleanup.md
  modified: []

key-decisions:
  - "Redirect homepage (src/pages/index.tsx) to /docs instead of keeping default Docusaurus landing page - keeps learners on docs immediately"
  - "Added Reference category to sidebar (troubleshooting + cleanup) beyond plan spec - improves navigation completeness"
  - "Removed deprecated onBrokenMarkdownLinks config option (moved to markdown.hooks in Docusaurus v4)"

patterns-established:
  - "Pattern: Docusaurus Tabs with groupId=operating-systems for all OS-specific commands"
  - "Pattern: MDX files avoid bare < and { outside code fences (Docusaurus MDX 3 pitfall)"
  - "Pattern: Lab pages follow sidebar_position / H1 / Learning Objectives / Lab Files / Lab Content / Lab Summary structure"

requirements-completed:
  - INFRA-02

duration: 15min
completed: 2026-04-12
---

# Phase 01 Plan 02: Docusaurus Course Site Scaffold Summary

**Docusaurus 3.10.0 course site with dark-mode Kubernetes.io theme, 14 lab placeholder pages, OS-specific Tabs pattern, and single sequential courseSidebar — build exits 0**

## Performance

- **Duration:** 15 min
- **Started:** 2026-04-12T06:14:07Z
- **Completed:** 2026-04-12T06:29:36Z
- **Tasks:** 2
- **Files modified:** 40

## Accomplishments

- Scaffolded Docusaurus 3.10.0 with TypeScript classic template; fully configured for schoolofdevops/302-llmops
- Created all 14 lab placeholder MDX pages (lab-00 through lab-13) with learning objectives and lab summary stubs
- Applied Kubernetes.io-like color scheme (#326ce5 primary blue), dark mode default, OS-specific Tabs pattern

## Task Commits

1. **Task 1: Initialize Docusaurus 3.10.0 site and configure it** - `f63e4dd` (feat)
2. **Task 2: Create all placeholder lab pages and setup docs** - `3c81d09` (feat)

## Files Created/Modified

- `course-content/docusaurus.config.ts` - Full course config: title, url, org, dark mode, sidebar reference
- `course-content/sidebars.ts` - courseSidebar with Setup + Labs (14 items) + Reference categories
- `course-content/src/css/custom.css` - Kubernetes.io-like color overrides (#326ce5 primary blue)
- `course-content/src/pages/index.tsx` - Redirect to /docs (replaces default Docusaurus homepage)
- `course-content/docs/index.md` - Course homepage with Smile Dental use case description
- `course-content/docs/setup/prerequisites.md` - Tool requirements with OS-specific KIND install tabs
- `course-content/docs/setup/preflight.md` - Cross-platform preflight check instructions
- `course-content/docs/labs/lab-00-cluster-setup.md` - Lab 00 with Tabs (groupId=operating-systems)
- `course-content/docs/labs/lab-01-*.md` through `lab-13-capstone.md` - 13 additional placeholder pages
- `course-content/docs/reference/troubleshooting.md` - Common issues by lab
- `course-content/docs/reference/cleanup.md` - Resource cleanup scripts table

## Decisions Made

- Replaced Docusaurus default homepage (`src/pages/index.tsx`) with a simple redirect to `/docs` — the default page linked to a non-existent `/docs/intro` causing a broken-links build failure
- Added `Reference` category to the sidebar beyond the two-category plan spec (Setup + Labs) — troubleshooting and cleanup docs were created and needed a navigation home
- Removed `onBrokenMarkdownLinks: 'warn'` (deprecated in Docusaurus v4; build was emitting deprecation warnings; moved to `markdown.hooks` would require v4 config syntax, opted to drop since default behavior is warn)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed broken link on generated homepage**
- **Found during:** Task 1 verification (npm run build)
- **Issue:** Generated `src/pages/index.tsx` linked to `/docs/intro` which was removed. `onBrokenLinks: 'throw'` caused build failure.
- **Fix:** Replaced default homepage with `<Redirect to="/docs" />` — learners land directly on the course docs
- **Files modified:** `course-content/src/pages/index.tsx`
- **Verification:** npm run build exits 0 with no broken link errors
- **Committed in:** f63e4dd (Task 1 commit)

**2. [Rule 1 - Bug] Removed deprecated config causing build warnings**
- **Found during:** Task 1 build
- **Issue:** `onBrokenMarkdownLinks: 'warn'` is deprecated in Docusaurus 3.10.0 (v4 prep), emitting warnings every build
- **Fix:** Removed the deprecated option; default behavior is unchanged
- **Files modified:** `course-content/docusaurus.config.ts`
- **Verification:** npm run build exits 0 with no deprecation warnings
- **Committed in:** f63e4dd (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - Bug)
**Impact on plan:** Both fixes necessary for clean build. No scope creep.

## Known Stubs

The following files contain intentional stubs (content scaffolding for future phases):

- `course-content/docs/labs/lab-01-synthetic-data.md` through `lab-13-capstone.md` — contain "Full lab instructions coming in a later phase." These are intentional scaffolding stubs. Lab content authoring is planned for Phase 02 content-authoring plans.
- `course-content/docs/reference/troubleshooting.md` — contains only Lab 00 and Lab 03-05 entries. Additional content will be added as labs are authored.

These stubs do NOT prevent this plan's goal (site builds, sidebar is complete, all lab pages are accessible) from being achieved. They are resolved in Phase 02.

## Issues Encountered

None beyond the two auto-fixed build errors described above.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Docusaurus site is ready for content authoring; all 14 lab pages exist as scaffold
- Phase 01-03 (preflight scripts) can proceed — `labs/lab-00/starter/scripts/` path is documented in lab-00 and setup/preflight pages
- Any content author can run `cd course-content && npm run build` to verify their additions build cleanly

---
*Phase: 01-course-infrastructure*
*Completed: 2026-04-12*
