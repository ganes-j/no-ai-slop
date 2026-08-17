# Routing manifest — feat: Wikipedia Signs-of-AI-writing periodic refresh
Plan: docs/plans/2026-08-17-001-feat-wiki-signs-refresh-plan.md · Policy: ROUTING_POLICY.md @ 2026-07-08
Mode: gated · Coordinator: Fable 5 (session model)

## Assignments
- U1 → codex-implementer [full] — frozen-spec Python impl, no PII, personal repo, route_pick assign — load-bearing check: `bash tests/test_guard.sh`
- U2 → coordinator [full] — skill authoring is spec-writing-as-the-work (§1 never-delegate) — load-bearing check: n/a (read-through vs writing-skills conventions; exercised by U4)
- U3 → codex-implementer [full] (trial — resolves ❓ CI/dep/test-bulk cell; low-stakes) — test additions against U1's fixed assertion targets — load-bearing check: `bash tests/test_guard.sh`
- U4 → coordinator [full] — session-tool work (WebFetch) + curation judgment (§1 never-delegate) — load-bearing check: `bash tests/test_guard.sh` after data edits
- U5 → coordinator [full] — tiny doc/version edits (<~20 lines, §1 never-delegate) — load-bearing check: n/a

Dispatch note: U1+U3 share one spec and one verify command; dispatching them as a single codex-dispatch run is sanctioned — each still gets its own outcome line.

## Execution log
U1 · codex-implementer · PASS · re-check `bash tests/test_guard.sh` green (50/50, run by coordinator) · 0 fix rounds · 01a00fed-b892-7940-a0ba-02dcd1a763de · 2026-08-17
U3 · codex-implementer · PASS (trial → resolves ❓ CI/dep/test-bulk) · re-check `bash tests/test_guard.sh` green (5 new checks, additive-only diff) · 0 fix rounds · 01a00fed-b892-7940-a0ba-02dcd1a763de · 2026-08-17
U2 · coordinator · PASS · re-check n/a (applied end-to-end by U4 reseed) · 0 fix rounds · na · 2026-08-17
U4 · coordinator · PASS · re-check `bash tests/test_guard.sh` green + 2 spot payloads deny · 0 fix rounds · na · 2026-08-17
U5 · coordinator · PASS · re-check n/a (docs/version) · 0 fix rounds · na · 2026-08-17
