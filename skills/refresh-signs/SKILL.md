---
name: refresh-signs
description: Use when the no-ai-slop guard nudges that its guidelines are stale (additionalContext naming this workflow), or when asked to refresh, update, or reseed the slop guard's guidelines from Wikipedia's "Signs of AI writing" page.
---

# Refresh Signs

Pull new AI-writing signs from https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing into the guard's data files: curated, never auto-appended. The guard stays deterministic; this workflow is the only place judgment touches the data.

## Workflow

1. **Fetch the page** (WebFetch). Enumerate every sign it lists: vocabulary words, literal phrases, structural/tone patterns.
2. **Check existing coverage** for each sign against:
   - `hooks/slop-phrases.txt` (auto-block tier)
   - `skills/no-ai-slop/SKILL.md` "Words to cut" / "Patterns to cut" (judgment tier)
   - `~/.claude/no-ai-slop-phrases.local.txt` and any project `.no-ai-slop-phrases.txt`
   Already covered: drop silently.
3. **Curate each new sign into a tier:**
   - **Auto-block** (`hooks/slop-phrases.txt`) only if ALL hold: it is a literal word/phrase the guard's case-insensitive word-boundary match can catch (no regex, no context); it is almost never legitimate in the user's own writing (the file's curation rule: a false positive here silently rewrites real content); and it is not Wikipedia-editorial. Chatbot reference artifacts (`oaicite`, `turn0search0`, `contentReference`, `grok_render_citation_card_json`, and kin) are ideal candidates, being literal and never legitimate.
   - **Judgment layer** (`skills/no-ai-slop/SKILL.md`) for ambiguous vocabulary and structural patterns: add words to the matching list, patterns as a new or extended "Patterns to cut" entry mirroring the existing voice (name, description, before/after example).
   - **Reject** and say why: Wikipedia-only editorial signs (wikitext, citation formats, categories, edit summaries, AfC process), signs needing regex or context the guard lacks, signs that would flag the user's legitimate technical prose.
4. **Edit in the dev clone** (`~/Developer/no-ai-slop`), never the installed plugin cache (`~/.claude/plugins/cache/...` is overwritten on update). Ship via the repo's normal PR flow, bumping `hooks/signs-refresh-baseline.txt` to today (`date +%F`) in the same change.
5. **Immediate effect:** mirror auto-block additions into `~/.claude/no-ai-slop-phrases.local.txt` so they guard before the plugin update lands.
6. **Update state:** write `last_refresh: $(date +%F)` into `~/.claude/no-ai-slop-refresh-state.json` (preserve other keys).
7. **Verify:** run `bash tests/test_guard.sh`. A new phrase that appears in a clean test fixture or the guard's own docs surfaces here.
8. **Report in-session:** a table of additions per tier and rejections with one-line reasons. No new signs: update state, report clean, stop.

## Common mistakes

| Mistake | Fix |
|---|---|
| Auto-appending every sign to the phrase file | The curation rule is the gate; ambiguity means judgment tier |
| Editing the plugin cache | Dev clone + PR; cache dies on `claude plugin update` |
| Adding a sign the guard can't match (regex, structure) | Structural signs are judgment-tier by definition |
| Hand-authoring dates | Shell `date +%F`, both for state and baseline |
| Skipping the suite after data edits | New phrases can collide with clean fixtures |
