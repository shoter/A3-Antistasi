#!/usr/bin/env python3
"""
Renders the newest entry of CHANGELOG-unstable.md for the release workflows.

Every push to `unstable` gets one entry at the top of CHANGELOG-unstable.md (the rule lives in CLAUDE.md).
The release workflow publishes that entry as the body of the `unstable-latest` GitHub prerelease (Markdown),
the Steam workflow as the Workshop change note (BBCode). Both go through .github/actions/changelog,
which calls this script.

An entry is a level-2 Markdown heading (`## `) and everything up to the next one; the first entry in the
file is the newest.

Usage:
    python Tools/renderChangelog.py                     # newest entry as Markdown on stdout
    python Tools/renderChangelog.py --format bbcode     # newest entry as Steam BBCode on stdout
    python Tools/renderChangelog.py --format bbcode --max-chars 7000 --github-output bbcode
                                                        # append it as multi-line output "bbcode" to $GITHUB_OUTPUT

Runs on the stock Python 3 of the GitHub runners (3.8+), no dependencies.
"""
import argparse
import os
import re
import sys

DEFAULT_FILE = "CHANGELOG-unstable.md"
NO_ENTRY_NOTICE = "No changelog entry found in %s." % DEFAULT_FILE
OUTPUT_DELIMITER = "CHANGELOG_ENTRY_EOF"

HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
BULLET = re.compile(r"^(\s*)([-*+]|\d+[.)])\s+(.*)$")
CODE_SPAN = re.compile(r"`([^`]*)`")
INLINE_BBCODE = [
    (re.compile(r"!?\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)"), r"[url=\2]\1[/url]"),
    (re.compile(r"\*\*(.+?)\*\*"), r"[b]\1[/b]"),
    (re.compile(r"__(.+?)__"), r"[b]\1[/b]"),
    (re.compile(r"~~(.+?)~~"), r"[strike]\1[/strike]"),
    (re.compile(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])"), r"[i]\1[/i]"),
    (re.compile(r"(?<!\w)_(?!\s)(.+?)(?<!\s)_(?!\w)"), r"[i]\1[/i]"),
]


def latest_entry(text):
    """Lines of the topmost `## ` entry, [] when the file has none."""
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    starts = [i for i, line in enumerate(lines) if line.startswith("## ")]
    if not starts:
        return []
    end = starts[1] if len(starts) > 1 else len(lines)
    entry = [line.rstrip() for line in lines[starts[0]:end]]
    while entry and not entry[-1]:
        entry.pop()
    return entry


def render_markdown(entry):
    """Returns (lines, tags open after each line). Markdown has nothing to close when truncated."""
    return entry, [[] for _ in entry]


def inline_bbcode(text):
    """Converts inline Markdown to BBCode and makes the text safe for the Steam manifest."""
    spans = []

    def stash(match):
        spans.append(match.group(1))
        return "\x00%d\x00" % (len(spans) - 1)

    text = CODE_SPAN.sub(stash, text)
    for pattern, replacement in INLINE_BBCODE:
        text = pattern.sub(replacement, text)
    text = re.sub("\x00(\\d+)\x00", lambda match: spans[int(match.group(1))], text)
    # The Steam deploy action pastes the note into a double-quoted VDF string without escaping anything,
    # so a stray quote or backslash would cut the note short or corrupt the manifest.
    return text.replace('"', "'").replace("\\", "/")


def render_bbcode(entry):
    """Returns (lines, tags open after each line) in Steam BBCode."""
    out = []
    open_after = []
    stack = []  # open lists as (indent, tag)
    pending_blank = False

    def emit(line):
        out.append(line)
        open_after.append([tag for _, tag in stack])

    def close_lists(down_to=-1):
        while stack and stack[-1][0] > down_to:
            emit("[/%s]" % stack.pop()[1])

    for line in entry:
        if not line.strip():
            pending_blank = True
            continue
        bullet = BULLET.match(line)
        if bullet:
            indent = len(bullet.group(1).expandtabs(4))
            tag = "olist" if bullet.group(2)[0].isdigit() else "list"
            close_lists(indent)
            if stack and stack[-1][0] == indent and stack[-1][1] != tag:
                emit("[/%s]" % stack.pop()[1])
            if not stack or stack[-1][0] < indent:
                stack.append((indent, tag))
                emit("[%s]" % tag)
            emit("[*]" + inline_bbcode(bullet.group(3)))
            pending_blank = False
            continue
        if stack and line[0].isspace():
            emit(inline_bbcode(line.strip()))  # continuation of the previous item
            pending_blank = False
            continue
        close_lists()
        if pending_blank and out:
            emit("")
        pending_blank = False
        heading = HEADING.match(line)
        if heading:
            text = inline_bbcode(heading.group(2))
            emit("[h3]%s[/h3]" % text if len(heading.group(1)) <= 2 else "[b]%s[/b]" % text)
        elif line.strip() in ("---", "***", "___"):
            emit("[hr][/hr]")
        else:
            emit(inline_bbcode(line.strip()))
    close_lists()
    return out, open_after


def finish(lines, open_after, max_chars, closer, marker):
    """Joins the lines, cutting at a line boundary and closing open lists when the result is too long."""
    text = "\n".join(lines)
    if max_chars is None or len(text) <= max_chars:
        return text
    for keep in range(len(lines), 0, -1):
        closers = [closer % tag for tag in reversed(open_after[keep - 1])]
        candidate = "\n".join(lines[:keep] + closers + [marker])
        if len(candidate) <= max_chars:
            return candidate
    return marker[:max_chars]


FORMATS = {
    "markdown": (render_markdown, "%s", "_(truncated, the full notes are in CHANGELOG-unstable.md)_"),
    "bbcode": (render_bbcode, "[/%s]", "[i](truncated, the full notes are in CHANGELOG-unstable.md)[/i]"),
}


def main(argv=None):
    parser = argparse.ArgumentParser(description="Render the newest entry of %s." % DEFAULT_FILE)
    parser.add_argument("--file", default=DEFAULT_FILE, help="changelog to read (default: %(default)s)")
    parser.add_argument("--format", choices=sorted(FORMATS), default="markdown",
                        help="output format (default: %(default)s)")
    parser.add_argument("--max-chars", type=int,
                        help="cut the output to this many characters at a line boundary, closing open lists")
    parser.add_argument("--out", help="write the output to this file (UTF-8, LF) instead of stdout")
    parser.add_argument("--github-output", metavar="NAME",
                        help="append the output as multi-line output NAME to the file named by $GITHUB_OUTPUT")
    args = parser.parse_args(argv)

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    try:
        with open(args.file, encoding="utf-8-sig") as handle:
            entry = latest_entry(handle.read())
    except OSError as error:
        print("::warning::%s: %s" % (args.file, error))
        entry = []

    if entry:
        render, closer, marker = FORMATS[args.format]
        lines, open_after = render(entry)
        rendered = finish(lines, open_after, args.max_chars, closer, marker)
    else:
        print("::warning file=%s::%s Every push to unstable needs an entry, see CLAUDE.md." % (args.file, NO_ENTRY_NOTICE))
        rendered = NO_ENTRY_NOTICE

    if args.out:
        with open(args.out, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(rendered + "\n")
    if args.github_output:
        path = os.environ.get("GITHUB_OUTPUT")
        if not path:
            sys.exit("--github-output needs the GITHUB_OUTPUT environment variable, which GitHub Actions sets")
        delimiter = OUTPUT_DELIMITER
        while delimiter in rendered:
            delimiter += "_"
        with open(path, "a", encoding="utf-8", newline="\n") as handle:
            handle.write("%s<<%s\n%s\n%s\n" % (args.github_output, delimiter, rendered, delimiter))
    if not args.out:
        print(rendered)
    return 0


if __name__ == "__main__":
    sys.exit(main())
