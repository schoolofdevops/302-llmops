---
sidebar_position: 1
---

# Lab 00: Cluster Setup

**Day 1 | Duration: ~30 minutes**

## Learning Objectives

- Create a 3-node KIND cluster with ImageVolume feature gates enabled
- Create the five namespaces used throughout the course
- Verify the cluster is healthy and ready for workloads

## Lab Files

Companion code: `labs/lab-00/`

## Prerequisites

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

Before creating the cluster, create the project workspace directory. The KIND cluster mounts this directory into all nodes at `/mnt/project` — it will be populated with code in subsequent labs.

```bash
mkdir -p llmops-project
```

## Setup

<Tabs groupId="operating-systems">
  <TabItem value="macos" label="macOS / Linux">

```bash
bash course-code/labs/lab-00/starter/scripts/preflight-check.sh
bash course-code/labs/lab-00/starter/scripts/bootstrap-kind.sh
```

  </TabItem>
  <TabItem value="windows" label="Windows">

```powershell
.\course-code\labs\lab-00\starter\scripts\preflight-check.ps1
bash course-code/labs/lab-00/starter/scripts/bootstrap-kind.sh
```

  </TabItem>
</Tabs>

:::note
The bootstrap script will ask for your project directory path. Enter the **absolute path** to the `llmops-project` directory you just created (e.g., `/Users/yourname/courses/llmops/llmops-project`).
:::

## Verify

```bash
kubectl get nodes
# Should show 3 nodes (1 control-plane, 2 workers) in Ready state

kubectl get namespaces | grep -E "llm-serving|llm-app|monitoring"
# Should show all 3 namespaces
```

## Lab Summary

After this lab: KIND cluster `llmops-kind` is running with 3 nodes, ImageVolume feature gates enabled,
and five namespaces created (`llm-serving`, `llm-app`, `monitoring`, `argocd`, `argo-workflows`).
