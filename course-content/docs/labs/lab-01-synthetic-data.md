---
sidebar_position: 2
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 01: Synthetic Data Generation

**Day 1 | Duration: ~30 minutes**

## Learning Objectives

- Understand why domain-specific synthetic data improves fine-tuned LLM quality
- Explore the Smile Dental clinic dataset (treatments, policies, FAQs, doctor schedules)
- Generate a JSONL training dataset from structured JSON clinic data
- Understand the chat format (`messages` array) required for instruction fine-tuning

## Why Synthetic Data?

Production LLMs — even large, capable ones — lack domain-specific knowledge. A base model like SmolLM2-135M-Instruct has learned general English and reasoning patterns, but it has never seen Smile Dental Clinic's treatment menu, INR pricing, or cancellation policy. When a patient asks "How much does a root canal cost at Smile Dental?", the base model either guesses or says it doesn't know.

The traditional fix is to collect real patient interactions and annotate them — but that's slow, expensive, and raises privacy concerns. Instead, we use **synthetic data generation**: we define the clinic's domain knowledge in structured JSON files (treatments, policies, FAQs), then write a script that mechanically generates hundreds of realistic question-answer pairs from those files. This gives us a clean, representative training dataset in minutes.

The generated dataset serves two downstream purposes in this course:
1. **Fine-tuning** (Lab 03) — trains SmolLM2-135M to encode Smile Dental's domain knowledge into its weights
2. **RAG retrieval** (Lab 02) — the same structured JSON files are indexed into FAISS so the retriever can surface relevant context at query time

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

## Lab Steps

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
The `synth_data.py` script uses only the Python standard library — no extra packages needed for this lab. We'll install the RAG dependencies in Lab 02 when they're actually needed.
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

## Verification

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

## After This Lab

Artifacts created in `llmops-project/`:

| Artifact | Used By |
|----------|---------|
| `datasets/clinic/treatments.json` | Lab 02 (RAG FAISS index) |
| `datasets/clinic/policies.json` | Lab 02 (RAG FAISS index) |
| `datasets/clinic/faqs.json` | Lab 02 (RAG FAISS index) |
| `datasets/train/dental_chat.jsonl` | Lab 03 (LoRA fine-tuning) |

**Continue to Lab 02** to build the FAISS index and deploy the RAG retriever — the same clinic JSON files are the input.
