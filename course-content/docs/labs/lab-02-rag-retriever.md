---
sidebar_position: 3
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 02: RAG Retriever

**Day 1 | Duration: ~45 minutes**

## Learning Objectives

- Understand the Retrieval-Augmented Generation (RAG) pattern and why it complements fine-tuning
- Build a FAISS vector index from the Smile Dental clinic corpus
- Deploy a FastAPI retriever service to Kubernetes using an initContainer pattern
- Query the running retriever and interpret the relevance scores

## Why RAG?

Fine-tuning (Lab 03) encodes domain knowledge into model weights — but weights are static. If Smile Dental changes its pricing next month, you'd have to retrain the model. And even a well-fine-tuned model can "hallucinate" specific facts if it wasn't trained on enough examples for a rare topic.

RAG solves this by keeping the authoritative knowledge in a separate database and retrieving the most relevant chunks at query time. The retriever returns 3 clinic documents, those are injected into the prompt as context, and the LLM synthesizes an answer. This means:
- **Accuracy** — the model reads the actual price from the retrieved document instead of relying on its weights
- **Updatability** — change the JSON files, rebuild the index, no retraining needed
- **Transparency** — in Lab 06, students can see exactly which documents were retrieved (glass-box mode)

In this lab, we build the retrieval half: a FAISS index backed by sentence embeddings, served through a FastAPI endpoint.

## How FAISS and Sentence Embeddings Work

**fastembed** converts text to a 384-dimensional numeric vector (embedding) using ONNX runtime — lightweight, no PyTorch needed. Semantically similar texts produce vectors that point in similar directions. We use `sentence-transformers/all-MiniLM-L6-v2`, a small but effective model that runs comfortably on CPU.

**FAISS IndexFlatIP** is an inner-product index. Since we normalize all embeddings to unit length (`normalize_embeddings=True`), the inner product equals the cosine similarity — 1.0 means identical, 0 means unrelated. FAISS can search hundreds of vectors in microseconds.

The workflow is:
1. Load treatments + policies + FAQs from JSON → create text chunks
2. Encode each chunk with the embedding model → 384-dim vectors
3. Normalize and add to FAISS IndexFlatIP
4. Save `faiss.index` and `metadata.json` to disk

At query time, the retriever encodes the user's question the same way and searches the index for the top-k most similar chunks.

## Code Walkthrough

The RAG code lives in `course-code/labs/lab-01/solution/rag/` (same code directory as the synth data tools — both are part of Lab 01 in the code repo).

### build_index.py

The `load_chunks()` function reads the three JSON files and produces a flat list of text chunks. Each treatment becomes one chunk that includes the treatment name, code, pricing, indications, duration, and aftercare — all in a single searchable string:

```python
text = (
    f"Treatment: {t['name']} (Code: {t['code']}). "
    f"Category: {t['category']}. Specialist: {t['specialist']}. "
    f"Indications: {indications}. "
    f"Duration: {t['duration_minutes']} minutes, {t['visits']} visit(s). "
    f"Cost at Smile Dental Clinic, Pune: ₹{price_low:,} to ₹{price_high:,}. "
    f"Aftercare: {aftercare}."
)
```

The `build_and_save()` function encodes all chunks, creates `IndexFlatIP(384)`, adds the normalized embeddings, and writes two files to disk: `faiss.index` (the searchable binary index) and `metadata.json` (the text + doc_id mapping so we can return readable results).

### retriever.py

A FastAPI service with three endpoints:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Liveness probe — returns `{"ok": true}` |
| `/search` | POST | Accepts `{"query": str, "k": int}` — returns top-k hits |
| `/metrics` | GET | Prometheus text format — retrieval latency and request counts |

The `/search` handler encodes the query using the same fastembed model as the index build step (critical — mismatched models give wrong scores), then calls `index.search()` and returns the matching chunks with their cosine scores.

## Kubernetes Deployment: initContainer Pattern

A key challenge: the FAISS index must be built before the retriever can serve requests. We solve this with a Kubernetes initContainer:

```
Pod startup:
  initContainer: build-index  →  runs build_index.py  →  writes /data/index/
  main container: retriever   →  starts AFTER init    →  reads /data/index/
```

The `emptyDir` volume is shared between both containers. The initContainer uses `pip install` directly (it runs inside a pod — `uv` is not installed there) + `python build_index.py`, writing `faiss.index` and `metadata.json` to `/data/index/`. Only then does Kubernetes start the `retriever` container, which reads the ready index at startup.

This pattern is used widely in production for one-time setup steps (database migrations, data downloads) that must complete before the main service starts.

## Lab Steps

All commands below assume you are in the **repository root** (where `course-code/` and `llmops-project/` directories are). If you're still inside `llmops-project/` from Lab 01:

```bash
cd ..
```

### Step 1: Copy the RAG code into your workspace

The clinic data files from Lab 01 are already in `llmops-project/datasets/clinic/`. Now copy the RAG code and K8s manifests:

<Tabs groupId="operating-systems">
  <TabItem value="mac" label="macOS / Linux">
  ```bash
  cp -r course-code/labs/lab-01/solution/rag/ llmops-project/rag/
  cp -r course-code/labs/lab-01/solution/k8s/ llmops-project/k8s/
  ```
  </TabItem>
  <TabItem value="win" label="Windows">
  ```powershell
  xcopy /E /I course-code\labs\lab-01\solution\rag\ llmops-project\rag\
  xcopy /E /I course-code\labs\lab-01\solution\k8s\ llmops-project\k8s\
  ```
  </TabItem>
</Tabs>

Verify the files are in place:

```bash
ls llmops-project/rag/
# Should show: build_index.py  retriever.py  requirements.txt

ls llmops-project/k8s/
# Should show: 10-retriever-deployment.yaml  10-retriever-service.yaml
```

### Step 2: Build the FAISS index locally (optional — for understanding)

You can run `build_index.py` locally to see how the index is built before deploying to Kubernetes. This is optional — the initContainer will also build it in-cluster.

<Tabs groupId="operating-systems">
  <TabItem value="mac" label="macOS / Linux">
  ```bash
  cd llmops-project
  source .venv/bin/activate
  uv pip install -r rag/requirements.txt

  python rag/build_index.py
  # Output:
  # Loaded 32 chunks from datasets/clinic
  # Loading embedding model: sentence-transformers/all-MiniLM-L6-v2
  # Encoding 32 chunks...
  # Built index: 32 chunks → datasets/index/faiss.index

  cd ..   # back to repository root
  ```
  </TabItem>
  <TabItem value="win" label="Windows">
  ```powershell
  cd llmops-project
  .venv\Scripts\activate
  uv pip install -r rag\requirements.txt

  python rag\build_index.py
  # Output:
  # Loaded 32 chunks from datasets/clinic
  # Loading embedding model: sentence-transformers/all-MiniLM-L6-v2
  # Encoding 32 chunks...
  # Built index: 32 chunks → datasets/index/faiss.index

  cd ..   # back to repository root
  ```
  </TabItem>
</Tabs>

:::note Why 32 chunks?
12 treatments + 8 policies + 12 FAQs = 32 documents. Each becomes one indexed chunk. Small enough to search instantly, large enough to cover the Smile Dental clinic corpus.
:::

### Step 3: Create ConfigMaps and apply Kubernetes manifests

The Deployment mounts clinic data and Python code into the pod via ConfigMaps. Create them first from your workspace files:

```bash
# Create ConfigMap with clinic JSON data (3 files used by build_index.py)
kubectl create configmap clinic-data -n llm-app \
  --from-file=treatments.json=llmops-project/datasets/clinic/treatments.json \
  --from-file=policies.json=llmops-project/datasets/clinic/policies.json \
  --from-file=faqs.json=llmops-project/datasets/clinic/faqs.json

# Create ConfigMap with Python source code (2 files: index builder + retriever)
kubectl create configmap retriever-code -n llm-app \
  --from-file=build_index.py=llmops-project/rag/build_index.py \
  --from-file=retriever.py=llmops-project/rag/retriever.py
```

Expected output:
```
configmap/clinic-data created
configmap/retriever-code created
```

Now apply the Deployment and Service:

```bash
kubectl apply -f llmops-project/k8s/
```

Expected output:
```
deployment.apps/rag-retriever created
service/rag-retriever created
```

### Step 4: Watch the initContainer complete

```bash
kubectl get pods -n llm-app -w
```

You'll see the pod go through these phases:
1. `Init:0/1` — initContainer `build-index` is running
2. `PodInitializing` — initContainer finished, main container starting
3. `Running` — retriever is ready

The initContainer takes about 1-2 minutes — it installs fastembed (lightweight ONNX-based embeddings) and downloads the embedding model on first run.

Check initContainer logs to see index build progress:

```bash
kubectl logs -n llm-app -l app=rag-retriever -c build-index
```

### Step 5: Verify the retriever is Ready

```bash
kubectl get pods -n llm-app
# NAME                              READY   STATUS    RESTARTS
# rag-retriever-xxxxx               1/1     Running   0

kubectl logs -n llm-app -l app=rag-retriever -c retriever | tail -5
# INFO:     Started server process
# INFO:     Waiting for application startup.
# INFO:     Application startup complete.
# INFO:     Uvicorn running on http://0.0.0.0:8001
```

## Verification

Test the health check:

```bash
curl http://localhost:31001/health
# {"ok":true}
```

Test retrieval with a dental query:

```bash
curl -s -X POST http://localhost:31001/search \
  -H "Content-Type: application/json" \
  -d '{"query": "How much does teeth whitening cost?", "k": 3}' | python3 -m json.tool
```

Expected response structure:

```json
{
  "hits": [
    {
      "doc_id": "TX-WHITE-01",
      "section": "treatments",
      "text": "Treatment: Teeth Whitening (Code: TX-WHITE-01). Category: Cosmetic Dentistry. ...",
      "score": 0.72
    },
    {
      "doc_id": "FAQ-03",
      "section": "faqs",
      "text": "Q: How long does teeth whitening last? A: Professional teeth whitening...",
      "score": 0.59
    },
    ...
  ],
  "latency_seconds": 0.0042
}
```

The `score` is the cosine similarity (0–1). Scores above 0.6 indicate strong semantic match. The first hit (teeth whitening treatment) scores highest because the query closely matches the indexed treatment text.

Try different queries to see which documents score highest:

```bash
# Policy question
curl -s -X POST http://localhost:31001/search \
  -H "Content-Type: application/json" \
  -d '{"query": "What is the cancellation policy?", "k": 2}' | python3 -m json.tool

# General FAQ
curl -s -X POST http://localhost:31001/search \
  -H "Content-Type: application/json" \
  -d '{"query": "Do you accept insurance?", "k": 2}' | python3 -m json.tool
```

## After This Lab

The Smile Dental RAG retriever is running in the `llm-app` namespace on NodePort 31001.

| Resource | Status |
|----------|--------|
| `rag-retriever` Deployment | Running (1/1) |
| `rag-retriever` Service | NodePort 31001 |
| FAISS index | 32 chunks (treatments + policies + FAQs) |

The retriever is used by:
- **Lab 06** (Chainlit UI) — the Chainlit app calls `/search` for every user message and injects the hits into the LLM prompt
