---
phase: 02-llmops-labs-day-1
plan: "02"
subsystem: lab-01-rag
tags: [rag, faiss, synthetic-data, fastapi, kubernetes, lab-01]
dependency_graph:
  requires: [02-01]
  provides: [lab-01-solution, lab-01-starter, faiss-retriever, synthetic-dataset]
  affects: [02-03, 02-04, 02-05]
tech_stack:
  added:
    - faiss-cpu==1.13.2
    - sentence-transformers==5.4.1
    - fastapi[standard]==0.135.3
    - prometheus-client==0.25.0
    - numpy==1.26.4
  patterns:
    - FAISS IndexFlatIP with normalize_embeddings=True for cosine similarity
    - Prometheus Counter + Histogram instrumented FastAPI service
    - K8s initContainer pattern for FAISS index build before serving
    - starter/solution code structure (solution=complete, starter=TODOs only)
key_files:
  created:
    - course-code/labs/lab-01/solution/datasets/clinic/treatments.json
    - course-code/labs/lab-01/solution/datasets/clinic/policies.json
    - course-code/labs/lab-01/solution/datasets/clinic/faqs.json
    - course-code/labs/lab-01/solution/datasets/clinic/doctors.json
    - course-code/labs/lab-01/solution/datasets/clinic/appointments.json
    - course-code/labs/lab-01/solution/tools/synth_data.py
    - course-code/labs/lab-01/solution/rag/build_index.py
    - course-code/labs/lab-01/solution/rag/retriever.py
    - course-code/labs/lab-01/solution/rag/requirements.txt
    - course-code/labs/lab-01/solution/k8s/10-retriever-deployment.yaml
    - course-code/labs/lab-01/solution/k8s/10-retriever-service.yaml
    - course-code/labs/lab-01/starter/tools/synth_data.py
    - course-code/labs/lab-01/starter/rag/build_index.py
    - course-code/labs/lab-01/starter/rag/retriever.py
    - course-code/labs/lab-01/starter/rag/requirements.txt
    - course-code/labs/lab-01/starter/k8s/10-retriever-deployment.yaml
    - course-code/labs/lab-01/starter/k8s/10-retriever-service.yaml
  modified: []
decisions:
  - "FAISS IndexFlatIP(384) with normalize_embeddings=True — inner product equals cosine on L2-normalised vectors"
  - "K8s initContainer builds FAISS index before retriever container starts — avoids 30s+ startup delay in serving container"
  - "Prometheus metrics mounted at /metrics via make_asgi_app() — avoids prometheus_client default HTTP server conflict"
  - "doctors.json includes per-day availability slots (not just days) for Phase 3 Hermes Agent appointment booking tool"
  - "Starter K8s manifests are identical copies of solution — students follow guide, not write manifests from scratch"
metrics:
  duration: 6min
  completed: "2026-04-23"
  tasks_completed: 2
  files_created: 20
---

# Phase 02 Plan 02: Lab 01 Synthetic Data + FAISS RAG Retriever Summary

**One-liner:** Smile Dental Clinic synthetic dataset (5 JSON files) and FAISS RAG retriever (FastAPI port 8001, NodePort 30100, Prometheus /metrics) with full solution and skeleton starter for lab-01.

## What Was Built

### Task 1: Smile Dental Synthetic Dataset (solution/)

Created all five clinic data files using "Smile Dental Clinic, Pune" branding and INR pricing:

- **treatments.json** — 12 dental treatments with TX-CODE format, category, specialist, indications, duration_minutes, visits, price_band_inr [min, max], aftercare
- **policies.json** — 8 clinic policies covering appointment booking, payment (UPI/card/cash, 50% advance for major), cancellation (24hr notice, ₹200 fee), insurance (Star Health, Niva Bupa, HDFC Ergo, ICICI Lombard), emergency walk-in, children policy, records, infection control
- **faqs.json** — 12 patient FAQs covering pain, cost, hours (Mon-Sat 9AM-7PM, Sun 10AM-2PM), payment/EMI, parking, emergency after-hours, insurance, X-ray frequency
- **doctors.json** — 4 doctors with specializations (General Dentistry, Orthodontics, Endodontics, Oral Surgery), qualifications, languages, per-day availability time slots — structured for Phase 3 Hermes Agent appointment booking
- **appointments.json** — 10 available appointment slots with slot_id/doctor_id/date/time/duration_minutes/status/treatment_types

Created **synth_data.py** generator that:
- Loads all 3 clinic data files via `DATA_DIR` env var
- Generates 300+ JSONL training examples using `build_example(user, assistant)` helper
- Produces price Q&A, duration Q&A, indication Q&A, aftercare Q&A, and policy/FAQ pairs with rephrasing templates for variety
- Outputs to `OUTPUT_DIR/dental_chat.jsonl`

### Task 2: FAISS RAG Retriever (solution/ + starter/)

**build_index.py:**
- `load_chunks(data_dir)` reads treatments, policies, faqs and creates one text chunk per record
- `build_and_save(chunks, index_dir, embed_model)` encodes with SentenceTransformer, builds `faiss.IndexFlatIP(384)`, persists `faiss.index` + `metadata.json`
- Uses `normalize_embeddings=True` so inner product equals cosine similarity

**retriever.py:**
- FastAPI service loading index+metadata at module level (not in route handler)
- `POST /search` — encodes query, runs `index.search()`, returns `{"hits": [...], "latency_seconds": float}`
- `GET /health` — liveness probe returning `{"ok": True}`
- `GET /metrics` — Prometheus text format via `make_asgi_app()`
- Instrumented with `Counter(retriever_search_requests_total)` and `Histogram(retriever_search_latency_seconds)`

**K8s manifests (solution/ and starter/):**
- `10-retriever-deployment.yaml` — initContainer builds FAISS index, main container serves on port 8001, readinessProbe on `/health` with 30s initial delay, resources requests/limits set
- `10-retriever-service.yaml` — NodePort 30100, namespace llm-app

**Starter files:**
- All Python starters have function signatures, docstrings, and `# TODO:` comments
- K8s manifests identical to solution (students follow guide, don't write manifests)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All solution files are fully implemented. Starter files intentionally contain `pass` and `TODO` comments — this is the designed behavior for student exercises, not production stubs.

## Self-Check: PASSED

Files verified:
- FOUND: course-code/labs/lab-01/solution/datasets/clinic/treatments.json (12 treatments)
- FOUND: course-code/labs/lab-01/solution/datasets/clinic/doctors.json (4 doctors)
- FOUND: course-code/labs/lab-01/solution/rag/build_index.py (faiss.write_index, normalize_embeddings=True)
- FOUND: course-code/labs/lab-01/solution/rag/retriever.py (/health, /search, prometheus_client, faiss.read_index)
- FOUND: course-code/labs/lab-01/solution/k8s/10-retriever-service.yaml (nodePort: 30100)

Commits verified:
- d0247ea: feat(02-02): create Smile Dental synthetic dataset and synth_data.py
- d301e18: feat(02-02): create FAISS RAG retriever solution and starter skeletons
