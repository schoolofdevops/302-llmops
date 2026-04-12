---
sidebar_position: 2
---

# Preflight Check

Run the preflight script before starting Lab 00 to verify your environment.

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

<Tabs groupId="operating-systems">
  <TabItem value="macos" label="macOS / Linux">

```bash
cd labs/lab-00/starter
bash scripts/preflight-check.sh
```

  </TabItem>
  <TabItem value="windows" label="Windows">

```powershell
cd labs\lab-00\starter
.\scripts\preflight-check.ps1
```

  </TabItem>
</Tabs>

## What the Script Checks

- Docker Desktop is running
- Docker memory allocation (fail below 8GB, warn between 8-12GB)
- Docker disk space (fail below 20GB free)
- Required tools: `kind`, `kubectl`, `helm`, `docker`
- Port availability: 80, 8000, 30000, 32000
- No stale KIND cluster with name `llmops-kind` already exists

Fix all `[FAIL]` items before proceeding to Lab 00.
