#!/usr/bin/env python3
"""
synth_data.py — Generate Smile Dental JSONL fine-tuning dataset from clinic data files.

Reads: datasets/clinic/treatments.json, policies.json, faqs.json
Writes: datasets/train/dental_chat.jsonl

Each output line: {"messages": [{"role": "system", ...}, {"role": "user", ...}, {"role": "assistant", ...}]}

Usage:
    python synth_data.py
    DATA_DIR=datasets/clinic OUTPUT_DIR=datasets/train python synth_data.py
"""
import json, os, random
from pathlib import Path
from typing import List, Dict, Any

# --- Configuration ---
DATA_DIR = Path(os.environ.get("DATA_DIR", "datasets/clinic"))
OUTPUT_DIR = Path(os.environ.get("OUTPUT_DIR", "datasets/train"))
SYSTEM_PROMPT = (
    "You are a helpful assistant for Smile Dental Clinic, Pune. "
    "Answer questions about dental treatments, pricing (in INR), appointment policies, "
    "and general dental health. Be concise, accurate, and friendly."
)

# ---- Q&A rephrase templates for variety ----
PRICE_QUESTIONS = [
    "How much does {name} cost at Smile Dental Clinic?",
    "What is the price of {name}?",
    "What is the cost of {name} in Pune?",
    "How much will I need to pay for {name}?",
    "Can you tell me the fee for {name}?",
]

DURATION_QUESTIONS = [
    "How long does {name} take?",
    "What is the duration of {name}?",
    "How many sessions are required for {name}?",
    "How many visits does {name} require?",
    "How much time should I set aside for {name}?",
]

INDICATION_QUESTIONS = [
    "Who needs {name}?",
    "When is {name} recommended?",
    "What are the indications for {name}?",
    "What conditions require {name}?",
    "When would a dentist suggest {name}?",
]

AFTERCARE_QUESTIONS = [
    "What should I do after {name}?",
    "What are the aftercare instructions for {name}?",
    "How do I care for my teeth after {name}?",
    "What precautions should I take after {name}?",
]

POLICY_QUESTIONS = [
    "What is the {category} policy at Smile Dental Clinic?",
    "Can you explain the {category} policy?",
    "Tell me about your {category} policy.",
    "What should I know about {category} at Smile Dental Clinic?",
    "How does Smile Dental handle {category_lower}?",
]


def build_example(user: str, assistant: str) -> dict:
    """Return a single chat training example as a messages dict."""
    return {
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user},
            {"role": "assistant", "content": assistant},
        ]
    }


def _format_inr_range(price_band: List[int]) -> str:
    """Format price band as a readable INR string."""
    low, high = price_band
    return f"₹{low:,} to ₹{high:,}"


def generate_treatment_examples(treatments: List[Dict[str, Any]]) -> List[dict]:
    """Generate Q&A examples from treatments.json (price, duration, indications, aftercare)."""
    examples = []
    for t in treatments:
        name = t["name"]
        price_str = _format_inr_range(t["price_band_inr"])
        category = t["category"]
        specialist = t["specialist"]
        duration = t["duration_minutes"]
        visits = t["visits"]
        indications = t["indications"]
        aftercare = t["aftercare"]

        # --- Price Q&A ---
        price_ans = (
            f"The cost of {name} at Smile Dental Clinic, Pune ranges from {price_str}. "
            f"The exact price depends on the complexity of your case. "
            f"Please contact us for a personalised estimate after your consultation."
        )
        for q_tmpl in random.sample(PRICE_QUESTIONS, k=2):
            examples.append(build_example(q_tmpl.format(name=name), price_ans))

        # --- Duration Q&A ---
        duration_ans = (
            f"{name} typically takes about {duration} minutes per session and usually requires {visits} visit(s). "
            f"Your {specialist} at Smile Dental Clinic will give you a more precise timeline during your consultation."
        )
        for q_tmpl in random.sample(DURATION_QUESTIONS, k=2):
            examples.append(build_example(q_tmpl.format(name=name), duration_ans))

        # --- Indications Q&A ---
        ind_list = "; ".join(indications)
        indication_ans = (
            f"{name} is typically recommended for patients with the following conditions: {ind_list}. "
            f"A {specialist} at Smile Dental Clinic will assess your specific situation during your consultation."
        )
        for q_tmpl in random.sample(INDICATION_QUESTIONS, k=2):
            examples.append(build_example(q_tmpl.format(name=name), indication_ans))

        # --- Aftercare Q&A ---
        aftercare_list = ". ".join(aftercare)
        aftercare_ans = (
            f"After {name}, it is important to follow these steps: {aftercare_list}. "
            f"If you experience unusual pain or swelling, please contact Smile Dental Clinic promptly."
        )
        for q_tmpl in random.sample(AFTERCARE_QUESTIONS, k=1):
            examples.append(build_example(q_tmpl.format(name=name), aftercare_ans))

        # --- General overview Q&A ---
        overview_q = f"Tell me about {name} at Smile Dental Clinic."
        overview_ans = (
            f"{name} is a {category} procedure performed by our {specialist} at Smile Dental Clinic, Pune. "
            f"It is indicated for: {ind_list}. "
            f"The procedure takes approximately {duration} minutes with {visits} visit(s) required. "
            f"Cost ranges from {price_str}. "
            f"After treatment: {aftercare_list}."
        )
        examples.append(build_example(overview_q, overview_ans))

    return examples


def generate_policy_examples(policies: List[Dict[str, Any]]) -> List[dict]:
    """Generate Q&A examples from policies.json."""
    examples = []
    for p in policies:
        category = p["category"]
        title = p["title"]
        details = p["details"]

        for q_tmpl in random.sample(POLICY_QUESTIONS, k=3):
            q = q_tmpl.format(
                category=category,
                category_lower=category.lower(),
            )
            examples.append(build_example(q, details))

        # Also add a direct question using the policy title
        direct_q = f"What is your {title}?"
        examples.append(build_example(direct_q, details))

    return examples


def generate_faq_examples(faqs: List[Dict[str, Any]]) -> List[dict]:
    """Generate Q&A examples from faqs.json (direct and slightly rephrased)."""
    examples = []
    for faq in faqs:
        question = faq["question"]
        answer = faq["answer"]

        # Direct Q&A
        examples.append(build_example(question, answer))

        # Rephrase with "I want to know..."
        rephrased = f"I want to know: {question}"
        examples.append(build_example(rephrased, answer))

        # Rephrase with "Can you tell me..."
        rephrased2 = f"Can you tell me about this: {question}"
        examples.append(build_example(rephrased2, answer))

    return examples


def main():
    """Load clinic data and generate JSONL training examples."""
    # --- Load data files ---
    treatments_path = DATA_DIR / "treatments.json"
    policies_path = DATA_DIR / "policies.json"
    faqs_path = DATA_DIR / "faqs.json"

    with open(treatments_path, encoding="utf-8") as f:
        treatments = json.load(f)
    with open(policies_path, encoding="utf-8") as f:
        policies = json.load(f)
    with open(faqs_path, encoding="utf-8") as f:
        faqs = json.load(f)

    # --- Generate examples from each source ---
    examples: List[dict] = []
    examples.extend(generate_treatment_examples(treatments))
    examples.extend(generate_policy_examples(policies))
    examples.extend(generate_faq_examples(faqs))

    # Shuffle for training diversity
    random.seed(42)
    random.shuffle(examples)

    # --- Write output ---
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / "dental_chat.jsonl"
    with open(output_path, "w", encoding="utf-8") as f:
        for ex in examples:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")

    print(f"Generated {len(examples)} examples → {output_path}")


if __name__ == "__main__":
    main()
