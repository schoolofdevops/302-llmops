---
sidebar_position: 1
---

# Prerequisites

Install these tools before Lab 00.

## Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Docker Desktop | 28.x+ | Container runtime for KIND cluster |
| KIND | 0.27.0+ | Kubernetes in Docker |
| kubectl | 1.34.x | Kubernetes CLI |
| Helm | 3.x | Kubernetes package manager |

## Docker Desktop Memory

Open Docker Desktop and navigate to **Settings &gt; Resources &gt; Memory**.
Set to at least **8GB** (12GB recommended for later labs running vLLM + Prometheus simultaneously).

## Install KIND

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

<Tabs groupId="operating-systems">
  <TabItem value="macos" label="macOS">

```bash
brew install kind
```

  </TabItem>
  <TabItem value="windows" label="Windows">

```powershell
choco install kind
# or download from https://github.com/kubernetes-sigs/kind/releases
```

  </TabItem>
</Tabs>

## Clone the Companion Repo

```bash
git clone https://github.com/schoolofdevops/302-llmops.git
cd 302-llmops
```
