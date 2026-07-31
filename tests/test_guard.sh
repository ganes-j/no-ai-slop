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

echo "-----"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
