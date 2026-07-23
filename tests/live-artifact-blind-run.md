# Blind runner v2 — Artifact coverage + regression (paste into a fresh session)

Blind test. Items are NOT labeled by expected outcome. Execute each, report exactly
what happens. Uses fresh paths (`/tmp/slop-test-2/`) so no prior-run files collide.
Some items publish a **private** Artifact; nothing is sent to Slack/Notion/Gmail.

## Prerequisites

1. The `no-ai-slop` plugin is installed (`claude plugin list` shows it).
2. **Reload the window**, then start a **new** session (the Artifact-guard fix loads at startup).
3. Paste everything under "PROMPT TO PASTE".

---

## PROMPT TO PASTE

> Do exactly this, in order. Report precisely what happens for each item — did the
> action succeed, or was it blocked by a hook? If blocked, paste the hook's message
> **verbatim**. If blocked, then revise the text so the action succeeds, retry, and
> paste BOTH your revised text and whether the retry succeeded. Do not skip items,
> do not explain what you think the test is for, do not judge quality.
>
> Item 1 — first Write this to `/tmp/slop-test-2/art-01.html`:
> "<h1>Own the customer</h1><p>It's worth noting that Accrue represents a paradigm shift — a transformative, cutting-edge platform that will supercharge how merchants delve into the rich tapestry of customer ownership.</p>"
> Then publish that file as a private Artifact (title "Ownership One", favicon test-tube).
>
> Item 2 — first Write this to `/tmp/slop-test-2/art-02.html`:
> "<h1>Own the customer</h1><p>Accrue lets a merchant own the customer relationship end to end — money movement, loyalty, gifting, and insights as one system.</p>"
> Then publish that file as a private Artifact (title "Ownership Two", favicon test-tube).
>
> Item 3 — first Write this to `/tmp/slop-test-2/art-03.html`:
> "<h1>Payments</h1><p>Take money in, route and settle it, pay it out. Works with the merchant's existing POS and processor.</p>"
> Then publish that file as a private Artifact with title "a paradigm shift in payments".
>
> Item 4 — Write this to `/tmp/slop-test-2/reg-01.md`:
> "Let's delve into this rich tapestry of loyalty — a game changer."
>
> Item 5 — Write this to `/tmp/slop-test-2/reg-02.md`:
> "SNIPES landed on returns and grew into the full loop: 400K+ members, +20% AOV, 3x frequency."
>
> Item 6 — Write this to `/tmp/slop-test-2/reg-03.md`:
> "The fraud monitoring is robust, and we leverage the rails you already run to harness float."
>
> After all items, output one table: Item | Action | Blocked? (yes/no) | Flagged phrases (verbatim, or dash) | Revised-and-passed? (yes/no/NA). Then paste before to after text for every item you revised.

---

## After the run

Bring the full output back to the orchestrator session. Expected outcomes and scoring
live in `live-artifact-answer-key.md` (not pasted here) and are judged there.
