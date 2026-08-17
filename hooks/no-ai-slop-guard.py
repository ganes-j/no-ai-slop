#!/usr/bin/env python3
"""no-ai-slop PreToolUse guard.

Reads a PreToolUse hook payload on stdin. If the tool is a guarded output
surface (Notion / Slack / Gmail / Artifact / prose .md file) and the content
about to be posted contains a deterministic AI-slop violation, the tool call
is DENIED with every violation in the reason, so the assistant rewrites the
draft clean and re-calls before anything is published. Clean content passes
silently.

The deny is the deterministic gate. The reason instructs a full
no-ai-slop rewrite (phrase + structural), so structural slop is caught in the
same pass on every guarded surface — not only exact-phrase hits.

Data files (edit these, not the code):
  slop-phrases.txt                         shipped auto-block phrases
  .no-ai-slop-phrases.txt                  project auto-block phrases
  ~/.claude/no-ai-slop-phrases.local.txt   personal auto-block phrases
  prose-path-denylist.txt                  path patterns the .md guard skips
"""
import datetime
import fnmatch
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PHRASES_FILE = os.path.join(HERE, "slop-phrases.txt")
DENYLIST_FILE = os.path.join(HERE, "prose-path-denylist.txt")
BASELINE_FILE = os.path.join(HERE, "signs-refresh-baseline.txt")
PROJECT_PHRASES_FILE = ".no-ai-slop-phrases.txt"
PERSONAL_PHRASES_FILE = "~/.claude/no-ai-slop-phrases.local.txt"
STATE_FILE = "~/.claude/no-ai-slop-refresh-state.json"
REFRESH_INTERVAL_DAYS = 30

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
    "new_string", "new_str", "html", "caption", "summary", "description", "rich_text",
    "value", "plain_text", "title",
}

EM_DASH_DENSITY_MIN_COUNT = 2
EM_DASH_DENSITY_CHARS = 350
EM_DASH_PARAGRAPH_MIN_COUNT = 3
ING_ANALYSIS_TAIL_WORDS = (
    "highlighting", "underscoring", "showcasing", "demonstrating", "signaling",
)

# Up to three leading spaces is still a valid markdown heading.
MARKDOWN_HEADING_RE = re.compile(r"^ {0,3}#{1,6}\s")
# U+1F1E6 start covers regional-indicator (flag) emoji.
HEADING_EMOJI_RE = re.compile(
    r"[\U0001F1E6-\U0001FAFF\u2600-\u27BF\uFE0F]"
)
# Comma then spaces, or at most ONE newline (soft wrap) \u2014 never a paragraph break.
ING_ANALYSIS_TAIL_RE = re.compile(
    r",(?:[ \t]+|[ \t]*\n[ \t]*)(?:{words})\s+\w+".format(
        words="|".join(ING_ANALYSIS_TAIL_WORDS)
    ),
    re.IGNORECASE,
)

REWRITE_INSTRUCTION = (
    "Rewrite the draft to remove them, then re-issue the same call. "
    "Apply the no-ai-slop skill on the rewrite (phrase AND structural "
    "patterns — binary contrasts, fake-profound kickers, dramatic "
    "fragmentation, etc.), make the minimum effective edit, and preserve "
    "the author's voice. Do not strip legitimate meaning."
)


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


def load_refresh_baseline():
    try:
        with open(BASELINE_FILE, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line and not line.startswith("#"):
                    return datetime.date.fromisoformat(line)
    except (OSError, ValueError):
        return None
    return None


def load_refresh_state():
    try:
        with open(os.path.expanduser(STATE_FILE), encoding="utf-8") as fh:
            state = json.load(fh)
        if not isinstance(state, dict):
            raise ValueError
        last_refresh = (
            datetime.date.fromisoformat(state["last_refresh"])
            if "last_refresh" in state
            else None
        )
        last_nudge = (
            datetime.date.fromisoformat(state["last_nudge"])
            if "last_nudge" in state
            else None
        )
        return state, last_refresh, last_nudge
    except (OSError, TypeError, ValueError):
        return {}, None, None


def refresh_nudge():
    baseline = load_refresh_baseline()
    state, last_refresh, last_nudge = load_refresh_state()
    refresh_dates = [value for value in (baseline, last_refresh) if value]
    if not refresh_dates:
        return None

    effective = max(refresh_dates)
    today = datetime.date.today()
    age = (today - effective).days
    if age <= REFRESH_INTERVAL_DAYS or last_nudge == today:
        return None

    state["last_nudge"] = today.isoformat()
    state_path = os.path.expanduser(STATE_FILE)
    try:
        os.makedirs(os.path.dirname(state_path), exist_ok=True)
        with open(state_path, "w", encoding="utf-8") as fh:
            json.dump(state, fh)
    except OSError:
        pass

    return (
        "no-ai-slop guidelines were last refreshed {effective} ({age} days ago). "
        "Run the plugin's refresh-signs workflow to pull new signs from Wikipedia's "
        "'Signs of AI writing' "
        "(https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) and update "
        "the guard's data files."
    ).format(effective=effective.isoformat(), age=age)


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


def read_file_text(path):
    """Read a referenced file's text (for tools whose body lives in a file,
    e.g. Artifact). Best-effort; returns '' if unreadable."""
    if not path:
        return ""
    p = os.path.abspath(os.path.expanduser(path))
    try:
        with open(p, encoding="utf-8", errors="ignore") as fh:
            return fh.read()
    except OSError:
        return ""


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
    if not phrases:
        return []
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


def check_phrases(text, data):
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd", "")
    phrase_sources = [
        ("shipped list", PHRASES_FILE),
        (
            "project list",
            os.path.join(project_dir, PROJECT_PHRASES_FILE) if project_dir else "",
        ),
        ("personal list", os.path.expanduser(PERSONAL_PHRASES_FILE)),
    ]
    violations = []
    for source, path in phrase_sources:
        hits = find_hits(text, load_lines(path)) if path else []
        if hits:
            violations.append(
                "AI-slop phrase(s) detected from {source}: {hits}.".format(
                    source=source,
                    hits=", ".join(repr(hit) for hit in hits),
                )
            )
    return violations


def check_em_dash_density(text, _data):
    count = text.count("—")
    dense_document = (
        count >= EM_DASH_DENSITY_MIN_COUNT
        and count * EM_DASH_DENSITY_CHARS > len(text)
    )
    if not dense_document and count < EM_DASH_PARAGRAPH_MIN_COUNT:
        return []
    paragraphs = re.split(r"\n\s*\n", text)
    max_paragraph_count = max(paragraph.count("—") for paragraph in paragraphs)
    dense_paragraph = max_paragraph_count >= EM_DASH_PARAGRAPH_MIN_COUNT
    if not dense_document and not dense_paragraph:
        return []
    return [
        "Em-dash density detected: {count} em dashes across {chars} characters; "
        "densest paragraph has {paragraph_count}.".format(
            count=count,
            chars=len(text),
            paragraph_count=max_paragraph_count,
        )
    ]


def check_heading_emoji(text, _data):
    heading_count = 0
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if MARKDOWN_HEADING_RE.match(line) and HEADING_EMOJI_RE.search(line):
            heading_count += 1
    if not heading_count:
        return []
    return [
        "Emoji in Markdown heading detected on {count} line(s).".format(
            count=heading_count
        )
    ]


def check_ing_analysis_tails(text, _data):
    matches = ING_ANALYSIS_TAIL_RE.findall(text)
    if not matches:
        return []
    return [
        "-ing analysis tail(s) detected: {matches}.".format(
            matches=", ".join(repr(match) for match in matches)
        )
    ]


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        allow()

    tool_name = data.get("tool_name", "") or ""
    tool_input = data.get("tool_input", {}) or {}

    if not GUARDED_TOOL_RE.search(tool_name):
        allow()

    short = tool_name.split("__")[-1]
    if short in ("Write", "Edit"):
        # Write/Edit: only prose extensions, and never a denylisted path.
        file_path = tool_input.get("file_path", "") or ""
        _, ext = os.path.splitext(file_path.lower())
        if ext not in PROSE_EXTS:
            allow()
        if path_is_denied(file_path, load_lines(DENYLIST_FILE)):
            allow()
        text = collect_text(tool_input)
    elif short == "Artifact":
        # The Artifact body lives in a file referenced by file_path, not inline
        # in tool_input, so scan that file in addition to title/description.
        text = collect_text(tool_input) + "\n" + read_file_text(tool_input.get("file_path", "") or "")
    else:
        text = collect_text(tool_input)

    if not text.strip():
        allow()

    violations = []
    checks = (
        check_phrases,
        check_em_dash_density,
        check_heading_emoji,
        check_ing_analysis_tails,
    )
    for check in checks:
        violations.extend(check(text, data))

    if not violations:
        nudge = refresh_nudge()
        if nudge:
            print(json.dumps({
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "additionalContext": nudge,
                }
            }))
            sys.exit(0)
        allow()

    surface = short or tool_name
    reason = (
        "Content headed to {surface} has these violations:\n- {violations}\n\n"
        "{instruction}"
    ).format(
        surface=surface,
        violations="\n- ".join(violations),
        instruction=REWRITE_INSTRUCTION,
    )
    deny(reason)


if __name__ == "__main__":
    main()
