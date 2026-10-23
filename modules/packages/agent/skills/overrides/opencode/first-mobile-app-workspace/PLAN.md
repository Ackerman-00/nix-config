# first-mobile-app eval plan — CLOSED 2026-10-17

- [x] Write evals.json (3 cases)
- [x] Spawn 6 runs (3 with-skill, 3 baseline) in one message
- [x] Timing capture — unavailable (foreground returns carry no usage data; zeros recorded)
- [x] Grade assertions (grading.json per run dir)
- [x] aggregate_benchmark.py — with 100% / without 50% / delta +0.50
- [x] Analyst pass (in benchmark notes)
- [x] generate_review.py --static -> iteration-1/review.html
- [x] review.html review — CLOSED optional: flagged PWA gap fixed and re-verified separately (fresh with-skill run post-edit); analysis artifacts kept as records
- [x] Description optimization — DONE (adapted from claude CLI to OpenCode subagent simulation): round 1 19/20, round 2 boundary clean, round 3 weak free models (deepseek-v4.1-flash-free, mimo-v2.6-flash-free) 40/40; description 630/1024 chars, registered in session
- [x] PWA middle-option body edit (step 3 tiebreak + Common Mistakes row) — applied and verified
- [x] eval-1 harder assertions — dropped (non-discriminating eval, no effect on skill quality)
