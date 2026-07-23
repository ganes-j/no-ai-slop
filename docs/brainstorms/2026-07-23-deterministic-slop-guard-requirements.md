---
date: 2026-07-23
topic: deterministic-slop-guard
---

# Deterministic AI-Slop Guard — Requirements

## Summary

Add a deterministic `PreToolUse` hook to a fork of no-ai-slop that greps content headed to Notion, Slack, Gmail, Claude Artifacts, and prose `.md` files against a high-precision banned-phrase list, and blocks it for rewrite before it publishes. The always-on CLAUDE.md anti-slop directive is removed; its greppable phrases move into the hook and its structural patterns stay in the fork's manual `/command`.

## Problem Frame

The current anti-slop coverage is an always-on CLAUDE.md directive. It is soft context the model may or may not apply, competing with a large prompt, and it does not reliably fire. The upstream no-ai-slop skill is more capable but is a manual `/command` — reliable only when the user remembers to run it. Neither guarantees that slop is caught before an artifact is published to an external surface, which is where a slip is most costly and hardest to undo.

## Key Decisions

- **Deterministic trigger, model-applied fix.** A code hook cannot rewrite prose. The hook is the exact-phrase gate; when it fires it denies the call and the model rewrites and re-issues. The grep re-checks the rewrite, so the loop converges on clean content.
- **Auto-list is high-precision only.** The auto-block list holds only phrases that are almost never legitimate. Ambiguous words (`leverage`, `robust`, `harness`, `utilize`, often-empty adverbs) are excluded and live in the manual `/command`, because auto-rewrite has no human to catch a bad edit.
- **Structural slop is covered on guarded surfaces.** The rewrite the hook forces runs the full skill — phrases and structural patterns — so structural slop is caught on every guarded post, not only when an exact phrase appears. The manual `/command` remains the only coverage for chat-only prose and on-demand audits.
- **CLAUDE.md guard removed entirely.** Its greppable phrases move into the hook; its structural patterns move into the fork's skill. In-chat prose that is never posted becomes unguarded — accepted.
- **Ships as a plugin fork.** `origin` = `ganes-j/no-ai-slop`, `upstream` = `petergyang/no-ai-slop`. Enabling the plugin auto-registers the hook via `hooks/hooks.json`; no manual `settings.json` hook wiring.

## Requirements

**Guard behavior**

R1. On a guarded tool call, the hook scans the content in the tool input against `slop-phrases.txt` (case-insensitive, word-boundary) and denies the call when any phrase matches, naming the matched phrases in the deny reason.
R2. On a match, the deny reason instructs a full no-ai-slop rewrite (phrase and structural), minimum effective edit, voice preserved; a clean re-issue of the same call then passes.
R3. Clean content passes silently — no prompt, no message, tool proceeds normally.

**Scope of surfaces**

R4. Guarded surfaces are the connectors (Notion create/update, Slack send/post/reply, Gmail create/draft/send) across both duplicate MCP server variants, plus the Claude `Artifact` tool.
R5. `Write`/`Edit` are guarded only for prose extensions (`.md`, `.mdx`, `.txt`) and only when the file path is not in `prose-path-denylist.txt`. All other file types pass unscanned.
R6. Non-output tools (Bash, Read, search, etc.) are never affected.

**Precision and tuning**

R7. `slop-phrases.txt` and `prose-path-denylist.txt` are the tuning surface — plain data files, editable without touching code.
R8. Ambiguous-but-often-legitimate words are absent from the auto-list and documented as living in the manual `/command`.

**Migration**

R9. The CLAUDE.md "Human-Voice Writing (Anti-AI-Slop)" section is removed; the fork's skill + hook are its replacement.

## Acceptance Examples

AE1. **Covers R1, R4.** A Slack `send_message` with "Let us delve into this tapestry" is denied; the reason names `delve` and `tapestry`. → verified in `tests/test_guard.sh`.
AE2. **Covers R3, R8.** A Slack message "The retry logic is robust; we leverage the existing harness" passes — those words are not on the auto-list. → verified.
AE3. **Covers R5.** A `Write` to `app.py` containing slop passes (not a prose extension); a `Write` to `docs/plans/p.md` containing slop passes (denylisted path); a `Write` to `memo.md` containing slop is denied. → verified.
AE4. **Covers R2.** After a deny, re-issuing the call with the phrase removed passes the grep.

## Scope Boundaries

- **Chat-only prose** (shown in chat, never posted through a tool) — not guarded. Accepted gap; the manual `/command` covers it on demand.
- **Structural patterns as a standalone deterministic check** — not greppable; not attempted in the hook. They ride the rewrite the hook forces, and otherwise live in the `/command`.
- **A hook-owned local-model rewrite** (headless/scheduled) — rejected in favor of the model-loop for fidelity and zero dependency.

## Dependencies / Assumptions

- The hook relies on the assistant acting on the deny (model-loop). It does not cover headless/scheduled posts.
- Assumes Claude Code PreToolUse `permissionDecision: "deny"` blocks the call and returns the reason to the assistant. (Verified behavior for the guarded MCP + built-in tools in testing.)
- Content extraction assumes prose lives under common content keys; unusual connector payload shapes may need a key added to the hook's `CONTENT_KEYS`.

## Outstanding Questions

**Resolve before enabling live**
- Confirm the fork should be pushed to `ganes-j/no-ai-slop` and enabled via the plugin marketplace (outward + config change).
- Confirm removal of the CLAUDE.md guard section now vs. after a live shakedown of the hook.

**Deferred**
- Whether to add an always-on structural nudge on clean guarded posts (currently structural rides only the phrase-triggered rewrite).
- Loop-escape handling if a legitimate quote contains an auto-list phrase (rare given curation).
