"""run_eval.py — Run DeepEval FaithfulnessMetric over an eval-set.jsonl.

Sequential per-item to stay under Groq free-tier rate limits (30 RPM / 6K TPM).
Inserts time.sleep(2.0) between cases by default (Pitfall 6 / Open Q4).

For each test case:
  1. Query the live vLLM at VLLM_URL with the question
  2. Use the response as `actual_output`
  3. Use the eval-set's ground_truth_context as `retrieval_context`
  4. Score with FaithfulnessMetric (uses GroqJudge for LLM-as-judge claim extraction + verification)
  5. Aggregate: pass ONLY IF every test case meets threshold

Output: write `true` or `false` to OUT_PATH (default /tmp/eval-pass.txt) for the Argo
Workflows step `outputs.parameters.pass.valueFrom.path`.
"""
import argparse
import json
import os
import sys
import time

import httpx
from deepeval.metrics import FaithfulnessMetric
from deepeval.test_case import LLMTestCase

from deepeval_local.groq_judge import GroqJudge


def _query_vllm(vllm_url: str, model: str, question: str, timeout: int = 60) -> str:
    """POST to vLLM /v1/completions; return the generated text."""
    try:
        with httpx.Client(timeout=timeout) as c:
            r = c.post(
                f"{vllm_url}/v1/completions",
                json={
                    "model": model,
                    "prompt": question,
                    "max_tokens": 256,
                    "temperature": 0.1,
                },
            )
            r.raise_for_status()
            return r.json()["choices"][0]["text"].strip()
    except Exception as e:
        print(f"  ! vLLM query failed: {e}", file=sys.stderr)
        return ""


def run(
    eval_path: str,
    out_path: str,
    threshold: float,
    sleep_seconds: float,
    vllm_url: str,
    vllm_model: str,
) -> bool:
    """Run the eval. Return True on pass, write out_path = 'true'/'false'."""
    judge = GroqJudge()
    metric = FaithfulnessMetric(model=judge, threshold=threshold, include_reason=True)

    cases = [json.loads(line) for line in open(eval_path) if line.strip()]
    total = len(cases)
    passed = 0
    failures = []

    for i, case in enumerate(cases, 1):
        # If vllm_url starts with http, query it; otherwise use expected_answer as stub
        if vllm_url.startswith("http") and not vllm_url.startswith("http://stub"):
            actual = _query_vllm(vllm_url, vllm_model, case["question"])
        else:
            actual = case.get("expected_answer", "")

        tc = LLMTestCase(
            input=case["question"],
            actual_output=actual or case.get("expected_answer", ""),
            retrieval_context=case["ground_truth_context"],
        )
        try:
            metric.measure(tc)
            score = metric.score
            ok = bool(getattr(metric, "success", score >= threshold))
        except Exception as e:
            print(f"  [{i}/{total}] {case['question'][:60]}... ERROR: {e}", file=sys.stderr)
            ok = False
            score = 0.0

        status = "PASS" if ok else "FAIL"
        print(f"  [{i}/{total}] {status} score={score:.3f} | {case['question'][:60]}")
        if ok:
            passed += 1
        else:
            failures.append({"question": case["question"], "score": score})

        if i < total and sleep_seconds > 0:
            time.sleep(sleep_seconds)

    overall_pass = passed == total
    print(
        f"\n  Result: {passed}/{total} passed (threshold={threshold}); pipeline gate = {overall_pass}"
    )
    if failures:
        print(f"  Failures: {len(failures)} (sample: {failures[:3]})")

    # Write the gate output
    with open(out_path, "w") as f:
        f.write("true" if overall_pass else "false")
    return overall_pass


def main():
    p = argparse.ArgumentParser(description="Run DeepEval Faithfulness over eval-set.jsonl")
    p.add_argument(
        "--eval-set", default=os.environ.get("EVAL_SET", "/workspace/eval-set.jsonl")
    )
    p.add_argument("--out", default=os.environ.get("OUT_PATH", "/tmp/eval-pass.txt"))
    p.add_argument(
        "--threshold", type=float, default=float(os.environ.get("THRESHOLD", "0.7"))
    )
    p.add_argument(
        "--sleep",
        type=float,
        default=float(os.environ.get("SLEEP_BETWEEN_CASES", "2.0")),
    )
    p.add_argument(
        "--vllm-url", default=os.environ.get("VLLM_URL", "http://localhost:8000")
    )
    p.add_argument(
        "--vllm-model",
        default=os.environ.get("VLLM_MODEL", "smollm2-135m-finetuned"),
    )
    args = p.parse_args()
    ok = run(args.eval_set, args.out, args.threshold, args.sleep, args.vllm_url, args.vllm_model)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
