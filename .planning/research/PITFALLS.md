# Pitfalls Research

**Domain:** LLMOps & AgentOps course with Kubernetes (CPU-only, KIND, Smile Dental scenario)
**Researched:** 2026-04-12
**Confidence:** MEDIUM-HIGH (technical pitfalls verified via official docs and GitHub issues; course design pitfalls from community evidence)

---

## Critical Pitfalls

### Pitfall 1: vLLM CPU KV Cache Misconfiguration Causes Silent OOM

**What goes wrong:**
vLLM's CPU backend defaults `VLLM_CPU_KVCACHE_SPACE` to 4 GiB. A SmolLM2-135M model with a context window over ~32K tokens can require more than 4 GiB of KV cache space at the default settings. The error message surfaces the wrong fix ("increase `gpu_memory_utilization`"), which doesn't apply on CPU. Students see a cryptic failure at serving time — not at build time.

**Why it happens:**
The vLLM CPU backend is a secondary target; its error messages still reference GPU concepts. Documentation for the CPU path is thinner than the GPU path, so students copy GPU-era config examples that don't apply. The 4 GiB default is also underdocumented as a ceiling.

**How to avoid:**
- Pin `VLLM_CPU_KVCACHE_SPACE=2` in all CPU deployment manifests (2 GiB is safe for SmolLM2-135M at the context lengths used in labs).
- Explicitly set `--max-model-len 4096` to bound context and predictably cap KV cache.
- Add a lab validation step that runs `vllm serve --help | grep kvcache` and confirms env vars are set.
- In Lab 04, include a KV cache sizing formula: `KV_GiB ≈ (n_layers × n_heads × head_dim × max_seq_len × 2 × batch_size × dtype_bytes) / 1e9`.

**Warning signs:**
- Pod restarts with OOM killer in `kubectl describe pod` events.
- `dmesg` shows OOM kill for vllm process.
- Error: "The model's max seq len (NNNN) is larger than the maximum number of tokens that can be stored in KV cache."

**Phase to address:** Lab 04 (Model Serving with KServe + vLLM) — must be addressed before any serving lab.

---

### Pitfall 2: Docker Desktop Memory Limit Kills KIND Workloads on 16GB Laptops

**What goes wrong:**
Docker Desktop on macOS defaults to 5 CPUs and 2–4 GB of RAM for its VM — far too little for a KIND cluster running vLLM, KServe, Prometheus, Grafana, and ArgoCD simultaneously. Students hit `Insufficient memory` scheduling errors mid-lab. On Apple Silicon Macs, memory is unified but Docker Desktop's VM still has a hard cap unless manually raised.

**Why it happens:**
Docker Desktop's memory setting is not visible in the cluster or pod logs — it appears only in Docker Desktop's UI preferences. Students don't know to check it. The KIND cluster shows 16 GB of apparent node capacity (it reads host specs), but actual available memory is whatever Docker's VM is capped to.

**How to avoid:**
- Lab 00 prerequisite: explicitly require students to set Docker Desktop → Resources → Memory to at least 12 GB and CPUs to at least 6 before creating the KIND cluster.
- Include a `scripts/preflight-check.sh` that verifies: Docker VM memory via `docker system info | grep Memory`, number of CPUs, and available disk space (>20 GB for images).
- Stage resource-hungry components across labs; don't run full stack in a single namespace without memory estimates.
- In the KIND config, use a 3-node setup only when needed; use 1-node for labs 00–03 where networking is not the focus.

**Warning signs:**
- `0/1 nodes are available: 1 Insufficient memory` in `kubectl get events`.
- Pods stuck in `Pending` with no other explanation.
- `kubectl describe node` shows capacity ≠ allocatable by a large margin.
- Docker Desktop process consuming >90% of host RAM.

**Phase to address:** Lab 00 (Cluster Setup) — prerequisite check must be first step.

---

### Pitfall 3: ImageVolume Feature Gate Silently Fails Without Error

**What goes wrong:**
If the KIND cluster is created without the `ImageVolume: true` feature gate, image volume mounts are silently ignored — the Pod starts, but the model directory is empty. This causes a vLLM "model not found" error that students misdiagnose as a Dockerfile problem or a bad model path.

**Why it happens:**
Kubernetes silently drops unknown or disabled feature gate resources rather than erroring. The Pod appears healthy (`Running`), so students don't look at the kubelet logs. The feature was beta in K8s 1.33 and is not enabled by default.

**How to avoid:**
- The KIND config YAML must include both `featureGates.ImageVolume: true` and `kubeletExtraArgs["feature-gates"]: "ImageVolume=true"`. Document both lines — one without the other doesn't work.
- Add a Lab 00 validation step: `kubectl get nodes -o jsonpath='{.items[0].status.conditions}' | grep Ready` is not enough — run `kubectl apply -f test-imagevolume-pod.yaml` and verify the mount path is populated.
- Pin `kindest/node` to a version where ImageVolume is known-good (v1.34.x confirmed working; test v1.35 before using it).

**Warning signs:**
- Pod is `Running` but vLLM reports "model weights not found" or directory is empty.
- `kubectl exec` into the pod shows `/mnt/model/` is empty.
- No `imagevolume` events in `kubectl describe pod`.

**Phase to address:** Lab 00 (Cluster Setup) and Lab 03 (Model Packaging as OCI image).

---

### Pitfall 4: Cross-Lab Artifact Coupling Creates Cascading Failures

**What goes wrong:**
Lab N+1 depends on an exact file path, image tag, or run ID produced by Lab N. When a student's Lab 02 LoRA training run produces `RUN_ID=abc123` but the Lab 03 Dockerfile hardcodes `RUN_ID=REPLACE_RUN_ID`, all downstream labs (03 → 04 → 07) break with different error messages at different points. Identified directly in CONCERNS.md.

**Why it happens:**
Labs are designed for sequential completion, but students skip steps, re-run labs with different outputs, or join mid-workshop. The current course has no artifact abstraction layer — every cross-lab reference is a hardcoded string.

**How to avoid:**
- Use a central `config.env` at repo root that all manifests source: `MODEL_IMAGE_TAG`, `RUN_ID`, `REGISTRY_USER`, `CLUSTER_NAME`, `NAMESPACE`.
- `scripts/setup.sh` reads `config.env` and patches all manifests via `envsubst`.
- Provide pre-built artifacts (merged model OCI image, FAISS index) on a public registry for each lab, so students can jump in at any point.
- Each lab's starter/ directory should include the expected artifacts from the previous lab so it is self-contained.
- Add a `scripts/reset-lab-N.sh` for each lab that restores a clean state.

**Warning signs:**
- `REPLACE_` or `xxxxxx` strings appearing in `kubectl describe` events.
- Image pull errors with `initcron/` or `<you>` in the image reference.
- Students on step 4 of Lab 05 asking why Lab 02 failed.

**Phase to address:** Course Infrastructure phase (before any lab is rewritten) — the artifact management pattern must be decided first.

---

### Pitfall 5: Kubernetes Agent Sandbox v1alpha1 API Breaking Changes

**What goes wrong:**
Agent Sandbox is at v1alpha1 (as of April 2026, latest release v0.3.10). The v0.2.1 release introduced three breaking changes: controller moved from StatefulSet to Deployment requiring manual delete before upgrade; metrics port changed from 80 to 8080; network isolation changed to "block by default." Any student running an older sandbox version will hit incompatible manifests with confusing errors.

**Why it happens:**
Alpha APIs change frequently without deprecation windows. If course manifests are pinned to an older API shape, they fail against a freshly installed sandbox controller. The Python SDK version must exactly match the controller version.

**How to avoid:**
- Pin agent-sandbox controller version explicitly in all lab manifests: `kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/download/v0.3.10/install.yaml`.
- Pin the Python SDK in requirements.txt to the matching version: `agent-sandbox==0.3.10`.
- In the Agent Sandbox lab, begin with an "API stability disclaimer": explain this is v1alpha1 and how to check if the course pinned version matches what is installed.
- Test the lab against the pinned version, not HEAD.
- Include a migration note for v0.2.1+ network isolation: sandboxes block internal cluster by default, so the dental assistant agent must have explicit egress policy to reach the vLLM service.

**Warning signs:**
- `no matches for kind "Sandbox" in version "sandbox.x-k8s.io/v1alpha1"` means CRD is not installed or mismatched.
- Agent pod connects but gets 403 or network timeout reaching vLLM service.
- `agent-sandbox` Python SDK throws `AttributeError` on Sandbox lifecycle methods — SDK/controller version mismatch.

**Phase to address:** Agent Sandbox lab (new module) — must pin versions at lab authoring time and retest before each course delivery.

---

### Pitfall 6: CPU LoRA Fine-Tuning Is Slow Enough to Kill a Workshop

**What goes wrong:**
LoRA fine-tuning of SmolLM2-135M on CPU with the existing PyTorch stack (torch==2.3.1, peft==0.12.0) takes 30–120 minutes per epoch on typical laptops. A 3-day workshop that asks students to wait 90 minutes for training loses the room. Students also leave training running overnight and arrive with failed jobs due to system sleep or screensavers.

**Why it happens:**
PyTorch CPU training is not optimized the way GPU training is. The course was apparently designed around this model size for memory reasons, but wall-clock training time was not validated on the minimum-spec laptop (16GB, no GPU).

**How to avoid:**
- Reduce the training dataset to 200–500 synthetic examples maximum (dental FAQ data is small enough). Validate training completes in under 15 minutes on 4 CPU cores.
- Provide a pre-trained checkpoint that students can use if training is "too slow" — treat training as "run it in background, we'll come back."
- Pin `torch` to a version with Intel MKL CPU optimization enabled (the default `pip install torch` wheel includes MKL on x86_64). Verify this explicitly in Lab 02.
- Add `--max-steps 50` as a default training flag during class; full training is an "optional exercise."
- Prevent sleep during training: add a lab note to disable sleep, or provide `caffeinate` (macOS) command.

**Warning signs:**
- Training time estimate in `tqdm` shows 2+ hours remaining.
- Students' machines throttle after 10+ minutes of CPU load (fan noise, thermal warning).
- `torch.backends.mkl.is_available()` returns False (training will be 5–10x slower without MKL).

**Phase to address:** Lab 02 (CPU LoRA Fine-Tuning) — validate timing on minimum-spec hardware before course delivery.

---

### Pitfall 7: Agent Tool-Calling Breaks on Small Models

**What goes wrong:**
SmolLM2-135M is not instruction-tuned or RLHF-aligned for tool-calling / function-calling JSON schemas. When the agentic lab adds tool definitions (appointment booking, treatment lookup), the model produces malformed JSON, calls non-existent tools, or hallucinates tool arguments. This is not a bug — it is a fundamental capability gap. Students blame their code.

**Why it happens:**
Tool-calling relies on the model understanding a structured prompt format (OpenAI function calling schema, or similar) and producing valid JSON. A 135M parameter base model does not have this capability. Even instruction-tuned variants at this scale are unreliable.

**How to avoid:**
- Decouple the agent framework from the model size concern. For the agentic labs, either:
  a. Use a cloud-hosted model API (OpenAI, Anthropic) as the LLM backend for agent reasoning, while keeping the fine-tuned SmolLM2 for RAG retrieval.
  b. Use a larger quantized model (e.g., Qwen2.5-1.5B-Instruct in GGUF format via llama.cpp) that has basic tool-calling capability on CPU.
- Do NOT attempt function-calling demonstrations with the fine-tuned SmolLM2-135M — frame it explicitly as a retrieval/generation model, not a reasoning agent.
- In the agentic lab, use deterministic tool dispatch (keyword routing or code-based dispatch) rather than relying on LLM function selection. This is also more educational — students learn that not all agent logic needs an LLM.
- Document the model capability gap in the lab intro: "SmolLM2 powers RAG; a larger model powers agent reasoning."

**Warning signs:**
- Model output includes broken JSON: `{"tool": "book_appoint` (truncated).
- Tool call succeeds but with hallucinated parameters: `{"patient_id": "12345"}` when no such patient exists.
- Infinite loops where the agent retries a failed tool call 20+ times.

**Phase to address:** Agentic module design phase — architecture decision about which model handles agent reasoning must be made before coding starts.

---

### Pitfall 8: KServe + vLLM on CPU Is Not First-Class — Expect Rough Edges

**What goes wrong:**
vLLM's own documentation states it is "not intended for CPU-based inference and has not been optimized for CPU performance." KServe's LLM serving story (InferenceService + vLLM runtime) is GPU-centric. The CPU vLLM image is a community addition (`kserve-vllm-cpu`) that has fewer guarantees than the GPU path. Students hit probe failures, slow startup times (2–5 minutes for model loading), and missing health-check configurations.

**Why it happens:**
The existing course Lab 04 makes vLLM + KServe on CPU work, but it requires specific resource annotations, `VLLM_CPU_KVCACHE_SPACE` env vars, and relaxed readiness probe initial delays. None of these are in the default KServe YAML examples.

**How to avoid:**
- Maintain a tested, working `InferenceService` YAML for CPU vLLM in the course repo. Do not have students write this from scratch — give it as a starter and explain each annotation.
- Set `readinessProbe.initialDelaySeconds: 120` (model loading takes 60–180 seconds on CPU).
- Set `livenessProbe.failureThreshold: 10` to avoid premature restarts during slow startup.
- Test the exact KServe and vLLM image version combination before each course delivery — a minor KServe upgrade can break the CPU runtime image reference.
- If KServe CPU vLLM proves too fragile, fall back to a plain Kubernetes Deployment + Service for vLLM serving, and use KServe only for conceptual illustration. Educational value comes from understanding the pattern, not requiring it to be production-grade.

**Warning signs:**
- `InferenceService` stays in `Unknown` state for more than 5 minutes.
- `kubectl describe inferenceservice` shows `Revision not ready`.
- `kubectl logs` for the vLLM container shows `RuntimeError: Failed to load model`.
- Readiness probe fails before model finishes loading (`Back-off restarting failed container`).

**Phase to address:** Lab 04 (Model Serving) — validate end-to-end before lab is written, not after.

---

### Pitfall 9: Labs with Copy-Paste Walls Get Negative Udemy Reviews

**What goes wrong:**
The existing course (Lab 01, 1401 lines; Lab 05, 954 lines) has long inline code blocks students must manually type or copy. Udemy reviews consistently cite "outdated code that doesn't work" and "too much copy-paste." When the code has even one typo or version mismatch, students spend hours on a problem that isn't pedagogical. This is one of the highest correlating factors for 1-star reviews on technical Udemy courses.

**Why it happens:**
Course authors write documentation first and then realize they need code too — so they inline it. Copy-pasting from PDF/browser into terminals introduces smart quotes, missing newlines, and invisible Unicode characters.

**How to avoid:**
- The companion repo starter/solution structure eliminates copy-paste walls entirely — this is already planned and is the single most important course improvement.
- Each lab step that requires a code file should say "open `starter/lab-NN/filename.py`" not paste this 200-line block.
- Long YAML manifests (KServe InferenceService, KIND config) go in the repo, not in docs. Docs explain the key fields, not the whole file.
- Docusaurus's MDX supports `CodeBlock` with a `file` reference — use it to pull from the repo rather than duplicating code in docs.
- Add a "What you'll type" vs "What you'll read" distinction — terminal commands are typed, config files are opened from starter/.

**Warning signs:**
- Any lab section with 50+ lines of continuous code block in docs.
- Lab instructions that say "replace X with Y in the above YAML."
- Student forum questions about indentation errors in YAML they copied.

**Phase to address:** Course Infrastructure phase — the companion repo structure must exist before any lab is written or rewritten.

---

### Pitfall 10: Version Pinning Becomes a Time Bomb

**What goes wrong:**
The existing course pins `torch==2.3.1`, `transformers==4.43.3`, `peft==0.12.0` (from CONCERNS.md). These become incompatible as transitive dependencies update. Students installing in 2026 on new machines get dependency resolution failures or subtle behavior changes. The course also pins `kindest/node:v1.34.0` — if a student has v1.35 already and can't roll back, Lab 00 fails.

**Why it happens:**
Authors pin versions at authoring time to get reproducibility. They don't plan for forward compatibility or document why specific versions were chosen.

**How to avoid:**
- Use lockfiles everywhere: `requirements.txt` pinned, but also provide `pip install --constraint constraints.txt` so students can understand which versions are locked for compatibility vs. convenience.
- Document the compatibility reason for each pin: `torch==2.3.x # CPU wheel with MKL; 2.4+ changed LoRA optimizer state dict format`.
- Provide a `scripts/verify-env.sh` that checks installed versions against expected ranges and warns if they diverge.
- For Kubernetes, pin to minimum version (`kindest/node:v1.34+`), not exact patch — students can use v1.34.0, v1.34.1, or v1.34.2 and all should work.
- Add a `COURSE_VERSIONS.md` at repo root listing the tested combination: KIND version, K8s version, vLLM version, KServe version, agent-sandbox version. Update this before each workshop delivery.
- Set up a GitHub Actions CI that runs Lab 00 and Lab 04 end-to-end monthly to catch breakage.

**Warning signs:**
- `pip install` resolves to a different version than pinned and prints a compatibility warning.
- `ImportError` or `AttributeError` on a method that exists in training docs but not in installed version.
- `kubectl apply` fails with "unknown field" — Kubernetes API version drift.

**Phase to address:** Course Infrastructure phase — lockfiles and version documentation before any lab is written.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Inline code in docs instead of starter repo | Faster to write | Copy-paste errors, broken on version bump, 1-star reviews | Never for this course |
| Hardcoded `REPLACE_RUN_ID` placeholders | No setup script needed | Students miss substitutions, cascading failures | Never — use `config.env` + `envsubst` |
| External gist for lab files | Quick sharing | Single point of failure, breaks offline | Never — inline or commit to repo |
| Happy-path-only lab instructions | Faster to write | Students stuck, high support load, negative reviews | Never for Udemy |
| No Docker Desktop prereq check | Faster lab start | Students fail mid-lab due to OOM, waste 30+ minutes | Never |
| Using SmolLM2-135M for agent tool-calling | Consistent with fine-tuning lab | Model lacks capability, non-pedagogical failures | Never — use correct model for each task |
| Floating version tags (`:latest`) for images | Always current | Non-reproducible, breaks between runs | Never in lab manifests |
| Single sequential lab path, no jump-in points | Simpler course design | Late joiners blocked, lost students in multi-day workshop | Acceptable only if pre-built artifacts provided |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| vLLM + KServe CPU | Use default InferenceService YAML (GPU-oriented) | Pin CPU-specific image tag, set large initialDelaySeconds, set `VLLM_CPU_KVCACHE_SPACE` |
| KIND + ImageVolumes | Enable only `featureGates.ImageVolume: true` in cluster config | Must also set `kubeletExtraArgs["feature-gates"]: "ImageVolume=true"` |
| Agent Sandbox + vLLM service | Default network isolation blocks egress | Explicitly define NetworkPolicy allowing Sandbox pods to reach vLLM ClusterIP |
| ArgoCD + GitHub | Pass PAT on CLI (`--password <token>`) | Use SSH key or ArgoCD interactive mode; never plain-text credentials on CLI |
| FAISS + RAG | Build index inside Python script, no persistence | Serialize FAISS index to disk and commit as lab artifact; loading is 10x faster than rebuilding |
| LangGraph + small model | Route all agent decisions through SmolLM2 | Use LangGraph's conditional edges with deterministic routing for tool dispatch; reserve LLM for generation only |
| KServe + KIND networking | Use `IngressClass` from cloud docs | KIND has no LoadBalancer; use NodePort or port-forward for all lab demos |
| Docker Desktop + KIND | Default VM memory (2–4 GB) | Require explicit Docker Desktop settings: 12 GB RAM, 6 CPUs before Lab 00 |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| vLLM CPU with default batch size on 2-core limit | First query takes 30+ seconds | Set `--max-num-seqs 1` for demo purposes; explain this is not production tuning | Any concurrent query load |
| FAISS index rebuild on every notebook restart | Lab 01 takes 5+ minutes to "start" | Persist index with `faiss.write_index()` in lab artifacts | Every time student re-runs notebook |
| Full Prometheus + Grafana stack in KIND on 16GB | System unresponsive, swap thrashing | Use minimal Prometheus scrape interval (60s), disable unused exporters | When running alongside vLLM pod |
| ArgoCD + Argo Workflows simultaneously | Node memory exhausted | Stage labs — don't run Labs 07 and 08 simultaneously on the same cluster | Any 2-Argo lab combo |
| SmolLM2 LoRA training with batch_size > 4 | Training OOM on CPU | Set `per_device_train_batch_size=1`, `gradient_accumulation_steps=4` in training config | Batch size >= 8 on 16GB |
| KIND cluster with 3 nodes on macOS | 3x container memory overhead | Use 1 worker node for non-networking labs; 3-node only for HA/scaling labs | Under Docker Desktop 12GB limit |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| GitHub PAT on argocd CLI (`--password <token>`) | Token in shell history, process list, and lab screenshots | Use SSH key auth or credential store; add warning in lab |
| Grafana default credentials documented in plaintext | Published course exposes admin credentials | Reference upstream default creds doc; require password change as lab step |
| Agent Sandbox with permissive network policy | Agent can reach any cluster service including secrets | Use the v0.2.1+ default "block all egress" and explicitly allow only required services |
| vLLM `/v1/chat/completions` unauthenticated in KIND | Any process in cluster can call the model endpoint | For labs, document this explicitly as "demo-only, not production"; show how to add AuthorizationPolicy in observability lab |
| `--insecure-ignore-host-key` in ArgoCD setup | Disables SSH host key verification, MITM risk | Use `ssh-keyscan github.com >> ~/.ssh/known_hosts` before repo add |

---

## UX Pitfalls (Course Design)

| Pitfall | Student Impact | Better Approach |
|---------|----------------|-----------------|
| No validation step at end of each lab | Students proceed with broken state; Lab N+3 fails mysteriously | End every lab with a "Validation Checklist" of copy-paste commands with expected output |
| Training runs during synchronous workshop time | 30+ minutes of dead air, students disengage | Kick off training, switch to concept slides, return when done — treat as async background task |
| Labs require full sequential completion | Students who miss Lab 02 can't do Labs 03–08 | Provide pre-built artifacts at each lab entry point; allow jump-in |
| No troubleshooting section | Students block on common errors, flood Slack/forums | Dedicated troubleshooting section in each lab covering top 3 known failures with exact error messages |
| Section 1 of lab is 15+ minutes of setup | Momentum lost before any interesting work | Move cluster/namespace setup to Lab 00 and reference in later labs; each lab starts with something that works |
| Single giant lab file (1400 lines) | Hard to navigate, hard to point to specific sections | Split into sub-labs (01a, 01b); Docusaurus TOC auto-generates from headings |
| Code explained after students type it | Students type without understanding, then get confused | Explain the key concept, then give the code, then explain what happened |

---

## "Looks Done But Isn't" Checklist

- [ ] **Lab 00 cluster setup:** Confirm ImageVolume feature gate works — run `test-imagevolume.yaml`, verify mount is populated, not just that Pod is Running.
- [ ] **Lab 02 training:** Confirm training completes in under 20 minutes on a 4-core machine with MKL. Don't just verify it starts.
- [ ] **Lab 03 model packaging:** Confirm the OCI image mounts correctly in KIND and model files are accessible at the expected path.
- [ ] **Lab 04 serving:** Confirm vLLM responds to `/v1/chat/completions` with a valid dental answer, not just that the endpoint returns HTTP 200.
- [ ] **Lab 07 ArgoCD:** Confirm GitOps sync actually deploys a changed manifest, not just that ArgoCD UI shows green.
- [ ] **Agent Sandbox lab:** Confirm the agent can reach the vLLM service through the network policy — test tool-calling end-to-end, not just sandbox creation.
- [ ] **Companion repo starter code:** Confirm each `starter/lab-NN/` directory runs without modification on a fresh clone (no `REPLACE_` strings, no missing files).
- [ ] **Cross-lab artifacts:** Confirm a student can start at Lab 04 using provided pre-built artifacts without completing Labs 01–03.
- [ ] **Docusaurus search:** Confirm DocSearch indexes all lab pages and returns results for "vLLM" and "KServe."
- [ ] **Version pinning:** Confirm `pip install -r requirements.txt` on a fresh virtualenv resolves without conflicts on macOS ARM and x86_64.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| vLLM OOM on KV cache | LOW | Set `VLLM_CPU_KVCACHE_SPACE=2`, `--max-model-len 4096`, redeploy pod |
| Docker Desktop memory too low | LOW | Adjust Docker Desktop settings, restart Docker, delete and recreate KIND cluster |
| ImageVolume feature gate missing | MEDIUM | Destroy cluster with `kind delete cluster`, recreate with corrected config YAML |
| Cross-lab artifact mismatch | MEDIUM | Run `scripts/reset-lab-N.sh`, or download pre-built artifact for that lab checkpoint |
| Agent Sandbox version mismatch | MEDIUM | Uninstall with `kubectl delete -f install.yaml`, reinstall pinned version, recreate Sandbox CRDs |
| Training too slow to finish in class | LOW | Kill training, load pre-trained checkpoint: `model = PeftModel.from_pretrained(base, "starter/lab02/checkpoint-50")` |
| vLLM + KServe probe failures | MEDIUM | Patch `initialDelaySeconds: 180`, delete and recreate InferenceService |
| Version dependency conflict | HIGH | Use provided Docker container (`docker pull course-env:lab02`) as guaranteed clean environment |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| vLLM CPU KV cache OOM | Lab 04 authoring | Run vLLM with `--max-model-len 4096` and verify healthy response |
| Docker Desktop memory limits | Lab 00 authoring | Preflight script returns green on 12GB Docker Desktop |
| ImageVolume feature gate silent fail | Lab 00 authoring | test-imagevolume.yaml pod shows mounted files |
| Cross-lab artifact coupling | Course Infrastructure (before labs) | Student can run lab 04 with pre-built artifacts from scratch |
| Agent Sandbox API breaking changes | Agent module authoring | All Sandbox manifests use pinned v0.3.10, end-to-end test passes |
| LoRA training too slow | Lab 02 authoring | Training completes in <20 min on 4-core CPU laptop |
| Agent tool-calling on 135M model | Agentic module design | Architecture decision documented: separate models for retrieval vs. reasoning |
| KServe CPU rough edges | Lab 04 authoring | InferenceService reaches Ready state within 3 minutes |
| Copy-paste walls | Course Infrastructure (before labs) | No lab has >20 continuous lines of code inline in docs |
| Version pinning time bomb | Course Infrastructure (before labs) | CI job runs pip install and verifies all labs end-to-end monthly |

---

## Sources

- vLLM CPU backend docs: https://docs.vllm.ai/en/stable/getting_started/installation/cpu/
- vLLM conserving memory docs: https://docs.vllm.ai/en/latest/configuration/conserving_memory/
- vLLM GitHub issue #29233 (CPU KV cache default too small): https://github.com/vllm-project/vllm/issues/29233
- Kubernetes Agent Sandbox GitHub releases (v0.3.10, breaking changes in v0.2.1): https://github.com/kubernetes-sigs/agent-sandbox/releases
- Kubernetes blog: Running Agents with Agent Sandbox (March 2026): https://kubernetes.io/blog/2026/03/20/running-agents-on-kubernetes-with-agent-sandbox/
- KServe vLLM CPU issue #5334 (llama.cpp for CPU): https://github.com/kserve/kserve/issues/5334
- KIND ImageVolume feature gate issue #3745: https://github.com/kubernetes-sigs/kind/issues/3745
- Arize AI: Common AI Agent Failure Modes: https://arize.com/blog/common-ai-agent-failures/
- Docker Desktop macOS memory configuration: https://oneuptime.com/blog/post/2026-02-08-how-to-configure-docker-desktop-memory-and-cpu-limits-on-macos/view
- Udemy quality review process: https://support.udemy.com/hc/en-us/articles/229605348-Udemy-s-Quality-Review-Process
- SkyPrep: 15 Online Course Design Mistakes: https://skyprep.com/2024/05/03/15-online-course-design-mistakes-that-ruin-engagement-and-metrics/
- FAISS scalability issues (GitHub issue #2809 excessive memory): https://github.com/facebookresearch/faiss/issues/2809
- Project codebase analysis: `.planning/codebase/CONCERNS.md` (direct evidence of current pitfalls in existing labs)

---
*Pitfalls research for: LLMOps & AgentOps with Kubernetes course (Smile Dental scenario)*
*Researched: 2026-04-12*
