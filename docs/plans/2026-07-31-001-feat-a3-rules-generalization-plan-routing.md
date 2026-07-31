# Routing manifest — feat: Generalize the A3 copy rules into the guard
Plan: docs/plans/2026-07-31-001-feat-a3-rules-generalization-plan.md · Policy: ROUTING_POLICY.md @ read 2026-07-31 (catalogs fresh per model_staleness.py)
Mode: gated (approved with the plan — Jesse pre-authorized autonomous execution this run) · Coordinator: Opus 4.8

## Assignments
- U1 → codex-implementer [full] — impl-from-frozen-spec via route_pick.py (verifiable, constraint-clean: personal dev repo, no PII/prod creds) — load-bearing check: `bash tests/test_guard.sh`
- U2 → codex-implementer [full] — same shape/pick; depends on U1's pipeline refactor — load-bearing check: `bash tests/test_guard.sh`
- U3 → codex-implementer [full] — same shape/pick; depends on U1 — load-bearing check: `bash tests/test_guard.sh`
- U4 → coordinator [bare: prose-only, no verify cmd] — skill-voice authoring is never-delegate judgment work; discipline floor bars write-workers without a verify command — load-bearing check: n/a (editorial read-through in U5)
- U5 → coordinator [full] — verification gate + tiny version/doc edits (never-delegate set) — load-bearing check: `bash tests/test_guard.sh`

Note: U1–U3 are sequential on the same two files with one shared verify command — codex-dispatch may run them as a single Codex session against the combined spec; outcome lines stay per-unit.

## Execution log
- U1 · codex-implementer · PASS · re-check `bash tests/test_guard.sh` green (pass=40 fail=0, orchestrator-run) · 0 fix rounds · 019fb9ff-d2bd-7d93-8cd0-f57b5ed8bb3f · 2026-07-31
- U2 · codex-implementer · PASS · re-check `bash tests/test_guard.sh` green (same run) · 0 fix rounds · 019fb9ff-d2bd-7d93-8cd0-f57b5ed8bb3f · 2026-07-31
- U3 · codex-implementer · PASS · re-check `bash tests/test_guard.sh` green (same run) · 0 fix rounds · 019fb9ff-d2bd-7d93-8cd0-f57b5ed8bb3f · 2026-07-31
- U4 · coordinator · PASS · re-check n/a (prose; editorial read-through done) · 0 fix rounds · na · 2026-07-31
- U5 · coordinator · PASS · re-check `bash tests/test_guard.sh` green · 0 fix rounds · na · 2026-07-31
- dual-review round (PR #2): 2 High fixed (fence-aware heading check; -ing regex no longer crosses paragraph breaks), 2 split fixed (mktemp fixture dir; flag-emoji + indented-heading coverage), 1 split rejected by design (em-dash pairs in short copy are the rule's target) · coordinator · re-check `bash tests/test_guard.sh` green (pass=45 fail=0) · 2026-07-31
