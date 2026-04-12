---
sidebar_position: 1
---

# Troubleshooting

Common issues and fixes organized by lab.

## Lab 00 — Cluster Setup

**Issue**: KIND cluster creation fails with "bind: address already in use"

**Fix**: Run `kind delete cluster --name llmops-kind` to remove any stale cluster, then retry.

**Issue**: `/mnt/project/` is empty inside pods

**Fix**: Verify the `hostPath` in kind-config.yaml uses your absolute project path with forward slashes.
Restart the cluster after correcting the path.

## Lab 03-05 — vLLM + KServe

**Issue**: Pods stuck in Pending with "Insufficient memory"

**Fix**: Increase Docker Desktop memory to 12GB: Settings &gt; Resources &gt; Memory. Restart Docker Desktop.

More troubleshooting content added as labs are authored.
