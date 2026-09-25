#!/usr/bin/env python3
"""Colored output formatter for the Globomantics ZAP demos.

Every demo script prints through this one module so that all on-screen output
shares one look: boxed headers that say *what* you are seeing and *why*, the
"star" line format (one highlighted line, one blank line), and consistent
PASS / FAIL / FIX styling.

------------------------------------------------------------------------------
COLOR PALETTE  --  swap these six values for the official palette.
------------------------------------------------------------------------------
The values below are neutral placeholders. When the official color guide is
available, change ONLY the hex-to-ANSI numbers in PALETTE; nothing else in any
script needs to change.
"""
import json
import os
import sys

# --- Palette (placeholder values; replace with the official palette) --------
# Each entry is a standard 256-color ANSI code.
PALETTE = {
    "header":    45,   # cyan  - box borders / titles
    "label":    247,   # grey  - the label part of a star line
    "value":    231,   # white - the value part of a star line
    "focus":    226,   # yellow- the ONE field we want the audience to read
    "pass":      42,   # green - a check that passed
    "fail":     196,   # red   - a check that failed
    "fix":      214,   # orange- the suggested fix / prompt
    "muted":    240,   # dim   - secondary text
}
_USE_COLOR = sys.stdout.isatty() or os.environ.get("FORCE_COLOR") == "1"


def _c(code: int, text: str) -> str:
    if not _USE_COLOR:
        return text
    return f"\033[38;5;{code}m{text}\033[0m"


def _w(name: str, text: str) -> str:
    return _c(PALETTE[name], text)


# --- Public helpers ---------------------------------------------------------
def header(what: str, why: str = "", width: int = 74) -> None:
    """A boxed header: WHAT we are showing and WHY we are showing it."""
    line = "─" * (width - 2)
    print(_w("header", f"┌{line}┐"))
    for row in _wrap(f"WHAT:  {what}", width - 4):
        print(_w("header", "│ ") + row.ljust(width - 4) + _w("header", " │"))
    if why:
        for row in _wrap(f"WHY:   {why}", width - 4):
            print(_w("header", "│ ") + _w("muted", row.ljust(width - 4)) + _w("header", " │"))
    print(_w("header", f"└{line}┘"))


def star(label: str, value: str, focus: bool = False) -> None:
    """A single highlighted line in the mandated star format.

    Prints:  ★ <label>: <value>   followed by one blank line.
    When focus=True the value is drawn in the focus color (the field the
    author reads aloud). Values are never truncated.
    """
    bullet = _w("focus" if focus else "header", "★")
    lab = _w("label", f"{label}:")
    val = _w("focus" if focus else "value", value)
    print(f"  {bullet} {lab} {val}")
    print()


def section(title: str) -> None:
    print(_w("header", f"{title}:"))
    print()


def item(text: str, focus: bool = False) -> None:
    bullet = _w("focus" if focus else "header", "★")
    body = _w("focus" if focus else "value", text)
    print(f"  {bullet} {body}")
    print()


def ok(msg: str) -> None:
    print(f"{_w('pass', '✔ PASS')}  {msg}")


def bad(msg: str, reason: str = "", fix: str = "") -> None:
    print(f"{_w('fail', '✘ FAIL')}  {msg}")
    if reason:
        print(f"        {_w('muted', 'why: ')}{reason}")
    if fix:
        print(f"        {_w('fix', 'fix: ')}{_w('fix', fix)}")


def note(text: str) -> None:
    print(_w("muted", text))


def _wrap(text: str, width: int):
    words, line, out = text.split(), "", []
    for word in words:
        if len(line) + len(word) + 1 > width:
            out.append(line)
            line = word
        else:
            line = f"{line} {word}".strip()
    out.append(line)
    return out or [""]


# --- CLI so bash scripts can call the same formatter ------------------------
def _main(argv) -> int:
    if not argv:
        print("usage: fmt.py {header|star|section|item|ok|fail|note|json} ...", file=sys.stderr)
        return 2
    cmd, args = argv[0], argv[1:]
    if cmd == "header":
        header(args[0], args[1] if len(args) > 1 else "")
    elif cmd == "star":
        star(args[0], args[1], focus=(len(args) > 2 and args[2] == "focus"))
    elif cmd == "section":
        section(args[0])
    elif cmd == "item":
        item(args[0], focus=(len(args) > 1 and args[1] == "focus"))
    elif cmd == "ok":
        ok(args[0])
    elif cmd == "fail":
        bad(args[0], args[1] if len(args) > 1 else "", args[2] if len(args) > 2 else "")
    elif cmd == "note":
        note(args[0])
    elif cmd == "json":
        # json <focus_key,focus_key,...>  -- reads JSON on stdin, prints each
        # requested field as a star line; focus keys use the focus color.
        focus_keys = set(args[0].split(",")) if args else set()
        keys = args[1].split(",") if len(args) > 1 else None
        data = json.load(sys.stdin)
        rows = data if isinstance(data, list) else [data]
        for row in rows:
            for key, val in row.items():
                if keys and key not in keys:
                    continue
                star(key, json.dumps(val) if isinstance(val, (dict, list)) else str(val),
                     focus=(key in focus_keys))
    else:
        print(f"unknown command: {cmd}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
