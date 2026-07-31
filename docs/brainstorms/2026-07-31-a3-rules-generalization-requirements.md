---
date: 2026-07-31
topic: a3-rules-generalization
---

# Generalize the A3/A4 copy rules into the guard

## Summary

Extend the fork's two existing layers with the generalizable rules from the byaccrue.com copy effort: the deterministic hook gains an em-dash density check, a project-local phrase-file loader, a handful of puffery phrases, two narrow structural checks, and the pending `new_str` field port; the manual `/no-ai-slop` skill gains five new judgment patterns. Structural style stays in the judgment layer by design.

---

## Problem Frame

A day-long marketing-copy effort (9 solution pages, ~26 guarded Notion writes) ran entirely through the hook without a single block, while the human reviewer repeatedly flagged the same style problems: em-dash clusters, parenthetical asides, bold-label fragments, casual stat lines, a signature claim repeated three times in one opening. None of these are phrase-matchable, and the hook's deterministic layer is phrase-only today. The effort also produced a project vocabulary deny-list ("Customer 360," "earn-and-burn," "loyalty currency") that has no home: the global phrase list is deliberately generic, so project-specific bans currently live only in project docs where the hook can't see them.

One counter-example bounds the design: the reviewer's own approved copy deliberately uses shapes the manual skill names as slop (negative listing: "not money back on the card, not a discount code"). Structural patterns therefore cannot auto-deny; only density metrics and near-never-legitimate matches can.

---

## Key Decisions

- **Three-layer split.** Deterministic hook = density checks and near-never-legitimate matches only; manual skill = every pattern needing judgment; project rule-sets stay in their projects but feed the hook through a local phrase file. Rationale: the fork's curation rule (a false positive silently rewrites real content) plus the approved-copy counter-example.
- **Density over phrase-matching for em-dashes.** A single em-dash is legitimate; clusters are the AI tell. The check counts and thresholds rather than bans, mirroring the manual skill's existing "1–2 fine in longer drafts, none in short copy" guidance.
- **Project-local phrase file as a mechanism, not more global phrases.** The generalizable thing about a project deny-list is the loading mechanism, not the words. The guard reads an optional per-project file and an optional personal file alongside the shipped list.
- **Every hook check denies; no advisory channel.** One behavior keeps the hook predictable. Revisit only if real false positives appear in use.

---

## Requirements

**Deterministic hook**

- R1. The hook denies content whose em-dash usage exceeds a density threshold, with the counts stated in the deny message; a single em-dash always passes. Default threshold intent: allow isolated use, block clusters (exact numbers tuned during implementation against fixtures).
- R2. The hook loads additional deny phrases from an optional project-local file in the working project and an optional personal file under the user's config dir; a missing file is silently skipped, and matches report which list fired.
- R3. The shipped phrase list gains the importance-puffery phrases that are near-never legitimate: "stands as a testament," "marks a pivotal moment," "plays a vital role," "solidifies its position," "underscores its significance."
- R4. The hook denies emoji in markdown headings.
- R5. The hook denies superficial-analysis `-ing` tails (comma followed by "highlighting/underscoring/showcasing/demonstrating/signaling" + clause); the word list stays narrow and easy to shrink if false positives appear.
- R6. Already satisfied upstream: `new_str` landed on main in 0.1.3 (PR #1) with test coverage; this change builds on it, no port needed.
- R7. Tests cover one realistic payload per real field name per guarded tool shape, plus fixtures for every new check (both firing and passing cases).

**Manual skill**

- R8. New pattern — circular definitions: "X is [a restatement of X's name]"; define with information or open on the capability instead.
- R9. New pattern — bold-label fragments: listicle bullets shaped "**Label** — fragment" in customer-facing prose; benefit copy reads as complete sentences.
- R10. New pattern — claim hammering: a signature claim repeated across consecutive blocks or paragraphs; one strong opening mention plus at most one reprise.
- R11. New editing principle — never extend a source claim into an adjacent mechanism claim; when the source doesn't specify a mechanism, ask instead of inventing one.
- R12. Style notes beside the existing em-dash guidance: prefer commas over parenthetical asides in short copy, and sentences containing statistics read as complete, formal sentences.

**Release**

- R13. Version bump so installed copies pick the change up on plugin update.

---

## Acceptance Examples

- AE1. **Covers R1.** Given a Notion-bound draft with four em-dashes in one paragraph, when the write fires, then the hook denies with the em-dash count and the rewrite instruction; the same draft with one em-dash passes.
- AE2. **Covers R2.** Given a project file listing `earn-and-burn`, when a Slack message containing "earn-and-burn" is sent from that project, then the hook denies and names the project list; with no project file present, only the shipped list applies.
- AE3. **Covers R1 + R2 together.** Given a project file present and a draft that is phrase-clean but em-dash-heavy, when the write fires, then the deny message reports the density violation without claiming a phrase hit.

---

## Scope Boundaries

- No per-surface thresholds and no advisory/warn channel — single global tuning, deny-only.
- No auto-deny of judgment-dependent structural patterns (binary contrasts, negative listing, colon reveals, fake-profound kickers) — they stay in the manual skill.
- No repetition/claim-hammering detection in the hook — product names legitimately repeat; judgment layer only.
- The site-copy claims checker (annotation stripping, claims-register sweep) is a separate candidate tool, not part of this change.
- Site-architecture rules from the source effort (proof typing, page contracts, attribution rules) stay in their project hub; they are not slop rules.

---

## Dependencies / Assumptions

- Assumes PreToolUse hooks can resolve the working project directory (e.g., an environment variable exposed to hook processes) to locate the project-local phrase file — verify during planning.
- Assumes the deny-message contract (block + rewrite instruction + re-issue) extends unchanged to the new checks.

---

## Outstanding Questions

**Deferred to planning**

- Exact em-dash threshold values and the unit they apply to (whole payload vs paragraph).
- Project-local file name and precedence order relative to the personal file.
- Whether "reflecting" makes the R5 word list (highest false-positive risk of the set).

---

## Sources

- `hooks/no-ai-slop-guard.py` — deterministic layer is phrase-only (`find_hits` against the phrase list); `new_str` scanning landed on main in 0.1.3 (PR #1).
- `hooks/slop-phrases.txt` — 20 shipped phrases, no puffery or structural entries.
- `skills/no-ai-slop/SKILL.md` — existing judgment patterns, including the em-dash guidance the R1 thresholds mirror.
- Origin rules: A3 hub (Notion, "A3 · Solution 1-Pagers — hub") rules S35/S38/S39/S41 and the A4 hub rules they extend.
