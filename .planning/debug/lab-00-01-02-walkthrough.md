---
slug: lab-00-01-02-walkthrough
status: resolved
created: 2026-05-01
resolved: 2026-05-01
---

# Lab 00/01/02 Full Walkthrough Audit

## Issues Found & Fixed

### Lab 00
- [x] KIND config mounts `./llmops-project` but dir didn't exist → Added `mkdir -p llmops-project` before bootstrap
- [x] NodePort 30100 not in KIND extraPortMappings → Added to both starter and solution configs
- [x] Script paths were ambiguous → Changed to full relative paths from repo root

### Lab 01
- [x] `uv pip install --system` → Replaced with proper venv: `uv venv` + `source .venv/bin/activate`
- [x] Copied ALL of solution/* (including rag/ and k8s/) → Now only copies datasets/ and tools/
- [x] Step 2 claimed to install from requirements.txt which has NO deps → Removed; noted stdlib only
- [x] Duplicate `cd llmops-project` in Step 4 → Removed

### Lab 02
- [x] ConfigMaps DON'T EXIST as manifests → Added `kubectl create configmap` commands
- [x] False expected output (4 resources) → Split into ConfigMap creation (2) + apply (2)
- [x] Redundant rag/ copy → Now correctly copies rag/ + k8s/ (Lab 01 no longer copies them)
- [x] `uv pip install --system` → Uses venv from Lab 01
- [x] No cwd context → Added "cd .." instruction and "assume repo root" note
- [x] Windows venv activation → Added OS-tabbed Step 2

## Root Causes

1. Lab content written from assumptions without executing commands
2. ConfigMaps referenced in Deployment but never created as YAML or instructions
3. Lab 01 blindly copied everything instead of what it needed
4. System-wide pip install copied from generic tutorials without thought
5. No end-to-end trace of student journey to catch logical gaps
