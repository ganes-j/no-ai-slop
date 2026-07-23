# Answer key — live-v11-blind-run (DO NOT paste into the runner session)

The runner is blind. This is the ground truth the orchestrator judges its output against.

## Expected outcome per item

| Item | Content type | Path | Expected | Why |
|------|--------------|------|----------|-----|
| 1 | clean v11 verbatim | .md | PASS | no auto-list phrase (em dashes are not auto-caught) |
| 2 | slop-injected v11 | .md | **BLOCK** | it's worth noting · paradigm shift · transformative · cutting-edge · supercharge · delve · tapestry |
| 3 | clean v11 verbatim | .md | PASS | no auto-list phrase |
| 4 | ambiguous vocab | .md | PASS | robust / leverage / harness are excluded from the auto-list on purpose |
| 5 | structural slop only | .md | PASS | binary contrast + rhetorical setup + fragmentation + kicker — none greppable; /command territory |
| 6 | slop-injected | .md | **BLOCK** | in today's world · it's important to note · game changer · at the end of the day · this changes everything |
| 7 | clean v11 verbatim | .md | PASS | no auto-list phrase |
| 8 | slop text, denylisted path | docs/plans/*.md | PASS | path denylist skips planning docs |
| 9 | clean v11 verbatim | .md | PASS | no auto-list phrase |
| 10 | slop text, .py | .py | PASS | not a prose extension |
| 11 | clean v11 verbatim | .md | PASS | no auto-list phrase |
| 12 | clean v11 verbatim | .md | PASS | no auto-list phrase |
| 13 | slop, Artifact | Artifact | **BLOCK** | proves a non-Write surface fires |

Expected BLOCK: **2, 6, 13**. Expected PASS: **1, 3, 4, 5, 7, 8, 9, 10, 11, 12**.

## Scoring (orchestrator fills after the run)

**1. Firing accuracy (integration).**
- Misses = any of {2, 6, 13} that passed. Any miss ⇒ hook not firing live (wiring / tool_input shape). Blocker.
- Correct-block phrases: for 2 and 6, did the flagged-phrase list match the "Why" column? Wrong/partial list ⇒ extraction or regex bug.

**2. False positives (the load-bearing number).**
- FP = any of {1, 3, 4, 5, 7, 9, 11, 12} that blocked. Target = **0**.
- Item 4 blocking ⇒ an ambiguous word leaked into the auto-list (name it, remove it).
- Item 8 blocking ⇒ denylist not honored (fix pattern). Item 10 blocking ⇒ extension check broken.
- Item 5 blocking would actually be surprising (no auto phrase) ⇒ investigate regex.

**3. Loop convergence.**
- For 2, 6, (13): did the revised text pass on the retry? Any that needed >1 retry or never passed ⇒ note it (list precision or a phrase in a proper noun).

**4. Rewrite quality (judge the before → after for 2, 6, 13), 1–5 each:**
- Slop removed — every flagged phrase gone.
- Meaning preserved — still says what v11 says (own the customer, one outcome or the loop, etc.); no invented claims.
- Voice/specifics preserved — kept concrete framing and any numbers; didn't flatten into generic prose.
- Not over-edited — cut the slop, not the substance.

**5. Verdict.**
- FP = 0 AND all expected blocks fired AND rewrite quality ≥ 3/5 average ⇒ **ship** (keep plugin enabled, proceed to remove the CLAUDE.md guard).
- Otherwise ⇒ **tune**: name the exact `slop-phrases.txt` line or `prose-path-denylist.txt` pattern to change, and re-run.
