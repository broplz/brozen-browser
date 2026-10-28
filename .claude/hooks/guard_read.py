#!/usr/bin/env python3
"""PreToolUse hook for Read | Grep | Glob — context protection.

Firefox's tree (engine/) is ~300k files; one careless Read or Grep can fill a context window.
Agents read engine/ and other big trees only in slices (offset/limit) and grep them only with a
narrowing glob/type and a head_limit. Raw logs go through triage_log.py. Secrets are never read.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bb_hooklib as h  # noqa: E402

NEVER = ["**/.env", "**/*.env", "**/*secret*", "**/*Secret*", "build/signing/**", ".surfer/**", ".git/**"]
BIG_TREES = ("engine/", "node_modules/", "locales/", ".surfer/", "logs/")
BIG_FILES = {"package-lock.json", "tsconfig.json"}
READ_LIMIT = 400          # max lines per Read inside a big tree
SIZE_LIMIT = 300 * 1024   # bytes: bigger files anywhere need offset/limit
GREP_LIMIT = 150          # max head_limit inside a big tree / at the repo root


def main():
    if h.unlocked():
        sys.exit(0)
    data = h.load()
    tool = data.get("tool_name", "")
    ti = data.get("tool_input") or {}
    role = h.role(data)
    root = h.root(data)

    if tool == "Read":
        fp = ti.get("file_path") or ""
        if not fp:
            sys.exit(0)
        rel = h.relpath(data, fp)
        if h.matches(rel, NEVER):
            h.block(f"{rel}: secrets/generated state are never read.")
        if role == "human":
            sys.exit(0)
        limit = ti.get("limit")
        if rel.endswith(".log"):
            h.block(f"{rel}: raw logs flood the context. Use `python3 scripts/agents/triage_log.py {rel}` "
                    "(build.sh/test.sh already print it), or `tail -n 40` via Bash.")
        if (rel.startswith(BIG_TREES) or os.path.basename(rel) in BIG_FILES) and (not limit or int(limit) > READ_LIMIT):
            h.block(f"{rel}: inside a big tree. Read it in slices (offset + limit ≤ {READ_LIMIT}) after locating the "
                    "spot with Grep (glob/type + head_limit), or read the Zen copy under src/ instead.")
        try:
            size = os.path.getsize(os.path.join(root, rel))
        except OSError:
            size = 0
        if size > SIZE_LIMIT and not limit:
            h.block(f"{rel} is {size // 1024} KB. Read it with offset/limit or Grep it.")
        sys.exit(0)

    if role == "human":
        sys.exit(0)

    if tool == "Grep":
        path = ti.get("path") or "."
        rel = h.relpath(data, path)
        narrow = bool(ti.get("glob") or ti.get("type"))
        hl = ti.get("head_limit")
        big = rel in (".", "") or rel.startswith(BIG_TREES) or rel.rstrip("/") in ("engine", "node_modules", "locales", "src")
        if big and not narrow:
            h.block(f"Grep over `{rel}` needs a narrowing `glob` or `type` (e.g. glob \"*.mjs\") — it is a huge tree.")
        if big and (hl is None or int(hl) > GREP_LIMIT):
            h.block(f"Grep over `{rel}` needs head_limit ≤ {GREP_LIMIT} (and files_with_matches mode first, then content on one file).")
        sys.exit(0)

    if tool == "Glob":
        pattern = ti.get("pattern") or ""
        path = ti.get("path") or "."
        rel = h.relpath(data, path)
        target = (rel.rstrip("/") + "/" + pattern) if rel not in (".", "") else pattern
        parts = target.split("/")
        huge = (target.startswith("**") or parts[0] in ("node_modules", ".surfer")
                or (parts[0] in ("engine", "locales") and (len(parts) < 2 or "*" in parts[1])))
        if huge:
            h.block(f"Glob `{target}` would walk a huge tree. Start from a known subdirectory (e.g. engine/browser/base/content/**).")
        sys.exit(0)
    sys.exit(0)


if __name__ == "__main__":
    main()
