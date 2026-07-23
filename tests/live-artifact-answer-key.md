# Answer key — live-artifact-blind-run v2 (DO NOT paste into the runner)

Focus: verify the Artifact-body guard fires LIVE after reload (the fix the last blind
run exposed), plus a regression pass on the core Write path.

| Item | What it is | Expected | Why |
|------|-----------|----------|-----|
| 1 | Artifact, slop in HTML body | .html Write PASSES, then Artifact publish BLOCKS | Write skips .html; the Artifact branch reads file_path body and catches slop. THE key new check. |
| 2 | Artifact, clean HTML body | Write passes, Artifact publishes | no slop anywhere |
| 3 | Artifact, clean body, slop in TITLE ("a paradigm shift...") | Artifact publish BLOCKS | title is in tool_input; collect_text scans it |
| 4 | Write .md, slop | BLOCK | delve, tapestry, game changer |
| 5 | Write .md, clean v11 | PASS | no auto-list phrase |
| 6 | Write .md, ambiguous vocab | PASS | robust/leverage/harness excluded |

Expected BLOCK: 1 (at publish), 3, 4. Expected PASS: 1 (the .html Write), 2, 5, 6.

## Scoring
1. **Artifact body fires (item 1 publish blocks):** the headline. If it passes, the file-read fix isn't live — check reload happened and cache is 0.1.2.
2. **Artifact title fires (item 3):** confirms tool_input scanning on Artifacts.
3. **Regression:** 4 blocks, 5 & 6 pass, zero false positives.
4. **Rewrite quality** on blocked items (1, 3, 4): meaning preserved, voice intact, slop gone, not over-edited.
5. **Verdict:** if item 1 blocks at publish and regression is clean, the Artifact gap is closed and the guard is fully shipped.
