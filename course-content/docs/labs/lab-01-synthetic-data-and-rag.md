---
sidebar_position: 2
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 01: Synthetic Data + RAG Retriever

**Day 1 | Duration: ~75 minutes**

## Learning Objectives

- Understand why domain-specific synthetic data improves fine-tuned LLM quality
- Explore the Smile Dental clinic dataset (treatments, policies, FAQs, doctor schedules)
- Generate a JSONL training dataset from structured JSON clinic data
- Understand the chat format (`messages` array) required for instruction fine-tuning
- Understand the Retrieval-Augmented Generation (RAG) pattern and why it complements fine-tuning
- Build a FAISS vector index from the Smile Dental clinic corpus
- Deploy a FastAPI retriever service to Kubernetes using an initContainer pattern
- Query the running retriever and interpret the relevance scores

## Why Synthetic Data?

Production LLMs — even large, capable ones — lack domain-specific knowledge. A base model like SmolLM2-135M-Instruct has learned general English and reasoning patterns, but it has never seen Smile Dental Clinic's treatment menu, INR pricing, or cancellation policy. When a patient asks "How much does a root canal cost at Smile Dental?", the base model either guesses or says it doesn't know.

The traditional fix is to collect real patient interactions and annotate them — but that's slow, expensive, and raises privacy concerns. Instead, we use **synthetic data generation**: we define the clinic's domain knowledge in structured JSON files (treatments, policies, FAQs), then write a script that mechanically generates hundreds of realistic question-answer pairs from those files. This gives us a clean, representative training dataset in minutes.

The generated dataset serves two downstream purposes in this course:
1. **Fine-tuning** (Lab 02) — trains SmolLM2-135M to encode Smile Dental's domain knowledge into its weights
2. **RAG retrieval** (this lab, Part 2) — the same structured JSON files are indexed into FAISS so the retriever can surface relevant context at query time

## What's Provided

The solution code is in `course-code/labs/lab-01/solution/`. Review the key files before running:

| File | Purpose |
|------|---------|
| `tools/synth_data.py` | Reads clinic JSON files, generates JSONL training examples |
| `datasets/clinic/treatments.json` | 12 dental treatments with INR pricing and aftercare |
| `datasets/clinic/policies.json` | 8 clinic policies (booking, payment, cancellation) |
| `datasets/clinic/faqs.json` | 12 patient FAQs with detailed answers |
| `datasets/clinic/doctors.json` | 4 doctors with specializations and weekly availability (used in agent labs) |
| `datasets/clinic/appointments.json` | Mock appointment slots (used in Phase 3 agent labs) |

## Understanding the Clinic Data

Before running the script, spend 5 minutes reading the JSON files. Open `treatments.json` — each treatment looks like:

```json
{
  "code": "TX-RCT-01",
  "name": "Root Canal Treatment",
  "category": "Endodontic",
  "specialist": "Endodontist",
  "price_band_inr": [8000, 15000],
  "duration_minutes": 60,
  "visits": 2,
  "indications": ["severe toothache", "infected pulp", "cracked tooth reaching pulp"],
  "aftercare": [
    "Avoid chewing on treated side for 24 hours",
    "Take prescribed antibiotics if given",
    "Return for crown placement within 2 weeks"
  ]
}
```

Key fields the script uses:
- `price_band_inr` — formatted as "₹8,000 to ₹15,000" in answers
- `indications` — used to generate "Who needs this treatment?" examples
- `aftercare` — used to generate post-treatment care questions
- `specialist` — included in answers so patients know which doctor handles their case

## Understanding synth_data.py

Open `course-code/labs/lab-01/solution/tools/synth_data.py`. The script has three main functions:

**`generate_treatment_examples(treatments)`** — For each treatment, generates 7 Q&A pairs covering price, duration, indications, aftercare, and a general overview. It uses template lists like `PRICE_QUESTIONS` to add variety (e.g., "How much does X cost?" vs "What is the fee for X?").

**`generate_policy_examples(policies)`** — For each policy, generates 4 Q&A pairs using rephrased question templates.

**`generate_faq_examples(faqs)`** — For each FAQ, generates 3 variants: direct question, "I want to know: ...", and "Can you tell me about...".

Each example is formatted as a `messages` dict — the standard format for instruction fine-tuning:

```json
{
  "messages": [
    {"role": "system", "content": "You are a helpful assistant for Smile Dental Clinic, Pune..."},
    {"role": "user",   "content": "How much does Root Canal Treatment cost at Smile Dental Clinic?"},
    {"role": "assistant", "content": "The cost of Root Canal Treatment at Smile Dental Clinic, Pune ranges from ₹8,000 to ₹15,000..."}
  ]
}
```

This three-message format (system → user → assistant) matches the chat template format that SmolLM2-135M-Instruct was originally trained on. The `apply_chat_template` call in `train_lora.py` converts these messages into the exact token sequence the model expects.

## Part 1: Synthetic Data Generation

### Step 1: Copy clinic data and tools to your workspace

From the repository root, copy only what this lab needs — the clinic dataset and the data generation script:

<Tabs groupId="operating-systems">
  <TabItem value="mac" label="macOS / Linux">
  ```bash
  # From the repository root
  cp -r course-code/labs/lab-01/solution/datasets llmops-project/
  cp -r course-code/labs/lab-01/solution/tools llmops-project/
  ```
  </TabItem>
  <TabItem value="win" label="Windows">
  ```powershell
  # From the repository root (PowerShell)
  xcopy /E /I course-code\labs\lab-01\solution\datasets llmops-project\datasets\
  xcopy /E /I course-code\labs\lab-01\solution\tools llmops-project\tools\
  ```
  </TabItem>
</Tabs>

Verify the files are in place:

```bash
ls llmops-project/datasets/clinic/
# Should show: appointments.json  doctors.json  faqs.json  policies.json  treatments.json

ls llmops-project/tools/
# Should show: synth_data.py  requirements.txt
```

### Step 2: Set up Python environment

:::info Install uv (one-time setup)
uv is a fast Python package manager (10-100x faster than pip). Install it once:

<Tabs groupId="operating-systems">
  <TabItem value="mac" label="macOS / Linux">
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```
  </TabItem>
  <TabItem value="win" label="Windows">
  ```powershell
  powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
  ```
  </TabItem>
</Tabs>

If you prefer pip, replace `uv pip install` with `pip install` and `uv venv` with `python -m venv .venv` in all commands below.
:::

Create a virtual environment and activate it:

<Tabs groupId="operating-systems">
  <TabItem value="mac" label="macOS / Linux">
  ```bash
  cd llmops-project
  uv venv
  source .venv/bin/activate
  ```
  </TabItem>
  <TabItem value="win" label="Windows">
  ```powershell
  cd llmops-project
  uv venv
  .venv\Scripts\activate
  ```
  </TabItem>
</Tabs>

:::note
The `synth_data.py` script uses only the Python standard library — no extra packages needed for this part. We'll install the RAG dependencies in Part 2 when they're actually needed.
:::

### Step 3: Review the system prompt

Open `tools/synth_data.py` and find the `SYSTEM_PROMPT` constant at the top:

```python
SYSTEM_PROMPT = (
    "You are a helpful assistant for Smile Dental Clinic, Pune. "
    "Answer questions about dental treatments, pricing (in INR), appointment policies, "
    "and general dental health. Be concise, accurate, and friendly."
)
```

This prompt is prepended to every training example. After fine-tuning, the model will default to this persona — it's a core part of how instruction fine-tuning shapes model behavior.

### Step 4: Generate the training dataset

```bash
python tools/synth_data.py
```

You should see output like:

```
Generated 164 examples → datasets/train/dental_chat.jsonl
```

The script reads from `datasets/clinic/` and writes to `datasets/train/dental_chat.jsonl`.

:::note Time estimate
The script runs in under 5 seconds — it is pure Python with no network calls or model inference. All data is generated deterministically from the JSON files.
:::

### Step 5: Inspect the output

Take a look at the first few examples:

<Tabs groupId="operating-systems">
  <TabItem value="mac" label="macOS / Linux">
  ```bash
  head -1 datasets/train/dental_chat.jsonl | python3 -m json.tool
  ```
  </TabItem>
  <TabItem value="win" label="Windows">
  ```powershell
  Get-Content datasets\train\dental_chat.jsonl -TotalCount 1 | python -m json.tool
  ```
  </TabItem>
</Tabs>

You should see a well-formed messages object. Count total examples:

```bash
wc -l datasets/train/dental_chat.jsonl
```

Expected: **164 lines** (one JSON object per line).

### Verification (Part 1)

Run these checks to confirm the dataset is correct:

```bash
# 1. Count lines (should be 164)
wc -l datasets/train/dental_chat.jsonl

# 2. Confirm first message role is "system"
python3 -c "
import json
with open('datasets/train/dental_chat.jsonl') as f:
    d = json.loads(f.readline())
roles = [m['role'] for m in d['messages']]
print('Message roles:', roles)
assert roles == ['system', 'user', 'assistant'], 'Unexpected structure!'
print('Structure OK')
"

# 3. Confirm Smile Dental appears in answers
python3 -c "
import json
with open('datasets/train/dental_chat.jsonl') as f:
    lines = f.readlines()
dental_count = sum(1 for l in lines if 'Smile Dental' in l)
print(f'Examples mentioning Smile Dental: {dental_count}/{len(lines)}')
"
```

Expected output:
- 164 lines
- Roles: `['system', 'user', 'assistant']`
- Most examples (treatment and policy QAs) mention Smile Dental

---

## Part 2: RAG Retriever

### Why RAG?

Fine-tuning (Lab 02) encodes domain knowledge into model weights — but weights are static. If Smile Dental changes its pricing next month, you'd have to retrain the model. And even a well-fine-tuned model can "hallucinate" specific facts if it wasn't trained on enough examples for a rare topic.

RAG solves this by keeping the authoritative knowledge in a separate database and retrieving the most relevant chunks at query time. The retriever returns 3 clinic documents, those are injected into the prompt as context, and the LLM synthesizes an answer. This means:
- **Accuracy** — the model reads the actual price from the retrieved document instead of relying on its weights
- **Updatability** — change the JSON files, rebuild the index, no retraining needed
- **Transparency** — in Lab 04, students can see exactly which documents were retrieved (glass-box mode)

In this part, we build the retrieval half: a FAISS index backed by sentence embeddings, served through a FastAPI endpoint.

### How FAISS and Sentence Embeddings Work

**fastembed** converts text to a 384-dimensional numeric vector (embedding) using ONNX runtime — lightweight, no PyTorch needed. Semantically similar texts produce vectors that point in similar directions. We use `sentence-transformers/all-MiniLM-L6-v2`, a small but effective model that runs comfortably on CPU.

**FAISS IndexFlatIP** is an inner-product index. Since we normalize all embeddings to unit length (`normalize_embeddings=True`), the inner product equals the cosine similarity — 1.0 means identical, 0 means unrelated. FAISS can search hundreds of vectors in microseconds.

The workflow is:
1. Load treatments + policies + FAQs from JSON → create text chunks
2. Encode each chunk with the embedding model → 384-dim vectors
3. Normalize and add to FAISS IndexFlatIP
4. Save `faiss.index` and `metadata.json` to disk

At query time, the retriever encodes the user's question the same way and searches the index for the top-k most similar chunks.

### Code Walkthrough

The RAG code lives in `course-code/labs/lab-01/solution/rag/` (same code directory as the synth data tools — both are part of Lab 01 in the code repo).

#### build_index.py

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

#### retriever.py

A FastAPI service with three endpoints:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Liveness probe — returns `{"ok": true}` |
| `/search` | POST | Accepts `{"query": str, "k": int}` — returns top-k hits |
| `/metrics` | GET | Prometheus text format — retrieval latency and request counts |

The `/search` handler encodes the query using the same fastembed model as the index build step (critical — mismatched models give wrong scores), then calls `index.search()` and returns the matching chunks with their cosine scores.

### Kubernetes Deployment: initContainer Pattern

A key challenge: the FAISS index must be built before the retriever can serve requests. We solve this with a Kubernetes initContainer:

```
Pod startup:
  initContainer: build-index  →  runs build_index.py  →  writes /data/index/
  main container: retriever   →  starts AFTER init    →  reads /data/index/
```

The `emptyDir` volume is shared between both containers. The initContainer uses `pip install` directly (it runs inside a pod — `uv` is not installed there) + `python build_index.py`, writing `faiss.index` and `metadata.json` to `/data/index/`. Only then does Kubernetes start the `retriever` container, which reads the ready index at startup.

This pattern is used widely in production for one-time setup steps (database migrations, data downloads) that must complete before the main service starts.

### Lab Steps (Part 2)

All commands below assume you are in the **repository root** (where `course-code/` and `llmops-project/` directories are). If you're still inside `llmops-project/` from Part 1:

```bash
cd ..
```

### Step 1: Copy the RAG code into your workspace

The clinic data files from Part 1 are already in `llmops-project/datasets/clinic/`. Now copy the RAG code and K8s manifests:

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

### Verification (Part 2)

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

Artifacts created in `llmops-project/`:

| Artifact | Used By |
|----------|---------|
| `datasets/clinic/treatments.json` | RAG FAISS index (this lab) |
| `datasets/clinic/policies.json` | RAG FAISS index (this lab) |
| `datasets/clinic/faqs.json` | RAG FAISS index (this lab) |
| `datasets/train/dental_chat.jsonl` | Lab 02 (LoRA fine-tuning) |

Running services:

| Resource | Status |
|----------|--------|
| `rag-retriever` Deployment | Running (1/1) |
| `rag-retriever` Service | NodePort 31001 |
| FAISS index | 32 chunks (treatments + policies + FAQs) |

The retriever is used by:
- **Lab 04** (Chainlit UI) — the Chainlit app calls `/search` for every user message and injects the hits into the LLM prompt

**Continue to Lab 02** to fine-tune SmolLM2-135M on the synthetic dataset you generated in this lab.
