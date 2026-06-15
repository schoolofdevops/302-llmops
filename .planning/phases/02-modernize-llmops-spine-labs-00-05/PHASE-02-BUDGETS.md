# Phase 02 Resource Budgets — Single-Session Walk

**Methodology:** Single continuous KIND session, Lab 00 → Lab 05, no teardown between labs (D-10, D-11).
**Verification target:** macOS arm64, Docker Desktop with ≥14 GB RAM allocation.
**Cluster:** llmops-kind (3 nodes, KIND v1.34.0).

---

## Lab 00 — KIND cluster up, no workloads (baseline)

**Captured:** 2026-06-15T07:22:25Z

### Docker container memory (kind containers only)
```
CONTAINER ID   NAME                        CPU %     MEM USAGE / LIMIT      MEM %    NET I/O           BLOCK I/O        PIDS
49e5ef32fd0a   llmops-kind-worker          9.10%     139.1MiB / 9.705GiB   1.40%    440kB / 86.2kB    16.3MB / 193MB   82
1489fdf3ca53   llmops-kind-control-plane   12.65%    672.6MiB / 9.705GiB   6.77%    257kB / 2.61MB    146MB / 753MB    255
7f69399a155b   llmops-kind-worker2         1.30%     151.9MiB / 9.705GiB   1.53%    4.68MB / 142kB    35MB / 206MB     80
6f72ddf80a35   kind-registry               0.00%     8.816MiB / 9.705GiB   0.09%    26kB / 3.33kB     1.87GB / 235MB   9
```

**Estimated baseline RSS:** ~964 MiB (~1 GB) for 3-node KIND cluster

### Docker Desktop VM allocation
```
9.705 GiB allocated to Docker Desktop VM
⚠️  WARNING: Plan requires ≥14 GB. Current: ~9.7 GB.
    Lab 02 training job needs ~8 GB headroom. Increase via:
    Docker Desktop → Settings → Resources → Memory → 14 GB (or more)
```

### kubectl top nodes
```
error: Metrics API not available
metrics-server not installed yet (expected at Lab 00; available after kube-prometheus-stack in Lab 05)
```

### kubectl top pods -A
```
error: Metrics API not available
metrics-server not installed yet (expected at Lab 00; available after kube-prometheus-stack in Lab 05)
```

### Key observations
- Empty cluster baseline; only kube-system pods running.
- Estimated baseline RSS: ~964 MiB across 3 KIND nodes (via docker stats).
- metrics-server NOT installed at this stage; `kubectl top` will succeed once kube-prometheus-stack lands in Lab 05.
- Both ImageVolume gates verified functional: alpine test pod showed populated /mounted (bin, etc, usr visible).
- Host extraPortMappings bound: 30200, 30300, 30400, 30500 (verified via docker inspect).
- ⚠️ Docker Desktop memory is 9.705 GiB — below the 14 GB recommendation. Increase before Lab 02 (training job).

---
