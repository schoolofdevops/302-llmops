# Lab 10 — Autoscaling (Starter)

This starter contains nothing yet — your task is to follow the [Lab 10 guide](../../../../course-content/docs/labs/lab-10-autoscaling.md) and build the autoscaling stack from scratch. Reference the working code in `../solution/` only after you have made an honest attempt yourself.

## First step

Before writing any code, scale vLLM back up (it was scaled to 0 at the end of Lab 06):

```bash
bash ../solution/scripts/00-prereq-scale-vllm-up.sh
```

If this script fails, do not proceed. Check that your KIND cluster is healthy and that the `vllm-smollm2` Deployment still exists in the `llm-serving` namespace.
