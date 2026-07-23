#!/usr/bin/env bash
# Feeds sample PreToolUse payloads to the guard and checks allow/deny.
# A "deny" prints JSON with permissionDecision:deny. An "allow" prints nothing.
set -u
GUARD="$(cd "$(dirname "$0")/.." && pwd)/hooks/no-ai-slop-guard.py"
pass=0; fail=0

FIX=/tmp/slop-test-fixtures; mkdir -p "$FIX"
printf "Let us delve into this tapestry of results." > "$FIX/artifact-slop.html"
printf "A clean sentence about payments and loyalty." > "$FIX/artifact-clean.html"

check() { # name  expected(allow|deny)  json
  local name="$1" expected="$2" json="$3"
  local out; out="$(printf '%s' "$json" | python3 "$GUARD" 2>/dev/null)"
  local got="allow"; echo "$out" | grep -q '"permissionDecision": "deny"' && got="deny"
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
check "gmail draft slop"  deny  '{"tool_name":"mcp__claude_ai_Gmail__create_draft","tool_input":{"body":"It is worth noting that this is a paradigm shift."}}'
check "gmail clean"       allow '{"tool_name":"mcp__gmail__draft_email","tool_input":{"body":"Following up on the invoice from Tuesday."}}'
check "artifact slop (file body)"  deny  "{\"tool_name\":\"Artifact\",\"tool_input\":{\"file_path\":\"$FIX/artifact-slop.html\",\"title\":\"x\"}}"
check "artifact clean (file body)" allow "{\"tool_name\":\"Artifact\",\"tool_input\":{\"file_path\":\"$FIX/artifact-clean.html\"}}"
check "artifact title slop"        deny  '{"tool_name":"Artifact","tool_input":{"file_path":"/tmp/slop-test-fixtures/artifact-clean.html","title":"a paradigm shift"}}'
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

echo "-----"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
