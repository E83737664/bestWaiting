# TODOS — Best Waiting

## Ghost Coach

### T4 — HUD overlay
**What:** NSPanel overlay showing flagged phrase + suggestion, auto-dismisses in 4 seconds.
**Why:** Closes the in-context feedback loop. The log is useful for weekly review but the HUD creates the karaoke moment — you see the correction immediately after dictating.
**Context:** ResultPopup.swift + ResultPopupController already implement NSPanel + NSHostingView with auto-dismiss. HUD is a variation of this pattern. Suppress if LLM response takes >2 seconds (still write to log). Only show for flag=true entries.
**Depends on:** 1 week of production coaching.jsonl data to confirm false-positive rate < 20%.

---

### T5 — Weekly digest
**What:** Read coaching.jsonl and surface top 3 recurring error categories from the past week.
**Why:** After a month of dictation, the log becomes genuinely personalized — not generic advice but your specific recurring patterns (e.g., "you say 'discuss about' 4 times a week").
**Context:** Quick MVP:
```sh
cat ~/Library/Application\ Support/OpenTypeless/coaching.jsonl \
  | python3 -c 'import sys,json; [print(json.loads(l).get("category","null")) for l in sys.stdin if l.strip()]' \
  | sort | uniq -c | sort -rn | head -5
```
A proper UI version would group by category, show example sentences, and compute weekly frequency trends.
**Depends on:** ~1 month of coaching.jsonl entries.

---

### T6 — Pronunciation accuracy analysis
**What:** Score each utterance for pronunciation accuracy, not just phrasing naturalness. Detect mispronounced words, unclear syllables, and common phoneme-level errors (e.g., l/r confusion, -ed/-ing endings, vowel reduction).
**Why:** Ghost Coach currently only catches fluency issues at the word and phrase level. Pronunciation errors are a separate dimension that affects how native speakers perceive the speaker, even when the phrasing is correct.
**How:** Integrate a pronunciation scoring API or local model (e.g., [SpeechSuper](https://www.speechsuper.com/), Azure Cognitive Services Pronunciation Assessment, or wav2vec2-based local model). Score each word and surface low-confidence phonemes in the log alongside the existing fluency analysis.
**Output format addition:**
```json
{
  "pronunciation": {
    "score": 72,
    "words": [
      { "word": "suggest", "score": 45, "issue": "final /t/ dropped" }
    ]
  }
}
```
**Depends on:** T4 HUD (to surface pronunciation feedback in-context).

---

### T7 — Ghost Coach UI
**What:** A dedicated view in the app showing the coaching log — browsable, filterable by category, with the original utterance, detected issue, and suggested correction displayed side by side.
**Why:** The JSONL log is a power-user tool. A UI makes the accumulated data accessible and actionable for everyday review — especially once T5 weekly digest and T6 pronunciation scoring add more dimensions to each entry.
**Key screens:**
- Entry list: timestamp, session app, category badge, one-line issue summary
- Entry detail: original / issue / suggestion / pronunciation score breakdown
- Stats panel: category distribution chart, weekly trend, total entries
**Depends on:** Sufficient log data (T5), pronunciation scoring optional (T6).
