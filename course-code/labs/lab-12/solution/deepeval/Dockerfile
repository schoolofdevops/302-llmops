# DeepEval container for Lab 12 eval step.
# Build context MUST be the solution/ root (not deepeval/ subfolder):
#   docker build -t kind-registry:5001/smile-dental-deepeval:v1.0.0 \
#     -f course-code/labs/lab-12/solution/deepeval/Dockerfile \
#     course-code/labs/lab-12/solution/
# Load into KIND (Pitfall 4 — KIND worker nodes can't pull from localhost:5001):
#   kind load docker-image kind-registry:5001/smile-dental-deepeval:v1.0.0 --name llmops-kind
FROM python:3.11-slim

WORKDIR /app

COPY deepeval/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Source files (deepeval_local package)
COPY deepeval_local/ /app/deepeval_local/
# Eval set baked into image; Argo Workflow can override by mounting /workspace/eval-set.jsonl
COPY eval/eval-set.jsonl /app/eval-set.jsonl

ENV PYTHONPATH=/app
ENV EVAL_SET=/app/eval-set.jsonl
ENV OUT_PATH=/tmp/eval-pass.txt
ENV THRESHOLD=0.7
ENV SLEEP_BETWEEN_CASES=2.0

ENTRYPOINT ["python", "-m", "deepeval_local.run_eval"]
