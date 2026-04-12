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

## Setup

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

<Tabs groupId="operating-systems">
  <TabItem value="macos" label="macOS / Linux">

```bash
bash scripts/preflight-check.sh
bash scripts/bootstrap-kind.sh
```

  </TabItem>
  <TabItem value="windows" label="Windows">

```powershell
.\scripts\preflight-check.ps1
bash scripts/bootstrap-kind.sh
```

  </TabItem>
</Tabs>

## Lab Content

Full lab instructions coming in Phase 2 content authoring.

## Lab Summary

After this lab: KIND cluster `llmops-kind` is running with 3 nodes, ImageVolume feature gates enabled,
and five namespaces created (`llm-serving`, `llm-app`, `monitoring`, `argocd`, `argo-workflows`).
