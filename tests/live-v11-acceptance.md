# Live acceptance test — deterministic slop guard vs. v11 positioning

Validates the enabled plugin against real Accrue v11 "Offering Architecture" prose.
Designed to run in a **separate, fresh Claude Code session** with the plugin enabled.
**Side-effect-free:** every case writes to a scratch `.md` file — no real Slack, Notion,
or Gmail is touched. One optional case uses a private Artifact.

## Prerequisites (do before starting the test session)

1. Enable the plugin in `~/.claude/settings.json`:
   ```json
   "enabledPlugins": { "no-ai-slop@no-ai-slop": true },
   "extraKnownMarketplaces": {
     "no-ai-slop": { "source": { "source": "github", "repo": "ganes-j/no-ai-slop" } }
   }
   ```
   (Or local: add `~/Developer/no-ai-slop` as a local marketplace.)
2. Start a **new** session (plugin/hook registration loads at startup).
3. Paste everything under "PROMPT TO PASTE" below.

---

## PROMPT TO PASTE

> You are testing a PreToolUse hook that blocks AI-slop before content is written.
> Run the 6 cases below **in order**. For each: perform the stated action exactly once.
> If a hook denies the Write, that is expected for some cases — when it does, read the
> flagged phrases, rewrite the text to remove the slop (minimum effective edit, preserve
> meaning and specifics), and re-issue the Write. Record what happened.
>
> Do NOT send any Slack message, create any Notion page, or send any email. Only `Write`
> to the scratch paths given (and one optional Artifact). After all cases, fill in the
> RESULTS TABLE and the JUDGMENT section.
>
> **Case A — slop-injected v11 (guard SHOULD fire).**
> Write this to `/tmp/slop-test/case-a.md`:
> "It's worth noting that Accrue represents a paradigm shift — a transformative, cutting-edge
> platform that will supercharge how merchants delve into the rich tapestry of customer
> ownership. Take one outcome or the whole loop on the rails you already run."
> Expected: DENY (flags: it's worth noting, paradigm shift, transformative, cutting-edge,
> supercharge, delve, tapestry). Then rewrite and re-Write until it passes.
>
> **Case B — verbatim clean v11 (guard must NOT fire).**
> Write this to `/tmp/slop-test/case-b.md`:
> "Most platforms keep the customer relationship — and the first-party data — for themselves,
> while the merchant stitches together a gateway, a loyalty vendor, a gift-card tool, a wallet,
> and a data feed that never talk to each other. Accrue makes the customer the merchant's to
> own: money movement, loyalty, gifting, and insights as one system."
> Expected: PASS untouched on the first Write. Any deny here is a false positive — record it.
>
> **Case C — structural slop, no banned words (guard must NOT fire; /command territory).**
> Write this to `/tmp/slop-test/case-c.md`:
> "This isn't a payment processor. It's a system of engagement. Think about it: the merchant
> owns the balance. And the loyalty. And the data. That's it. That's the whole moat."
> Expected: PASS on the first Write (the hook greps exact phrases only). Note that a human
> would still want `/no-ai-slop` to fix the binary contrast, rhetorical setup, dramatic
> fragmentation, and mic-drop kicker — this case proves why the manual command still exists.
>
> **Case D — your legitimate vocabulary (guard must NOT fire).**
> Write this to `/tmp/slop-test/case-d.md`:
> "The fraud monitoring is robust, and we leverage the rails you already run to harness float
> while the balance sits."
> Expected: PASS untouched (robust / leverage / harness are excluded from the auto-list on
> purpose). Any deny here is a false positive — record it.
>
> **Case E — denylisted path (guard must NOT fire even with slop).**
> Write the exact Case A slop text to `/tmp/slop-test/docs/plans/case-e.md`.
> Expected: PASS untouched — the path denylist skips planning docs. A deny here is a bug.
>
> **Case F (optional) — non-Write surface.**
> Create a private Artifact whose body is the Case A slop text.
> Expected: DENY (proves the guard covers Artifacts, not just Write). Skip if you'd rather
> not create an Artifact.
>
> After running all cases, output the RESULTS TABLE and JUDGMENT below.

### RESULTS TABLE (fill in)

| Case | Surface | Expected | Fired? | Correct? | Notes |
|------|---------|----------|--------|----------|-------|
| A | Write .md | DENY then pass | | | which phrases flagged? |
| B | Write .md | PASS | | | any false positive? |
| C | Write .md | PASS | | | structural slop left in, as designed |
| D | Write .md | PASS | | | legit words survived? |
| E | Write docs/plans | PASS | | | denylist honored? |
| F | Artifact | DENY | | | optional |

### JUDGMENT (the "impact" read)

1. **Did it fire exactly where it should?** A and F deny; B, C, D, E pass. Any deviation is
   the headline result.
2. **Rewrite quality on Case A** — score 1–5 each, with a one-line reason:
   - Slop removed (all flagged phrases gone)?
   - Meaning preserved (still says "own the customer, take one outcome or the loop")?
   - Voice/specifics preserved (no invented claims; kept concrete framing)?
   - Not over-edited (didn't flatten into generic prose)?
3. **False-positive count** across B/C/D/E — must be 0. Any >0 means the auto-list or
   denylist needs tuning; name the offending phrase/path.
4. **Verdict:** ship (enable live + remove the CLAUDE.md guard), or tune first — and if tune,
   exactly which line of `slop-phrases.txt` or `prose-path-denylist.txt` to change.

---

## What a passing run looks like

- A fires, names the 7 phrases, and the rewrite converges to clean, concrete v11-style prose.
- B, C, D, E all pass on the first Write (zero false positives).
- C passing is a **feature**, not a miss — it documents the boundary between the deterministic
  hook (exact phrases) and the manual `/no-ai-slop` (structural judgment).
- If all of the above hold, step 2 (enable live) and step 3 (remove the CLAUDE.md guard) are safe.
