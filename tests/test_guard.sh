#!/usr/bin/env bash
# Feeds sample PreToolUse payloads to the guard and checks allow/deny.
# A "deny" prints JSON with permissionDecision:deny. An "allow" prints nothing.
set -u
GUARD="$(cd "$(dirname "$0")/.." && pwd)/hooks/no-ai-slop-guard.py"
pass=0; fail=0
REWRITE_INSTRUCTION="Rewrite the draft to remove them, then re-issue the same call. Apply the no-ai-slop skill on the rewrite (phrase AND structural patterns — binary contrasts, fake-profound kickers, dramatic fragmentation, etc.), make the minimum effective edit, and preserve the author's voice. Do not strip legitimate meaning."

FIX="$(mktemp -d -t slop-test-fixtures-XXXXXX)"
printf "Let us delve into this tapestry of results." > "$FIX/artifact-slop.html"
printf "A clean sentence about payments and loyalty." > "$FIX/artifact-clean.html"
mkdir -p "$FIX/project" "$FIX/project-missing" "$FIX/personal/.claude" "$FIX/empty-home" "$FIX/cwd-project"
rm -f "$FIX/project-missing/.no-ai-slop-phrases.txt" "$FIX/empty-home/.claude/no-ai-slop-phrases.local.txt"
printf "earn-and-burn\n" > "$FIX/project/.no-ai-slop-phrases.txt"
printf "growth theater\n" > "$FIX/personal/.claude/no-ai-slop-phrases.local.txt"
printf "points confetti\n" > "$FIX/cwd-project/.no-ai-slop-phrases.txt"
export CLAUDE_PROJECT_DIR="$FIX/project-missing"
export HOME="$FIX/empty-home"

check() { # name  expected(allow|deny)  json  [reason substrings...]
  local name="$1" expected="$2" json="$3"
  shift 3
  local out; out="$(printf '%s' "$json" | python3 "$GUARD" 2>/dev/null)"
  local got="allow"; echo "$out" | grep -q '"permissionDecision": "deny"' && got="deny"
  if [ "$got" = "deny" ] && ! printf '%s' "$out" | python3 -c '
import json
import sys

reason = json.load(sys.stdin)["hookSpecificOutput"]["permissionDecisionReason"]
instruction = sys.argv[1]
raise SystemExit(reason.count(instruction) != 1 or not reason.endswith(instruction))
' "$REWRITE_INSTRUCTION"; then
    got="deny rewrite instruction mismatch"
  fi
  local needle
  for needle in "$@"; do
    case "$needle" in
      !*)
        if printf '%s' "$out" | grep -Fq -- "${needle#!}"; then
          got="deny reason unexpectedly contains: ${needle#!}"
        fi
        ;;
      *)
        if ! printf '%s' "$out" | grep -Fq -- "$needle"; then
          got="deny reason missing: $needle"
        fi
        ;;
    esac
  done
  if [ "$got" = "$expected" ]; then
    pass=$((pass+1)); printf 'PASS  %-42s -> %s\n' "$name" "$got"
  else
    fail=$((fail+1)); printf 'FAIL  %-42s -> got %s, want %s\n' "$name" "$got" "$expected"
  fi
}

check "slack slop"        deny  '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{"text":"Let us delve into this tapestry of results."}}'
check "slack clean"       allow '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{"text":"Shipped the fix. Tests pass."}}'
check "slack legit robust" allow '{"tool_name":"mcp__slack__slack_post_message","tool_input":{"text":"The retry logic is robust; we leverage the existing harness."}}'
check "notion nested slop" deny  '{"tool_name":"mcp__claude_ai_Notion__notion-create-pages","tool_input":{"pages":[{"content":"This is huge and will supercharge the team."}]}}'
check "notion update new_str slop" deny  '{"tool_name":"mcp__claude_ai_Notion__notion-update-page","tool_input":{"command":"replace_content","new_str":"A game-changer that will supercharge the team."}}'
check "notion update new_str clean" allow '{"tool_name":"mcp__claude_ai_Notion__notion-update-page","tool_input":{"command":"replace_content","new_str":"Refunds land as spendable balance and drive reconversion."}}'
check "notion content_updates slop" deny  '{"tool_name":"mcp__claude_ai_Notion__notion-update-page","tool_input":{"command":"update_content","content_updates":[{"old_str":"x","new_str":"Let us delve into this tapestry."}]}}'
check "gmail draft slop"  deny  '{"tool_name":"mcp__claude_ai_Gmail__create_draft","tool_input":{"body":"It is worth noting that this is a paradigm shift."}}'
check "gmail clean"       allow '{"tool_name":"mcp__gmail__draft_email","tool_input":{"body":"Following up on the invoice from Tuesday."}}'
check "artifact slop (file body)"  deny  "{\"tool_name\":\"Artifact\",\"tool_input\":{\"file_path\":\"$FIX/artifact-slop.html\",\"title\":\"x\"}}"
check "artifact clean (file body)" allow "{\"tool_name\":\"Artifact\",\"tool_input\":{\"file_path\":\"$FIX/artifact-clean.html\"}}"
check "artifact title slop"        deny  "{\"tool_name\":\"Artifact\",\"tool_input\":{\"file_path\":\"$FIX/artifact-clean.html\",\"title\":\"a paradigm shift\"}}"
check "write md slop"     deny  '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/memo.md","content":"Let us dive in to this multifaceted problem."}}'
check "write py slop"     allow '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/app.py","content":"# delve tapestry supercharge"}}'
check "write denylist plan" allow '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/docs/plans/p.md","content":"delve into this tapestry"}}'
check "write denylist CLAUDE" allow '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/CLAUDE.md","content":"delve tapestry"}}'
check "write denylist tests dir" allow '{"tool_name":"Write","tool_input":{"file_path":"/x/repo/tests/fixture.md","content":"delve tapestry game changer"}}'
check "write denylist tool repo" allow '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/Developer/no-ai-slop/README.md","content":"delve tapestry paradigm shift"}}'
check "edit md slop"      deny  '{"tool_name":"Edit","tool_input":{"file_path":"/Users/x/brief.md","new_string":"a transformative, game-changing shift"}}'
check "bash not guarded"  allow '{"tool_name":"Bash","tool_input":{"command":"echo delve tapestry"}}'
check "read not guarded"  allow '{"tool_name":"Read","tool_input":{"file_path":"/x/delve.md"}}'
check "word boundary"     allow '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{"text":"We are delving carefully and elevating slowly."}}'

LONG_SPARSE_TEXT="$(printf '%0750d' 0)—$(printf '%0750d' 0)—end"
PARAGRAPH_OVERRIDE_TEXT="$(printf '%01100d' 0)\n\nOne—two—three—four."
check "notion paragraph four em dashes" deny '{"tool_name":"mcp__claude_ai_Notion__notion-update-page","tool_input":{"command":"replace_content","new_str":"One—two—three—four—five."}}' "Em-dash density" "4 em dashes"
check "notion single em dash" allow '{"tool_name":"mcp__claude_ai_Notion__notion-update-page","tool_input":{"command":"replace_content","new_str":"One—two."}}'
check "long sparse em dashes" allow "{\"tool_name\":\"mcp__claude_ai_Notion__notion-update-page\",\"tool_input\":{\"command\":\"replace_content\",\"new_str\":\"$LONG_SPARSE_TEXT\"}}"
check "paragraph em dash override" deny "{\"tool_name\":\"mcp__claude_ai_Notion__notion-update-page\",\"tool_input\":{\"command\":\"replace_content\",\"new_str\":\"$PARAGRAPH_OVERRIDE_TEXT\"}}" "densest paragraph has 3"
check "slack dense em dashes" deny '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{"text":"A short update—payments shipped and tests pass—but rollout remains paused while we review the production metrics and confirm that every retry path behaves correctly."}}' "Em-dash density"
check "phrase and em dash violations" deny '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{"text":"Let us delve into this result—then inspect the data—and ship only what the evidence supports."}}' "shipped list" "Em-dash density"
CLAUDE_PROJECT_DIR="$FIX/project" HOME="$FIX/empty-home" check "project phrase file" deny '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{"text":"The earn-and-burn mechanic needs revision."}}' "project list"
CLAUDE_PROJECT_DIR="$FIX/project-missing" HOME="$FIX/empty-home" check "missing project phrase file" allow '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{"text":"The earn-and-burn mechanic needs revision."}}'
CLAUDE_PROJECT_DIR="$FIX/project-missing" HOME="$FIX/personal" check "personal phrase file" deny '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{"text":"That roadmap is growth theater."}}' "personal list"
unset CLAUDE_PROJECT_DIR
HOME="$FIX/empty-home" check "payload cwd phrase file" deny "{\"cwd\":\"$FIX/cwd-project\",\"tool_name\":\"mcp__claude_ai_Slack__slack_send_message\",\"tool_input\":{\"text\":\"Avoid points confetti in the loyalty copy.\"}}" "project list"
HOME="$FIX/empty-home" check "new puffery phrase" deny '{"tool_name":"mcp__claude_ai_Gmail__create_draft","tool_input":{"body":"This release stands as a testament to the team."}}' "stands as a testament"
HOME="$FIX/empty-home" check "emoji in markdown heading" deny '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/launch.md","content":"## 🚀 Launch plan\n\nShip after review."}}' "Emoji in Markdown heading"
HOME="$FIX/empty-home" check "emoji in markdown body" allow '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/launch.md","content":"## Launch plan\n\nShip after review 🚀"}}'
HOME="$FIX/empty-home" check "ing analysis tail" deny '{"tool_name":"mcp__claude_ai_Gmail__create_draft","tool_input":{"body":"The launch reached every region, highlighting the team’s commitment."}}' "-ing analysis tail"
HOME="$FIX/empty-home" check "wrapped ing analysis tail" deny '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/launch.md","content":"The launch reached every region,\nhighlighting the team’s commitment."}}' "-ing analysis tail"
HOME="$FIX/empty-home" check "ing sentence subject" allow '{"tool_name":"mcp__claude_ai_Gmail__create_draft","tool_input":{"body":"Highlighting matters when reviewers scan a draft."}}'
HOME="$FIX/empty-home" check "reflecting tail excluded" allow '{"tool_name":"mcp__claude_ai_Gmail__create_draft","tool_input":{"body":"The setting changed, reflecting the viewer’s theme."}}'
CLAUDE_PROJECT_DIR="$FIX/project" HOME="$FIX/empty-home" check "project file with density only" deny '{"tool_name":"mcp__claude_ai_Notion__notion-update-page","tool_input":{"command":"replace_content","new_str":"Refunds return as balance—customers spend it again—and merchants retain the next purchase."}}' "Em-dash density" "!AI-slop phrase(s)"

check "emoji heading inside code fence" allow '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/notes.md","content":"Real prose here.\n\n```\n## 🚀 Example\n```"}}'
check "flag emoji in heading"           deny  '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/notes.md","content":"## 🇺🇸 Launch\n\nBody."}}'
check "indented emoji heading"          deny  '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/notes.md","content":"   ## 🚀 Plan\n\nBody."}}'
check "ing tail across paragraph break" allow '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{"text":"We shipped it,\n\nHighlighting comes later in the doc."}}'
check "ing tail soft wrap still denies" deny  '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{"text":"The launch adds file search,\nhighlighting the team commitment."}}'

# --- HTML entity decoding -------------------------------------------------
# Prose that spells its em dashes as entities reads identically to a human but
# carried zero literal em dashes past the density check.
check "md entity em dashes"        deny  '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/memo.md","content":"One&mdash;two&mdash;three&mdash;four&mdash;five."}}' "Em-dash density"
check "md numeric entity em dashes" deny '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/memo.md","content":"One&#8212;two&#x2014;three&#8212;four."}}' "Em-dash density"
check "md single entity"           allow '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/memo.md","content":"One&mdash;two."}}'
check "slack entity em dashes"     deny  '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{"text":"Refunds return as balance&mdash;customers spend it again&mdash;and merchants keep the next purchase."}}' "Em-dash density"
check "entity decode keeps phrases" deny '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/memo.md","content":"Let us delve into this&mdash;a tapestry."}}' "shipped list"

# --- source-file prose literals -------------------------------------------
# The real 2026-08-17 miss: five coversheet definitions written by Edit into a
# .mjs template literal, spelled with &mdash; so nothing looked like an em dash.
check "mjs prose literals (real miss)" deny '{"tool_name":"Edit","tool_input":{"file_path":"/Users/x/build/pages/strategic.mjs","new_string":"const BAND_DEFS = [[\"Move Money\", \"A branded balance customers load, hold, and spend everywhere the merchant sells &mdash; float on the balance, economics on the spend.\"], [\"Loyalty\", \"The marketing and activation layer on top of money movement &mdash; rewards, offers, and drops that turn balances into repeat purchase.\"], [\"Gifting\", \"Someone else pays and it lands as spendable balance &mdash; every gift or referral enrolls a new customer.\"], [\"Insights\", \"Full purchase behavior the merchant can act on &mdash; profiles, segments, and plain-language answers.\"]];"}}' "Em-dash density"
check "tsx marketing copy literal" deny '{"tool_name":"Edit","tool_input":{"file_path":"/Users/x/src/solutions-entry.tsx","new_string":"const copy = \"Let us delve into this tapestry of loyalty results.\";"}}' "shipped list"
check "source code only"           allow '{"tool_name":"Edit","tool_input":{"file_path":"/Users/x/app.ts","new_string":"const userIds = buildQuery(\"SELECT id FROM users WHERE active = true\");"}}'
check "source short literals"      allow '{"tool_name":"Edit","tool_input":{"file_path":"/Users/x/app.ts","new_string":"const a = \"x&mdash;y\"; const b = \"p&mdash;q\"; const c = \"m&mdash;n\";"}}'
check "source denylist tests dir"  allow '{"tool_name":"Edit","tool_input":{"file_path":"/x/repo/tests/fixture.mjs","new_string":"const s = \"A branded balance customers load and spend &mdash; float on it &mdash; and more &mdash; again &mdash; yes.\";"}}'
check "source denylist tool repo"  allow '{"tool_name":"Edit","tool_input":{"file_path":"/Users/x/Developer/no-ai-slop/hooks/x.py","new_string":"S = \"A branded balance customers load and spend &mdash; float on it &mdash; and more &mdash; again &mdash; yes.\""}}'
check "unknown ext still skipped"  allow '{"tool_name":"Write","tool_input":{"file_path":"/Users/x/data.bin","new_string":"A branded balance customers load and spend &mdash; float &mdash; more &mdash; again &mdash; yes."}}'
# Entities must decode BEFORE literals are picked: &nbsp; stands in for the
# whitespace the prose run requires, so decoding after extraction drops it.
check "nbsp-separated prose literal" deny '{"tool_name":"Edit","tool_input":{"file_path":"/Users/x/a.mjs","new_string":"const s = \"A&nbsp;branded&nbsp;balance&nbsp;customers&nbsp;load&nbsp;and&nbsp;spend&mdash;float&mdash;economics&mdash;more&mdash;yes\";"}}' "Em-dash density"
# A literal is not terminated by an escaped delimiter.
check "escaped quote in literal"     deny '{"tool_name":"Edit","tool_input":{"file_path":"/Users/x/a.mjs","new_string":"const s = \"he said \\\"paradigm shift\\\" and left the meeting today\";"}}' "shipped list"
# The removed side of an Edit is never scored (old_string is not a content key).
check "source edit ignores old_string" allow '{"tool_name":"Edit","tool_input":{"file_path":"/Users/x/a.mjs","old_string":"const old = \"Removed prose &mdash; with &mdash; three &mdash; dashes &mdash; here\";","new_string":"const ok = \"A clean replacement sentence with no dashes at all\";"}}'

STALE_HOOKS="$FIX/stale-hooks"
mkdir -p "$STALE_HOOKS"
cp -R "$(dirname "$GUARD")/." "$STALE_HOOKS/"
printf '2026-06-01\n' > "$STALE_HOOKS/signs-refresh-baseline.txt"
STALE_GUARD="$STALE_HOOKS/no-ai-slop-guard.py"
NUDGE_JSON='{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{"text":"Shipped the fix. Tests pass."}}'

check_silent() { # name  guard  home  json
  local name="$1" guard="$2" home="$3" json="$4"
  local out status
  out="$(printf '%s' "$json" | HOME="$home" python3 "$guard" 2>/dev/null)"
  status=$?
  if [ "$status" -eq 0 ] && [ -z "$out" ]; then
    pass=$((pass+1)); printf 'PASS  %-42s -> allow\n' "$name"
  else
    fail=$((fail+1)); printf 'FAIL  %-42s -> got output/status %q/%s, want silent/0\n' "$name" "$out" "$status"
  fi
}

mkdir -p "$FIX/nudge-home" "$FIX/fresh-state-home/.claude" "$FIX/deny-home" "$FIX/malformed-home/.claude"
HOME="$FIX/nudge-home" GUARD="$STALE_GUARD" check "stale clean emits nudge" allow "$NUDGE_JSON" "additionalContext" "!permissionDecision"
printf '{"last_refresh":"%s"}\n' "$(date +%F)" > "$FIX/fresh-state-home/.claude/no-ai-slop-refresh-state.json"
check_silent "fresh state suppresses nudge" "$STALE_GUARD" "$FIX/fresh-state-home" "$NUDGE_JSON"
check_silent "daily nudge throttle" "$STALE_GUARD" "$FIX/nudge-home" "$NUDGE_JSON"
HOME="$FIX/deny-home" GUARD="$STALE_GUARD" check "stale slop stays deny-only" deny '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{"text":"Let us delve into this tapestry of results."}}' '"permissionDecision": "deny"' "!additionalContext"
printf 'not json\n' > "$FIX/malformed-home/.claude/no-ai-slop-refresh-state.json"
check_silent "malformed state fails open" "$GUARD" "$FIX/malformed-home" "$NUDGE_JSON"
mkdir -p "$FIX/malformed-stale-home/.claude"
printf 'not json\n' > "$FIX/malformed-stale-home/.claude/no-ai-slop-refresh-state.json"
HOME="$FIX/malformed-stale-home" GUARD="$STALE_GUARD" check "malformed state still nudges when stale" allow "$NUDGE_JSON" "additionalContext" "!permissionDecision"

echo "-----"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
