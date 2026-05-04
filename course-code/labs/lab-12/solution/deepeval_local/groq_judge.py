"""groq_judge.py — DeepEvalBaseLLM wrapper for Groq's OpenAI-compat endpoint.

Per RESEARCH.md Code Example, Phase 3 already pins Groq llama-3.3-70b-versatile
as LLM_MODEL. DeepEval FaithfulnessMetric makes 2 calls per test case (claim
extraction + verification). Free tier is 30 RPM / 6K TPM — Pitfall 6 / Open Q4
guards against blow-up.
"""
import os

from openai import OpenAI
from deepeval.models import DeepEvalBaseLLM


class GroqJudge(DeepEvalBaseLLM):
    def __init__(self):
        self.client = OpenAI(
            base_url=os.environ["LLM_BASE_URL"],   # https://api.groq.com/openai/v1
            api_key=os.environ["GROQ_API_KEY"],
        )
        self.model_name = os.environ.get("LLM_MODEL", "llama-3.3-70b-versatile")

    def load_model(self):
        return self.client

    def generate(self, prompt: str) -> str:
        r = self.client.chat.completions.create(
            model=self.model_name,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.1,
            max_tokens=1024,
        )
        return r.choices[0].message.content

    async def a_generate(self, prompt: str) -> str:
        return self.generate(prompt)

    def get_model_name(self) -> str:
        return self.model_name
