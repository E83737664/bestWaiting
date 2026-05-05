# TODOS — OpenTypeless

## Ghost Coach (CoachingService)

### T4 — HUD overlay (Week 2)
**What:** NSPanel overlay showing flagged phrase + suggestion, auto-dismisses in 4 seconds.
**Why:** Closes the in-context feedback loop. The log is useful for weekly review but the HUD creates the karaoke moment — you see the correction immediately after dictating.
**Pros:** Real-time feedback makes the coaching actionable. No separate app to open.
**Cons:** Noisy until prompt false-positive rate is confirmed low. Need 1 week of log data before shipping.
**Context:** ResultPopup.swift + ResultPopupController already implement NSPanel + NSHostingView with auto-dismiss. HUD is a variation of this pattern. Suppress if LLM response takes >2 seconds (still write to log). Only show for flag=true entries.
**Depends on:** 1 week of production coaching.jsonl data to confirm false-positive rate < 20%.

---

### T5 — Weekly digest (Phase 2)
**What:** Read coaching.jsonl and surface top 3 recurring error categories from the past week.
**Why:** After a month of dictation, the log becomes genuinely personalized — not generic advice but your specific recurring patterns (e.g., "you say 'discuss about' 4 times a week").
**Pros:** Turns the log from passive recording into an active learning asset. The `category` field was designed for this — all data is already there.
**Cons:** Requires data accumulation (~1 month). Not useful until then.
**Context:** Quick MVP:
```sh
cat ~/Library/Application\ Support/OpenTypeless/coaching.jsonl \
  | python3 -c 'import sys,json; [print(json.loads(l).get("category","null")) for l in sys.stdin if l.strip()]' \
  | sort | uniq -c | sort -rn | head -5
```
A proper UI version would group by category, show example sentences, and compute weekly frequency trends.
**Depends on:** ~1 month of coaching.jsonl entries, T4 HUD optional.
