# No AI slop

Remove AI-slop patterns from your writing — and stop the worst of it from ever being published.

## Fork changes

This is a personal fork of [petergyang/no-ai-slop](https://github.com/petergyang/no-ai-slop). Upstream is a manual editor/detector skill you invoke with `/no-ai-slop`. This fork keeps that skill unchanged and adds a **deterministic guard layer** on top, because a directive you have to remember to run does not reliably fire.

The differences, all deliberate:

1. **A `PreToolUse` hook that blocks slop before it publishes.** `hooks/no-ai-slop-guard.py` greps content headed to **Notion, Slack, Gmail, Claude Artifacts, and prose `.md` files** against a high-precision phrase list. On a hit it denies the tool call and hands the flagged phrases back, so the draft is rewritten clean and re-issued *before* anything lands. No confusing half-published states, no prompt — it just runs.
2. **Deterministic trigger, model-applied fix.** The hook is the exact-phrase gate (pure code). The rewrite it forces applies the full skill — phrases *and* structural patterns — so structural slop is caught on every guarded surface, not only when an exact phrase happens to appear.
3. **A high-precision auto-list, separate from the judgment list.** `hooks/slop-phrases.txt` holds only phrases that are almost never legitimate (`delve`, `tapestry`, `paradigm shift`, `it's worth noting`…). Ambiguous words that are often legitimate in technical writing (`leverage`, `robust`, `harness`, `utilize`, and the often-empty adverbs) are **excluded** from the auto-list and stay in the manual `/command`, where a human applies judgment. Auto-rewrite with no human in the loop must not mangle real content.
4. **A path denylist for the file guard.** `hooks/prose-path-denylist.txt` keeps the `.md` guard off internal engineering docs — plans, `docs/solutions`, memory, `CLAUDE.md`, session archives. Non-prose files (code, SQL, JSON) are never scanned.
5. **Plugin-shaped.** Restructured into a Claude Code plugin (`skills/`, `hooks/hooks.json`, `.claude-plugin/`) so enabling it auto-registers the hook.

Not meant to merge back upstream — the guard layer is a deliberate divergence.

Tune the guard by editing the two data files; move a word out of `slop-phrases.txt` the moment it causes a bad rewrite. The manual skill's full pattern set lives in [SKILL.md](skills/no-ai-slop/SKILL.md).

## What the manual skill catches

The `/no-ai-slop` command detects 20+ patterns. A sample:

| Pattern | Smells like |
|---------|-------------|
| Binary contrasts | "It's not X. It's Y." |
| Throat-clearing openers | "Here's the thing..." |
| Faux-insight setups | "What nobody tells you..." |
| Colon reveals | "The best part: it learns." |
| Superficial analysis | "...highlighting the team's commitment" |
| Importance puffery | "marks a pivotal moment" |
| Weasel attribution | "experts agree," "studies show" |
| Fake-profound kickers | a final cute mic-drop aphorism |
| Dramatic fragmentation | "That's it. That's the whole thing." |

It also enforces fundamentals: lead with the point, active voice, untangle hard sentences, prefer concrete numbers over abstractions.

## Install

```bash
claude plugin marketplace add ganes-j/no-ai-slop
claude plugin install no-ai-slop@no-ai-slop
```

Then reload / restart your session — hooks load at startup. Verify with `claude plugin list`.

**Editing `settings.json` alone is not enough.** Adding `enabledPlugins` + `extraKnownMarketplaces` registers and clones the marketplace but does **not** install the plugin, so the `PreToolUse` guard never loads (it lives under `plugins/marketplaces/` but not `plugins/cache/`). Run `claude plugin install` as above, or use `/plugin` interactively. Installing registers the guard automatically via `hooks/hooks.json` — no manual hook wiring.

## Use

**Automatic (the guard).** Nothing to invoke. When you post to a guarded surface, slop is blocked and rewritten before it lands.

**Manual edit.** Paste a draft and invoke the skill:

```
/no-ai-slop

[your draft]
```

You get the edited draft plus a short *What changed* section.

**Detect.** Ask whether a piece reads as AI:

```
/no-ai-slop is this AI slop?

[the text]
```

Every pattern it found, each with the quoted line.

## Files

- `hooks/no-ai-slop-guard.py` — the deterministic PreToolUse guard
- `hooks/slop-phrases.txt` — high-precision auto-block list (edit to tune)
- `hooks/prose-path-denylist.txt` — paths the file guard skips
- `hooks/hooks.json` — plugin hook registration
- `skills/no-ai-slop/SKILL.md` — the manual editing rules and workflow
- `skills/no-ai-slop/eval.md` — pass/fail checks the skill runs on its own edits
- `tests/test_guard.sh` — allow/deny cases for the guard

## License

MIT. Upstream: [petergyang/no-ai-slop](https://github.com/petergyang/no-ai-slop).
