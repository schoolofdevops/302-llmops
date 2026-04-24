---
status: awaiting_human_verify
trigger: "Lab 1 dataset generation produces 164 records but lab guide mentions 300+"
created: 2026-04-24T00:00:00Z
updated: 2026-04-24T00:00:00Z
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: CONFIRMED — lab guide contains stale record count (312/300+) that was never valid for current data + script
test: ran synth_data.py; confirmed 164 output; verified math 12*8+8*4+12*3=164
expecting: fix = update lab guide line 148 from "312" to "164" and line 180/187 from "300+" to "164+"
next_action: edit course-content/docs/labs/lab-01-synthetic-data.md to correct the count

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: 300+ records in datasets/train/dental_chat.jsonl
actual: 164 records (wc -l confirms 164)
errors: none — generation completes successfully, structure is valid (system/user/assistant roles OK, all 164 mention Smile Dental)
reproduction: run the data generation script from lab 1, then `wc -l datasets/train/dental_chat.jsonl`
started: discovered during manual lab testing; unclear if this ever produced 300+

## Eliminated
<!-- APPEND only - prevents re-investigating -->

- hypothesis: script has a bug causing under-generation
  evidence: script math is correct: 12 treatments × 8 QA pairs + 8 policies × 4 QA pairs + 12 FAQs × 3 variants = 96+32+36 = 164. No bug.
  timestamp: 2026-04-24

- hypothesis: input data files are incomplete / missing records
  evidence: checked clinic/ dir: treatments.json=12 items, policies.json=8 items, faqs.json=12 items. All fully populated.
  timestamp: 2026-04-24

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-04-24
  checked: course-content/docs/labs/lab-01-synthetic-data.md lines 148, 180, 187
  found: lab guide says "Generated 312 examples" (line 148) and "Expected: **300+ lines**" (lines 180, 187)
  implication: these numbers are stale/wrong; the lab guide was written for a planned dataset that was never built

- timestamp: 2026-04-24
  checked: course-code/labs/lab-01/solution/tools/synth_data.py
  found: script generates 8 QA per treatment (2 price + 2 duration + 2 indication + 1 aftercare + 1 overview), 4 per policy (3 template + 1 direct), 3 per FAQ (direct + 2 rephrases). No use of doctors.json.
  implication: algorithm is well-designed and correct; the 312/300+ figure never matched this algorithm + data combination

- timestamp: 2026-04-24
  checked: course-code/labs/lab-01/solution/datasets/clinic/ directory
  found: 5 JSON files (appointments.json, doctors.json, faqs.json, policies.json, treatments.json). Lab guide mentions doctors.json as a source file but synth_data.py does not read it.
  implication: secondary discrepancy: lab guide lists doctors.json as a script input, but script ignores it

- timestamp: 2026-04-24
  checked: ran `python3 tools/synth_data.py` in solution directory
  found: "Generated 164 examples → datasets/train/dental_chat.jsonl"; wc -l confirms 164
  implication: 164 is the definitive, correct output for the current script + data

- timestamp: 2026-04-24
  checked: arithmetic to reach 312 — no plausible combination of 8/4/3 multipliers with 12/8/12 data items reaches 312
  found: would need 29 treatments + 8 policies + 16 FAQs to hit exactly 312 with current formula
  implication: the 312 figure in the lab guide was written speculatively for a larger planned dataset that was never created

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: The lab guide (course-content/docs/labs/lab-01-synthetic-data.md) contains stale record count claims ("312 examples", "300+ lines") written for a planned dataset configuration that was never built. The actual script + data correctly and deterministically generates exactly 164 records. The script algorithm (8/4/3 QA pairs per treatment/policy/FAQ) applied to 12 treatments + 8 policies + 12 FAQs = 164. No script bug exists.
fix: Update lab guide lines 148, 180, 187 to reflect actual count (164). Also fix the secondary discrepancy: lab guide claims doctors.json is used as a script input, but synth_data.py never reads it.
verification: ran synth_data.py → confirmed 164; updated 4 locations in lab guide from 300+/312 → 164; confirmed no remaining stale count references
files_changed:
  - course-content/docs/labs/lab-01-synthetic-data.md
