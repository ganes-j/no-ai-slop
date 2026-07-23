#!/usr/bin/env python3
"""no-ai-slop PreToolUse guard.

Reads a PreToolUse hook payload on stdin. If the tool is a guarded output
surface (Notion / Slack / Gmail / Artifact / prose .md file) and the content
about to be posted contains a high-precision AI-slop phrase, the tool call is
DENIED with the flagged phrases in the reason, so the assistant rewrites the
draft clean and re-calls before anything is published. Clean content passes
silently.

The deny is the deterministic exact-phrase gate. The reason instructs a full
no-ai-slop rewrite (phrase + structural), so structural slop is caught in the
same pass on every guarded surface — not only exact-phrase hits.

Data files (edit these, not the code):
  slop-phrases.txt        one auto-block phrase per line
  prose-path-denylist.txt path patterns the .md guard skips
"""
import fnmatch
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PHRASES_FILE = os.path.join(HERE, "slop-phrases.txt")
DENYLIST_FILE = os.path.join(HERE, "prose-path-denylist.txt")

PROSE_EXTS = {".md", ".mdx", ".txt"}

# tool_name patterns for surfaces the guard covers. The settings/plugin matcher
# is the first filter; this is the authoritative second filter.
GUARDED_TOOL_RE = re.compile(
    r"(?:^|__)(?:Write|Edit|Artifact)$"
    r"|[Nn]otion.*(?:create|update|append|comment)"
    r"|[Ss]lack.*(?:send|post|reply|message)"
    r"|create_draft|update_draft|draft_email|send_email"
    r"|gmail_send|gmail_createDraft|gmail_sendDraft",
    re.IGNORECASE,
)

# keys whose string values carry user-facing prose across the guarded tools
CONTENT_KEYS = {
    "text", "message", "body", "content", "markdown", "md", "comment",
    "new_string", "html", "caption", "summary", "description", "rich_text",
    "value", "plain_text", "title",
}


def load_lines(path):
    try:
        with open(path, encoding="utf-8") as fh:
            out = []
            for line in fh:
                line = line.strip()
                if line and not line.startswith("#"):
                    out.append(line)
            return out
    except OSError:
        return []


def allow():
    # Exit 0 with no decision => tool proceeds normally.
    sys.exit(0)


def deny(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def collect_text(obj):
    """Recursively gather string values living under known content keys."""
    chunks = []

    def walk(node, under_content_key):
        if isinstance(node, str):
            if under_content_key:
                chunks.append(node)
        elif isinstance(node, dict):
            for k, v in node.items():
                walk(v, under_content_key or (k.lower() in CONTENT_KEYS))
        elif isinstance(node, list):
            for item in node:
                walk(item, under_content_key)

    walk(obj, False)
    return "\n".join(chunks)


def path_is_denied(file_path, denylist):
    ap = os.path.abspath(os.path.expanduser(file_path)).lower()
    base = os.path.basename(ap)
    for pat in denylist:
        p = pat.lower()
        if fnmatch.fnmatch(ap, p) or fnmatch.fnmatch(base, p):
            return True
        if "*" not in p and p in ap:
            return True
    return False


def find_hits(text, phrases):
    hits = []
    low = text.lower()
    for phrase in phrases:
        p = phrase.lower()
        # word-boundary match so "harness" never matches inside "harnessing"
        # for multiword phrases, \b around the whole phrase
        pattern = r"\b" + re.escape(p) + r"\b"
        if re.search(pattern, low):
            hits.append(phrase)
    return hits


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        allow()

    tool_name = data.get("tool_name", "") or ""
    tool_input = data.get("tool_input", {}) or {}

    if not GUARDED_TOOL_RE.search(tool_name):
        allow()

    # Write/Edit: only prose extensions, and never a denylisted path.
    short = tool_name.split("__")[-1]
    if short in ("Write", "Edit"):
        file_path = tool_input.get("file_path", "") or ""
        _, ext = os.path.splitext(file_path.lower())
        if ext not in PROSE_EXTS:
            allow()
        if path_is_denied(file_path, load_lines(DENYLIST_FILE)):
            allow()

    text = collect_text(tool_input)
    if not text.strip():
        allow()

    hits = find_hits(text, load_lines(PHRASES_FILE))
    if not hits:
        allow()

    surface = short or tool_name
    reason = (
        "AI-slop phrase(s) detected in content headed to {surface}: {hits}. "
        "Rewrite the draft to remove them, then re-issue the same call. "
        "Apply the no-ai-slop skill on the rewrite (phrase AND structural "
        "patterns — binary contrasts, fake-profound kickers, dramatic "
        "fragmentation, etc.), make the minimum effective edit, and preserve "
        "the author's voice. Do not strip legitimate meaning."
    ).format(surface=surface, hits=", ".join(repr(h) for h in hits))
    deny(reason)


if __name__ == "__main__":
    main()
