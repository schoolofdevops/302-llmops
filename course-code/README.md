# LLMOps & AgentOps with Kubernetes — Companion Code

Companion code repository for the course. Each lab has a `starter/` and `solution/` directory.

## Student Workflow

1. Copy files from `labs/lab-NN/starter/` into your working directory
2. Follow the lab instructions on the course site
3. Compare your result with `labs/lab-NN/solution/` when finished

If you fall behind, copy `labs/lab-NN+1/starter/` into your workspace and resume from the next lab.

## Repository Structure

```
labs/
  lab-00/   # Cluster Setup
    starter/  # Template files with REPLACE placeholders
    solution/ # Fully working reference files
  lab-01/   # Synthetic Data Generation
  ...
  lab-13/   # Capstone Exercise
shared/
  k8s/      # Shared Kubernetes manifests (namespaces, etc.)
  scripts/  # Shared cleanup scripts for resource management
config.env  # Central artifact configuration (edit before starting)
COURSE_VERSIONS.md  # Pinned dependency versions for this course
```

## Prerequisites

See the [course site prerequisites page](https://llmops.schoolofdevops.com/docs/setup/prerequisites) for installation instructions.
Run `labs/lab-00/starter/scripts/preflight-check.sh` (macOS/Linux) or `preflight-check.ps1` (Windows) before starting.
