---
sidebar_position: 2
---

# Resource Cleanup

Run cleanup scripts between heavy lab sections to reclaim cluster memory.

## When to Clean Up

| After Labs | Run | Removes |
|------------|-----|---------|
| Labs 00-05 | `shared/scripts/cleanup-phase1.sh` | KServe, vLLM, model artifacts |
| Labs 06-08 | `shared/scripts/cleanup-phase2.sh` | Chainlit, Agent API, Agent Sandbox |
| Labs 09-13 | `shared/scripts/cleanup-phase3.sh` | Prometheus, Grafana, ArgoCD, Argo Workflows |

## Running Cleanup

```bash
bash shared/scripts/cleanup-phase1.sh
```

Cleanup scripts preserve namespaces and cluster infrastructure.
They only remove workloads to free memory for the next phase.
