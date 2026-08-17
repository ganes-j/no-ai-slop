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

### 0.2.0 — density checks and per-project phrase lists

Born from a day of real marketing-copy work where the phrase gate passed ~26 writes a human reviewer kept flagging for style. The deterministic layer now also denies:

- **Em-dash clusters.** One em-dash always passes. A deny fires when dashes cluster (two or more, denser than about one per 350 characters, or three-plus in a single paragraph). Thresholds are module constants in the guard — tune them there.
- **Emoji in markdown headings.** Heading lines only; body emoji stay legal.
- **Superficial `-ing` tails.** ", highlighting/underscoring/showcasing/demonstrating/signaling ..." after a comma. `reflecting` is deliberately excluded (too often legitimate in technical prose).
- **Five puffery phrases** joined the shipped list ("stands as a testament," "marks a pivotal moment," "plays a vital role," "solidifies its position," "underscores its significance").

And the phrase gate now loads two optional supplemental lists, so project vocabulary bans get enforced without touching the shipped list:

- `.no-ai-slop-phrases.txt` in the project root (resolved from `CLAUDE_PROJECT_DIR`, falling back to the hook payload's `cwd`) — e.g., a marketing repo banning "Customer 360" and "earn-and-burn".
- `~/.claude/no-ai-slop-phrases.local.txt` — personal additions that follow you across projects.

Missing files are silently skipped; a hit names which list it came from. All checks report in a single deny, so one rewrite round fixes everything.

### 0.3.0 — self-refreshing guidelines (Wikipedia "Signs of AI writing")

The guideline data now keeps itself current against Wikipedia's [Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing):

- **Deterministic staleness nudge.** On each clean guarded call, the hook compares today against the newest of `hooks/signs-refresh-baseline.txt` (shipped, updated by each reseed PR) and `~/.claude/no-ai-slop-refresh-state.json` (written by local refreshes). Past 30 days it emits a PreToolUse `additionalContext` nudge — at most once per calendar day — pointing at the refresh workflow. No network in the hook, allow/deny behavior untouched, missing or malformed files fail open.
- **`refresh-signs` workflow skill.** Fetches the Wikipedia page, curates new signs into tiers per the shipped list's curation rule (never-legitimate literal phrases → `slop-phrases.txt`; ambiguous vocabulary and structural patterns → the manual skill's judgment lists), mirrors auto-block additions into the personal list for immediate effect, updates state and baseline, and reports every addition and rejection.
- **Initial reseed (2026-08-17).** Fifteen phrases joined the shipped list: importance puffery ("a testament to", "evolving landscape", "plays a pivotal/crucial/key role"...), AI self-disclosure ("as an AI language model", "as of my last update"), and chatbot reference-markup artifacts ("oaicite", "contentReference", and kin — literal tokens from pasted AI output). The judgment layer gained seven vocabulary words, a new "Rule of three" pattern, and extensions to four existing patterns (copula dodges, "Not only X, but also Y", challenges-then-optimism endings, Title Case / empty-heading formatting).
- **Worktree exemption.** The path denylist now also skips worktree checkouts of this repo (`*/no-ai-slop-*/*`), which previously evaded the self-repo exemption and blocked the tool's own maintenance edits.

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
