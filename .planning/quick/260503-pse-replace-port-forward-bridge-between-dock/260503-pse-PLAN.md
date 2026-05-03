---
phase: 260503-pse-replace-port-forward-bridge-between-dock
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - course-code/labs/lab-00/solution/setup/kind-config.yaml
  - course-code/labs/lab-00/starter/setup/kind-config.yaml
  - course-code/labs/lab-01/solution/k8s/10-retriever-service.yaml
  - course-code/labs/lab-01/starter/k8s/10-retriever-service.yaml
  - course-code/labs/lab-07/solution/docker-compose.yaml
  - course-code/labs/lab-06/solution/scripts/generate-traffic-full.sh
  - course-code/labs/lab-06/starter/scripts/generate-traffic-full.sh
  - course-content/docs/labs/lab-07-agent-core.md
  - course-content/docs/labs/lab-02-rag-retriever.md
  - course-content/docs/labs/lab-06-web-ui.md
autonomous: true
requirements:
  - QUICK-PSE-260503-01
must_haves:
  truths:
    - "rag-retriever NodePort is 31001 in lab-01 starter and solution Service manifests"
    - "KIND control-plane maps host port 31001 → containerPort 31001 in both lab-00 starter and solution kind-config"
    - "Lab 07 docker-compose RETRIEVER_URL default points at host.docker.internal:31001 (no kubectl port-forward needed)"
    - "Lab 07 page no longer instructs the learner to run kubectl port-forward svc/rag-retriever 8001:8001"
    - "Lab 02 verification curls and lab 06 traffic script reference port 31001, not 30100"
    - "No live-doc / starter / solution reference to port-forward of rag-retriever or to host.docker.internal:8001 remains (excluding .planning/ history and llmops-labuide/ legacy guides)"
  artifacts:
    - path: "course-code/labs/lab-00/solution/setup/kind-config.yaml"
      provides: "KIND host→container port mapping for retriever NodePort 31001"
      contains: "containerPort: 31001"
    - path: "course-code/labs/lab-00/starter/setup/kind-config.yaml"
      provides: "Starter KIND config with 31001 mapping (matches solution)"
      contains: "containerPort: 31001"
    - path: "course-code/labs/lab-01/solution/k8s/10-retriever-service.yaml"
      provides: "rag-retriever NodePort Service on port 31001"
      contains: "nodePort: 31001"
    - path: "course-code/labs/lab-01/starter/k8s/10-retriever-service.yaml"
      provides: "Starter retriever NodePort 31001 (matches solution)"
      contains: "nodePort: 31001"
    - path: "course-code/labs/lab-07/solution/docker-compose.yaml"
      provides: "Compose RETRIEVER_URL defaults to host.docker.internal:31001"
      contains: "host.docker.internal:31001"
    - path: "course-content/docs/labs/lab-07-agent-core.md"
      provides: "Lab 07 prereq updated; port-forward instructions removed"
  key_links:
    - from: "course-code/labs/lab-07/solution/docker-compose.yaml (mcp-treatment-lookup)"
      to: "host port 31001 → KIND control-plane → rag-retriever Service nodePort 31001 → pod :8001"
      via: "host.docker.internal:31001 + kind extraPortMappings"
      pattern: "host\\.docker\\.internal:31001"
    - from: "course-content/docs/labs/lab-07-agent-core.md prereqs"
      to: "course-code/labs/lab-00/solution/setup/kind-config.yaml extraPortMappings"
      via: "Auto-exposed by KIND port mapping configured in Lab 00"
      pattern: "host\\.docker\\.internal:31001"
---

<objective>
Replace the fragile `kubectl port-forward svc/rag-retriever 8001:8001` bridge between the Lab 07 Docker Compose stack and the KIND-hosted RAG retriever with a stable NodePort 31001 + KIND `extraPortMappings` entry. Docker Compose containers will reach the retriever via `host.docker.internal:31001` with no port-forward terminal required.

Purpose: Eliminate the "blocks a terminal and is fragile" UX from Lab 07 — the most common live-class friction point on Day 2 — and make the retriever bridge declarative (config files), not operational (a long-running process the learner has to keep alive).

Output: Updated KIND configs (×2), retriever Service manifests (×2), docker-compose.yaml, traffic-generation scripts (×2), Lab 07 page (prereq + warning + after-this-lab table), Lab 02 verification commands, Lab 06 traffic snippet.

Decision (locked): REPURPOSE port 30100 — its KIND host port mapping stays in `kind-config.yaml` (reserved for future use). Only the retriever Service nodePort and the documentation that names the retriever's external port move to 31001. Add a new 31001 entry to `extraPortMappings` rather than renaming 30100.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@./CLAUDE.md
@.planning/STATE.md

@course-code/labs/lab-00/solution/setup/kind-config.yaml
@course-code/labs/lab-00/starter/setup/kind-config.yaml
@course-code/labs/lab-01/solution/k8s/10-retriever-service.yaml
@course-code/labs/lab-01/starter/k8s/10-retriever-service.yaml
@course-code/labs/lab-07/solution/docker-compose.yaml
@course-content/docs/labs/lab-07-agent-core.md
@course-content/docs/labs/lab-02-rag-retriever.md
@course-content/docs/labs/lab-06-web-ui.md
@course-code/labs/lab-06/solution/scripts/generate-traffic-full.sh

<scope_exclusions>
The following are OUT OF SCOPE and MUST NOT be modified:
- `llmops-labuide/site/**` — Docusaurus build output (regenerated by build)
- `llmops-labuide/docs/**` — legacy MkDocs guide superseded by `course-content/docs/`
- `.planning/**` — historical planning artifacts (decisions/SUMMARYs preserve old port numbers intentionally)
- `course-code/labs/lab-08/**` and `lab-09/**` `port-forward` references — those are KServe/Tempo/cost-middleware port-forwards, NOT the rag-retriever bridge being replaced

Only the rag-retriever ↔ Lab 07 Docker Compose bridge is in scope.
</scope_exclusions>

<repurposing_decision>
The existing `containerPort: 30100 / hostPort: 30100` block in both kind-config files MUST stay in place (reserved for future use). Add a NEW entry for 31001 alongside it. Do NOT rename 30100 → 31001 in the kind-config.
</repurposing_decision>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add NodePort 31001 to KIND configs, retriever Service, docker-compose, and traffic scripts</name>
  <files>
    course-code/labs/lab-00/solution/setup/kind-config.yaml,
    course-code/labs/lab-00/starter/setup/kind-config.yaml,
    course-code/labs/lab-01/solution/k8s/10-retriever-service.yaml,
    course-code/labs/lab-01/starter/k8s/10-retriever-service.yaml,
    course-code/labs/lab-07/solution/docker-compose.yaml,
    course-code/labs/lab-06/solution/scripts/generate-traffic-full.sh,
    course-code/labs/lab-06/starter/scripts/generate-traffic-full.sh
  </files>
  <action>
Make the following surgical edits in BOTH starter and solution where applicable. Use the Edit tool — preserve all surrounding YAML/comments untouched.

**1a. lab-00 kind-config (BOTH starter and solution)**

In the control-plane node's `extraPortMappings:` block, immediately AFTER the existing `30100` entry, ADD a new entry for 31001. Keep the 30100 entry unchanged (reserved for future use per the locked repurposing decision).

In `course-code/labs/lab-00/solution/setup/kind-config.yaml`, after line 84 (`    protocol: tcp` of the 30100 entry), insert:
```yaml
  - containerPort: 31001
    hostPort: 31001
    listenAddress: "0.0.0.0"
    protocol: tcp
```

In `course-code/labs/lab-00/starter/setup/kind-config.yaml`, after line 82 (`    protocol: tcp` of the 30100 entry, before the `30200` entry), insert the same 4 lines.

Indentation MUST match the surrounding entries exactly (two-space dash, four-space property indent). Do NOT touch the `30100` block, the worker nodes, or the `kubeadmConfigPatches` section.

**1b. lab-01 retriever Service (BOTH starter and solution)**

`course-code/labs/lab-01/solution/k8s/10-retriever-service.yaml` line 16: change `    nodePort: 30100` → `    nodePort: 31001`.

`course-code/labs/lab-01/starter/k8s/10-retriever-service.yaml` line 16: same change.

The Service's `port: 8001` and `targetPort: 8001` stay unchanged — only the nodePort moves.

**1c. lab-07 docker-compose**

`course-code/labs/lab-07/solution/docker-compose.yaml` line 57: change
```yaml
      RETRIEVER_URL: "${RETRIEVER_URL:-http://host.docker.internal:8001}"
```
to
```yaml
      RETRIEVER_URL: "${RETRIEVER_URL:-http://host.docker.internal:31001}"
```
The `extra_hosts` block (host.docker.internal:host-gateway) stays — it's still required for Linux Docker Engine.

**1d. lab-06 traffic generation scripts (BOTH starter and solution)**

In `course-code/labs/lab-06/solution/scripts/generate-traffic-full.sh` and `course-code/labs/lab-06/starter/scripts/generate-traffic-full.sh`:
- Line 9 (the `# Example:` comment): change `localhost 30100 30200 3` → `localhost 31001 30200 3`
- Line 14 (default value): change `RETRIEVER_PORT="${2:-30100}"` → `RETRIEVER_PORT="${2:-31001}"`

Do not touch any other line in those scripts.

**Why these specific files only:** The Service `nodePort` is the source of truth for the retriever's external port; the KIND mapping must publish it on the host so Docker Compose can reach it; the docker-compose default and the lab-06 traffic script are the only direct consumers that hardcode the port. All doc/prose updates are in Tasks 2 and 3.
  </action>
  <verify>
    <automated>cd /Users/gshah/courses/llmops &amp;&amp; rg "31001" course-code/labs/lab-00/solution/setup/kind-config.yaml course-code/labs/lab-00/starter/setup/kind-config.yaml course-code/labs/lab-01/solution/k8s/10-retriever-service.yaml course-code/labs/lab-01/starter/k8s/10-retriever-service.yaml course-code/labs/lab-07/solution/docker-compose.yaml course-code/labs/lab-06/solution/scripts/generate-traffic-full.sh course-code/labs/lab-06/starter/scripts/generate-traffic-full.sh &amp;&amp; ! rg "host\.docker\.internal:8001" course-code/labs/lab-07/ &amp;&amp; ! rg "nodePort: 30100" course-code/labs/lab-01/</automated>
  </verify>
  <done>
- Both kind-config files contain BOTH a `containerPort: 30100` entry and a `containerPort: 31001` entry under control-plane `extraPortMappings`.
- Both lab-01 retriever Service manifests have `nodePort: 31001` and no `nodePort: 30100`.
- lab-07 `docker-compose.yaml` defaults `RETRIEVER_URL` to `http://host.docker.internal:31001`.
- Both `generate-traffic-full.sh` files default `RETRIEVER_PORT` to `31001` and the `# Example:` line shows `31001`.
- `yq '.nodes[0].extraPortMappings[] | select(.containerPort == 31001)' course-code/labs/lab-00/solution/setup/kind-config.yaml` returns a non-empty mapping.
  </done>
</task>

<task type="auto">
  <name>Task 2: Update Lab 07 page — remove port-forward prereq, update warning callout and after-this-lab table</name>
  <files>
    course-content/docs/labs/lab-07-agent-core.md
  </files>
  <action>
All edits in `course-content/docs/labs/lab-07-agent-core.md`. Use the Edit tool with exact-match strings.

**2a. Replace the port-forward prereq (lines 37-41).**

Find this exact block:
```markdown
- [ ] Day-1 RAG retriever reachable on host port 8001 — in a **separate terminal** run:
  ```bash
  kubectl -n llm-app port-forward svc/rag-retriever 8001:8001
  ```
  Leave this terminal open for the duration of Lab 07.
```

Replace with:
```markdown
- [ ] Day-1 RAG retriever reachable on `host.docker.internal:31001` — the rag-retriever NodePort (31001) is auto-exposed by the KIND port mapping configured in Lab 00, so no `kubectl port-forward` is needed. Verify with `curl -s http://localhost:31001/health` and expect `{"ok":true}`. If the cluster was rebuilt without the 31001 mapping, re-run `bash course-code/labs/lab-00/solution/setup/bootstrap-kind.sh` (or the starter equivalent) so the new `extraPortMappings` entry takes effect.
```

**2b. Update the treatment_lookup warning callout (around line 402-404).**

Find this exact block:
```markdown
:::note treatment_lookup may return empty hits
If the Day-1 RAG retriever is not port-forwarded (`kubectl -n llm-app port-forward svc/rag-retriever 8001:8001`), `treatment_lookup` returns an empty list. The agent gracefully continues to `book_appointment` anyway — this is expected behavior in Docker Compose mode. Full end-to-end with retrieval works in Lab 08 (K8s).
:::
```

Replace with:
```markdown
:::note treatment_lookup may return empty hits
If the Day-1 RAG retriever Service is unreachable on `host.docker.internal:31001` (cluster down, retriever pod not Ready, or the 31001 KIND port mapping missing), `treatment_lookup` returns an empty list. The agent gracefully continues to `book_appointment` anyway — this is expected behavior in Docker Compose mode. Full end-to-end with retrieval works in Lab 08 (K8s).
:::
```

**2c. Update the prose mention of `host.docker.internal:8001` near line 187.**

Find:
```markdown
This tool reuses the Day-1 RAG retriever unchanged (D-10). It calls `/search` and returns top-k chunks. In Docker Compose mode the URL is `host.docker.internal:8001`; Lab 08 points it at the in-cluster Service.
```
Replace with:
```markdown
This tool reuses the Day-1 RAG retriever unchanged (D-10). It calls `/search` and returns top-k chunks. In Docker Compose mode the URL is `host.docker.internal:31001` (the retriever's NodePort, exposed via KIND port mapping); Lab 08 points it at the in-cluster Service.
```

**2d. Update the Linux extra_hosts callout (around line 473-480).**

Find:
```markdown
This resolves the Day-1 RAG retriever at `http://host.docker.internal:8001`. On macOS and Windows Docker Desktop, this is automatic. On Linux Docker Engine, the `extra_hosts` entry is required.
```
Replace with:
```markdown
This resolves the Day-1 RAG retriever at `http://host.docker.internal:31001`. On macOS and Windows Docker Desktop, this is automatic. On Linux Docker Engine, the `extra_hosts` entry is required.
```

**2e. Update the After This Lab table (around line 497).**

Find:
```markdown
| RAG retriever (Day 1, port-forwarded) | `http://localhost:8001` | Required upstream (KIND) |
```
Replace with:
```markdown
| RAG retriever (Day 1, NodePort) | `http://localhost:31001` | Required upstream (KIND) |
```

**2f. Update the tear-down note (around line 510).**

Find:
```markdown
The `-v` flag removes the `bookings-data` volume. Leave the stack running if you want to compare the Docker Compose version with the Lab 08 Kubernetes deployment. Stop the `kubectl port-forward` terminal (Ctrl-C) when done.
```
Replace with:
```markdown
The `-v` flag removes the `bookings-data` volume. Leave the stack running if you want to compare the Docker Compose version with the Lab 08 Kubernetes deployment.
```

(The trailing port-forward sentence is removed — there is no longer a port-forward terminal to stop.)

**Do NOT touch any other section** of `lab-07-agent-core.md` (Hermes content, MCP tool source listings, OS Tabs, Groq/Gemini setup, etc. all stay as-is).
  </action>
  <verify>
    <automated>cd /Users/gshah/courses/llmops &amp;&amp; ! rg "port-forward svc/rag-retriever" course-content/docs/labs/lab-07-agent-core.md &amp;&amp; ! rg "host\.docker\.internal:8001" course-content/docs/labs/lab-07-agent-core.md &amp;&amp; rg "host\.docker\.internal:31001" course-content/docs/labs/lab-07-agent-core.md &amp;&amp; rg "localhost:31001" course-content/docs/labs/lab-07-agent-core.md</automated>
  </verify>
  <done>
- No occurrence of `port-forward svc/rag-retriever` remains in `lab-07-agent-core.md`.
- No occurrence of `host.docker.internal:8001` remains in `lab-07-agent-core.md`.
- The prereq, treatment_lookup warning, prose mention, Linux callout, after-this-lab table, and tear-down note all reference `31001` (host.docker.internal:31001 or localhost:31001).
- The Day-1 retriever bullet in Prerequisites no longer references `kubectl port-forward` and instead says `host.docker.internal:31001` is auto-exposed by the Lab 00 KIND port mapping.
  </done>
</task>

<task type="auto">
  <name>Task 3: Update Lab 02 + Lab 06 docs to reference NodePort 31001 and run final repo-wide sweep</name>
  <files>
    course-content/docs/labs/lab-02-rag-retriever.md,
    course-content/docs/labs/lab-06-web-ui.md
  </files>
  <action>
Update remaining `course-content/docs/labs/` references that name the rag-retriever's external port. Use the Edit tool with `replace_all: true` where the same string appears multiple times — the doc currently has six `localhost:30100` curl examples in lab-02, all of which target the retriever and should move together.

**3a. lab-02-rag-retriever.md — verification curls + summary table**

In `course-content/docs/labs/lab-02-rag-retriever.md`, replace ALL occurrences of `localhost:30100` with `localhost:31001`. Lines affected (per repo grep): 244, 251, 285, 290.

Then update the prose at line 297:
```markdown
The Smile Dental RAG retriever is running in the `llm-app` namespace on NodePort 30100.
```
→
```markdown
The Smile Dental RAG retriever is running in the `llm-app` namespace on NodePort 31001.
```

And the summary table at line 302:
```markdown
| `rag-retriever` Service | NodePort 30100 |
```
→
```markdown
| `rag-retriever` Service | NodePort 31001 |
```

**3b. lab-06-web-ui.md — traffic-script invocation + summary table**

In `course-content/docs/labs/lab-06-web-ui.md`:

Line 243 — replace:
```
bash course-code/labs/lab-06/solution/scripts/generate-traffic-full.sh localhost 30100 30200 3
```
with:
```
bash course-code/labs/lab-06/solution/scripts/generate-traffic-full.sh localhost 31001 30200 3
```

Line 253 — replace:
```
 Retriever: http://localhost:30100
```
with:
```
 Retriever: http://localhost:31001
```

Line 352 — replace:
```
| RAG Retriever | `http://localhost:30100/search` | Running |
```
with:
```
| RAG Retriever | `http://localhost:31001/search` | Running |
```

**3c. Final repo-wide sweep**

After the edits above, run a stale-reference sweep to confirm no in-scope file still uses the old port-forward bridge or the deprecated retriever NodePort 30100. The sweep is informational — failures here are reported but do not block completion if they fall in known excluded paths.

Run from the repo root:

```bash
rg "30100|port-forward.*rag-retriever|host.docker.internal:8001" \
  --glob '!llmops-labuide/**' \
  --glob '!.planning/**' \
  --glob '!course-content/docs/labs/lab-08-agent-sandbox.md' \
  --glob '!course-content/docs/labs/lab-09-observability.md' \
  --glob '!course-code/labs/lab-08/**' \
  --glob '!course-code/labs/lab-09/**'
```

Expected: zero matches. If matches appear, they were missed in tasks 1-2; correct them and re-run.

Note on the kept 30100 entry: `course-code/labs/lab-00/{solution,starter}/setup/kind-config.yaml` will still match `30100` because the host port mapping is intentionally preserved per the locked repurposing decision. Add `course-code/labs/lab-00/` to the exclude list ONLY for the sweep below, then re-run:

```bash
rg "30100|port-forward.*rag-retriever|host.docker.internal:8001" \
  --glob '!llmops-labuide/**' \
  --glob '!.planning/**' \
  --glob '!course-content/docs/labs/lab-08-agent-sandbox.md' \
  --glob '!course-content/docs/labs/lab-09-observability.md' \
  --glob '!course-code/labs/lab-08/**' \
  --glob '!course-code/labs/lab-09/**' \
  --glob '!course-code/labs/lab-00/**'
```

This second sweep MUST return zero matches. If it does, the migration is clean.

**Do not touch:** `llmops-labuide/docs/lab00.md`, `llmops-labuide/docs/lab01.md`, `llmops-labuide/docs/lab05.md` — those are the legacy MkDocs guide and are out of scope per the scope_exclusions block. Likewise leave Lab 08 / Lab 09 port-forward content alone (it's KServe / Tempo / cost-middleware port-forwards, unrelated to the rag-retriever bridge).
  </action>
  <verify>
    <automated>cd /Users/gshah/courses/llmops &amp;&amp; ! rg "30100" course-content/docs/labs/lab-02-rag-retriever.md course-content/docs/labs/lab-06-web-ui.md course-content/docs/labs/lab-07-agent-core.md &amp;&amp; rg "31001" course-content/docs/labs/lab-02-rag-retriever.md &amp;&amp; rg "31001" course-content/docs/labs/lab-06-web-ui.md &amp;&amp; bash -c 'matches=$(rg "30100|port-forward.*rag-retriever|host.docker.internal:8001" --glob "!llmops-labuide/**" --glob "!.planning/**" --glob "!course-content/docs/labs/lab-08-agent-sandbox.md" --glob "!course-content/docs/labs/lab-09-observability.md" --glob "!course-code/labs/lab-08/**" --glob "!course-code/labs/lab-09/**" --glob "!course-code/labs/lab-00/**" 2>/dev/null); test -z "$matches"'</automated>
  </verify>
  <done>
- `lab-02-rag-retriever.md` has zero `30100` occurrences and at least one `31001` occurrence in a curl/health line.
- `lab-06-web-ui.md` traffic-script invocation passes `31001` (not `30100`); summary table row shows `http://localhost:31001/search`.
- The repo-wide sweep (excluding legacy `llmops-labuide/`, `.planning/`, lab-08/lab-09, and the intentionally-kept lab-00 KIND mapping) returns zero matches for `30100`, `port-forward.*rag-retriever`, or `host.docker.internal:8001`.
- Day-1 → Day-2 retriever bridge is purely declarative: KIND port mapping + Service nodePort + docker-compose env default — no `kubectl port-forward` instruction anywhere in the live course content.
  </done>
</task>

</tasks>

<verification>
After all three tasks:

1. **Static config consistency**
   ```bash
   yq '.nodes[0].extraPortMappings[] | select(.containerPort == 31001)' course-code/labs/lab-00/solution/setup/kind-config.yaml
   yq '.nodes[0].extraPortMappings[] | select(.containerPort == 31001)' course-code/labs/lab-00/starter/setup/kind-config.yaml
   yq '.spec.ports[0].nodePort' course-code/labs/lab-01/solution/k8s/10-retriever-service.yaml   # → 31001
   yq '.spec.ports[0].nodePort' course-code/labs/lab-01/starter/k8s/10-retriever-service.yaml    # → 31001
   yq '.services["mcp-treatment-lookup"].environment.RETRIEVER_URL' course-code/labs/lab-07/solution/docker-compose.yaml  # → "${RETRIEVER_URL:-http://host.docker.internal:31001}"
   ```

2. **Stale-reference sweep (in-scope only — see Task 3 for exclusion list)**
   ```bash
   rg "30100|port-forward.*rag-retriever|host.docker.internal:8001" \
     --glob '!llmops-labuide/**' \
     --glob '!.planning/**' \
     --glob '!course-content/docs/labs/lab-08-agent-sandbox.md' \
     --glob '!course-content/docs/labs/lab-09-observability.md' \
     --glob '!course-code/labs/lab-08/**' \
     --glob '!course-code/labs/lab-09/**' \
     --glob '!course-code/labs/lab-00/**'
   # Expected: no output
   ```

3. **(Optional, manual) Live-stack smoke test** — once Lab 01 + Lab 07 are re-run with the new manifests:
   - `kubectl -n llm-app get svc rag-retriever -o jsonpath='{.spec.ports[0].nodePort}'` → `31001`
   - `curl -s http://localhost:31001/health` → `{"ok":true}` from the host
   - `cd course-code/labs/lab-07/solution && docker compose up -d && docker compose exec mcp-treatment-lookup python -c "import urllib.request, os; print(urllib.request.urlopen(os.environ['RETRIEVER_URL']+'/health').read())"` → `b'{"ok":true}'`

(Live smoke test is not part of the automated verify because the cluster may not be running; the static checks are sufficient to merge the doc + config change.)
</verification>

<success_criteria>
- All 7 source files in Task 1 contain the expected new port (31001) and no stale 8001/30100 reference for the retriever bridge.
- All 3 doc files in Tasks 2-3 (`lab-07-agent-core.md`, `lab-02-rag-retriever.md`, `lab-06-web-ui.md`) describe the retriever as reachable on `host.docker.internal:31001` / `localhost:31001` with no `kubectl port-forward` in the prereqs or warnings.
- The in-scope stale-reference sweep returns zero matches.
- `llmops-labuide/`, `.planning/`, lab-08, lab-09 untouched.
- Existing port 30100 KIND mapping preserved (reserved for future use per repurposing decision).
</success_criteria>

<output>
After completion, create `.planning/quick/260503-pse-replace-port-forward-bridge-between-dock/260503-pse-SUMMARY.md`
</output>
