---
sidebar_position: 4
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 03: CPU LoRA Fine-Tuning

**Day 1 | Duration: ~60 minutes (15-20 min active + 40 min training wait)**

## Learning Objectives

- Understand what LoRA is and why it enables fine-tuning with minimal compute
- Submit a training job to Kubernetes and monitor its logs
- Understand the merge step — why it's needed for deployment
- Verify the merged model directory is ready for OCI packaging in Lab 04

## What Is Fine-Tuning and Why LoRA?

**Full fine-tuning** updates every parameter in the model. SmolLM2-135M has 135 million parameters — storing full gradients and optimizer states for all of them requires ~4–8 GB of memory even for this small model. On CPU, one training step can take 30–60 seconds.

**LoRA (Low-Rank Adaptation)** is a parameter-efficient alternative. Instead of updating the full weight matrices, LoRA adds small trainable "adapter" matrices to the attention layers. With rank-8 adapters on `q_proj` and `v_proj`, LoRA adds only about **300,000 trainable parameters out of 135 million** — less than 0.3% of the model. Yet during fine-tuning, all the domain-specific learning concentrates in these small adapters.

Why does LoRA work? The original research showed that the "effective rank" of weight updates during fine-tuning is inherently low — meaning a small matrix can capture the adaptation needed. For domain specialization (teaching Smile Dental pricing), this holds strongly: the model doesn't need to restructure its general language understanding, just bias its responses toward dental domain facts.

## Timing — Read This First

:::warning Training time varies by hardware
`MAX_STEPS=50` is set deliberately conservative. At batch_size=1 on CPU, each step takes 6-20 seconds depending on your machine. Total wall time: **5-20 minutes**.

**Instructor tip:** Start the training job, then continue with the slides for the concept section. Come back when the logs show "Training complete". Do not increase MAX_STEPS for the workshop — 50 steps gives a noticeably domain-adapted model with manageable wait time.
:::

## Code Walkthrough

The training code is in `course-code/labs/lab-02/solution/training/`.

### train_lora.py

Key sections to understand:

**Model loading** — `torch.float32` is used instead of `bfloat16`. Some CPU builds handle bfloat16 inconsistently, causing silent precision errors. `float32` is slightly slower but stable on all laptop CPUs:
```python
model = AutoModelForCausalLM.from_pretrained(BASE_MODEL, dtype=torch.float32)
```

**LoRA configuration** — PEFT 0.19.0 stable parameters:
```python
lora_config = LoraConfig(
    r=8,                              # rank — controls adapter size
    lora_alpha=16,                    # scaling factor (alpha/r = 2x)
    target_modules=["q_proj", "v_proj"],  # attention query and value projections
    lora_dropout=0.05,
    bias="none",
    task_type=TaskType.CAUSAL_LM,
)
```

**Training arguments** — CPU-specific flags:
```python
training_args = TrainingArguments(
    max_steps=50,              # conservative for workshop CPUs
    per_device_train_batch_size=1,
    gradient_accumulation_steps=4,  # effective batch = 4 samples
    use_cpu=True,              # Force CPU — KIND nodes have no GPU
    report_to="none",          # no wandb/tensorboard
)
```

**Data format** — `load_and_tokenize()` reads `dental_chat.jsonl` (from Lab 01), applies the model's chat template, and produces `{"input_ids": [...], "labels": [...]}` pairs. The labels equal the input_ids (causal LM training — the model predicts the next token at every position).

### merge_lora.py

After training, the LoRA adapter weights are separate from the base model. For deployment with vLLM, we need a single merged model directory. `merge_and_unload()` mathematically combines the adapter into the base weight matrices:

```
Base model (frozen) + LoRA adapter (trained)  →  Merged model (single weight set)
```

The merged model is a standard HuggingFace model directory that any inference engine can load — no PEFT library required at serving time.

## Lab Steps

All commands assume you are in the **repository root** (`302-llmops/`). If you are still inside `llmops-project/` from Lab 02:

```bash
cd ..
```

### Step 1: Build the training Docker image

The training Job runs inside a container that has PyTorch, transformers, and PEFT pre-installed.

```bash
docker build \
  -t kind-registry:5001/smollm2-trainer:latest \
  course-code/labs/lab-02/solution/training/
```

```bash
docker push kind-registry:5001/smollm2-trainer:latest
```

:::note Build time
First build downloads PyTorch (~1GB). Subsequent builds use cache and take under a minute.
:::

### Step 2: Verify the training data is in place

The training Job mounts `./llmops-project` from your host into the pod at `/mnt/project`. The training data must exist before submitting the job:

```bash
ls llmops-project/datasets/train/dental_chat.jsonl
# Expected: file exists, size ~500KB
```

If the file is missing, go back and run Lab 01 first.

### Step 3: Submit the training Kubernetes Job

```bash
kubectl apply -f course-code/labs/lab-02/solution/k8s/20-job-train-lora.yaml
```

Confirm the Job and Pod are created:

```bash
kubectl get job smollm2-lora-train -n llm-app
kubectl get pods -n llm-app -l job-name=smollm2-lora-train
```

### Step 4: Monitor training logs

:::tip Continue with slides while training runs
The next 15-20 minutes are a good time for the instructor to cover the concept slides on fine-tuning evaluation, LoRA theory, or LLMOps pipelines. The training is fully automated.
:::

Stream the training logs:

```bash
kubectl logs -f job/smollm2-lora-train -n llm-app
```

You will see output like:

```
Base model: HuggingFaceTB/SmolLM2-135M-Instruct
Data path:  /mnt/project/datasets/train/dental_chat.jsonl
Run dir:    /mnt/project/training/runs/run-20260501-143012
Max steps:  50
Loaded 164 training samples
trainable params: 460,800 || all params: 134,975,808 || trainable%: 0.3414
{'loss': '2.883', 'grad_norm': '0.6483', 'learning_rate': '0.0001961', 'epoch': '0.2439'}
{'loss': '2.740', 'grad_norm': '0.6086', 'learning_rate': '0.0001559', 'epoch': '0.4878'}
{'loss': '2.508', 'grad_norm': '0.4254', 'learning_rate': '8.955e-05', 'epoch': '0.7317'}
{'loss': '2.452', 'grad_norm': '0.4338', 'learning_rate': '2.436e-07', 'epoch': '1.22'}
{'train_runtime': '303.9', 'train_loss': '2.617', 'epoch': '1.22'}
Training complete in 304s (5.1 min)
Training complete. Adapter saved to: /mnt/project/training/runs/run-20260501-143012/checkpoint-50
```

Watch the loss decreasing with each log step — this is the model learning to associate dental questions with Smile Dental answers.

### Step 5: Run the merge Job

Once the training Job completes (Pod shows `Completed`), run the merge:

```bash
kubectl get pods -n llm-app -l job-name=smollm2-lora-train
# NAME                          READY   STATUS      RESTARTS
# smollm2-lora-train-xxxxx      0/1     Completed   0
```

Apply the merge Job. First, find the run directory that was created:

<Tabs groupId="operating-systems">
  <TabItem value="mac" label="macOS / Linux">
  ```bash
  # Find the latest run directory
  RUN_DIR=$(ls -t llmops-project/training/runs/ | head -1)
  echo "Latest run: $RUN_DIR"

  # Run merge locally (uses same container image)
  docker run --rm \
    -v "$(pwd)/llmops-project:/mnt/project" \
    -e BASE_MODEL="HuggingFaceTB/SmolLM2-135M-Instruct" \
    -e ADAPTER_PATH="/mnt/project/training/runs/${RUN_DIR}/checkpoint-50" \
    -e MERGED_PATH="/mnt/project/training/merged-model" \
    kind-registry:5001/smollm2-trainer:latest \
    python merge_lora.py
  ```
  </TabItem>
  <TabItem value="win" label="Windows">
  ```powershell
  # Find the latest run directory
  $RUN_DIR = (Get-ChildItem llmops-project\training\runs\ | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
  Write-Host "Latest run: $RUN_DIR"

  # Run merge locally
  docker run --rm `
    -v "${PWD}\llmops-project:/mnt/project" `
    -e BASE_MODEL="HuggingFaceTB/SmolLM2-135M-Instruct" `
    -e ADAPTER_PATH="/mnt/project/training/runs/${RUN_DIR}/checkpoint-50" `
    -e MERGED_PATH="/mnt/project/training/merged-model" `
    kind-registry:5001/smollm2-trainer:latest `
    python merge_lora.py
  ```
  </TabItem>
</Tabs>

The merge takes 2-3 minutes. You'll see the merged model files listed at the end:

```
Merged model saved to: /mnt/project/training/merged-model
Files in merged directory:
  chat_template.jinja                      0.00 MB
  config.json                              0.00 MB
  generation_config.json                   0.00 MB
  model.safetensors                      513.16 MB
  tokenizer.json                           3.36 MB
  tokenizer_config.json                    0.00 MB
```

## Verification

Confirm the merged model directory exists and has the expected files:

```bash
ls -lh llmops-project/training/merged-model/
```

You should see:
- `model.safetensors` (~514 MB — the merged model weights)
- `config.json` — model architecture config
- `tokenizer.json` + `tokenizer_config.json` — tokenizer files

All files must be present for vLLM to load the model in Lab 04.

Optional — run a quick local inference test (requires the venv from Lab 01 with transformers installed):

```bash
cd llmops-project && source .venv/bin/activate
uv pip install transformers torch --quiet
python3 -c "
from transformers import pipeline
pipe = pipeline('text-generation',
    model='training/merged-model',
    max_new_tokens=80)
result = pipe([{'role': 'user', 'content': 'How much does teeth whitening cost?'}])
print(result[0]['generated_text'][-1]['content'])
"
cd ..
```

Expected: a response mentioning Smile Dental Clinic and INR pricing.

:::note Skip this if short on time
The real validation happens in Lab 05 when vLLM serves the model. This local test is optional — it just confirms the merge completed correctly without deploying anything.
:::

## After This Lab

| Artifact | Path | Size |
|----------|------|------|
| LoRA adapter checkpoint | `llmops-project/training/runs/run-*/checkpoint-50/` | ~3 MB |
| Merged model | `llmops-project/training/merged-model/` | ~520 MB |

**Continue to Lab 04** to package the merged model as an OCI container image and push it to the KIND registry.
