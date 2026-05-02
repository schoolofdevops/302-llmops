---
phase: 03-agentops-labs-day-2
plan: 03
subsystem: lab-07-doc
tags: [lab-07, docusaurus, hermes-agent, mcp, groq, gemini, walkthrough]
dependency_graph:
  requires: [03-02]
  provides: [lab-07-student-walkthrough]
  affects: [03-04, 03-05]
tech_stack:
  added: []
  patterns: [docusaurus-mdx-jsx-comment, tabs-groupId-llm-provider, admonition-pitfalls]
key_files:
  created: []
  modified:
    - course-content/docs/labs/lab-07-agent-core.md
decisions:
  - HTML comments (<!-- -->) replaced with MDX JSX comments ({/* */}) to satisfy Docusaurus MDX parser
  - OS Tabs dropped from Part F — docker compose commands are identical on macOS and Windows Git Bash
  - Inline Python assertion block in Verification replaced with simpler grep-based one-liner to stay under 500 lines
metrics:
  duration: "7 minutes"
  completed: "2026-05-02"
  tasks_total: 1
  tasks_completed: 1
  files_created: 1
  files_modified: 0
---

# Phase 3 Plan 03: Lab 07 Documentation Summary

Full Docusaurus walkthrough for Lab 07 Agent Core — 498-line page takes a student from `cp .env.example .env` to a verified multi-step agent demo with the canonical "severe tooth pain since yesterday" query exercising all three MCP tools.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Rewrite lab-07-agent-core.md as complete Day-2 walkthrough | 54284d4 | course-content/docs/labs/lab-07-agent-core.md |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] HTML comment syntax breaks MDX parser**
- **Found during:** Docusaurus build
- **Issue:** `<!-- TODO: screenshot... -->` — MDX treats `!` as illegal JSX, build fails with `Unexpected character U+0021`
- **Fix:** Changed to `{/* TODO: screenshot... */}` (MDX JSX comment syntax)
- **Files modified:** course-content/docs/labs/lab-07-agent-core.md
- **Commit:** 54284d4

### Design Choices During Execution

**OS Tabs in Part F:** Dropped. `docker compose up -d --build` and the `curl` canonical demo query work identically on macOS and Windows Git Bash. No OS-specific shell-quoting differences exist for these commands.

**Verification section:** Simplified to a single bash block with `python3 -m json.tool | grep '"name"'` pattern rather than inline Python assertions. Both approaches verify the same thing; the simplified version is easier to read and kept the page under 500 lines.

## Line Count

Final: **498 lines** (target: 250–500)

## The 5 Common Pitfalls Included

1. **Hermes requires a model with 64K+ context window** — `ValueError: context_length below MINIMUM_CONTEXT_LENGTH` if SmolLM2 or any 4K model is used (RESEARCH Pitfall 1)
2. **MCP url MUST end in /mcp** — `/mcp` suffix is where FastMCP mounts the endpoint; omitting it causes 404 at Hermes startup (RESEARCH Pitfall 3)
3. **API_SERVER_HOST=0.0.0.0 is mandatory inside containers** — without it Hermes binds to 127.0.0.1 only; Chainlit/curl get Connection refused (RESEARCH Pitfall 4)
4. **Linux Docker users — host.docker.internal requires extra_hosts** — not auto-resolved on Linux Docker Engine; compose file already includes `extra_hosts: host-gateway` (note admonition, not warning)
5. **Free-tier rate limits** — Groq 30 RPM / 6K TPM / 1K RPD; each demo query = 2–3 LLM calls (RESEARCH Pitfall 7)

## Docusaurus Build

**Status: PASSED**

Build command: `npx @docusaurus/core@3.10.0 build --no-minify`
Output: `[SUCCESS] Generated static files in "build".`

## Known Stubs

None — all code excerpts are verbatim from solution files. The `{/* TODO: screenshot */}` comment is a known placeholder per the plan spec (plan item 12 explicitly included it as a placeholder).

## Self-Check: PASSED
