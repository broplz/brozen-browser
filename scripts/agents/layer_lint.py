#!/usr/bin/env python3
"""Deterministic check of a task's diff against the ADR-0002 layer rules. Zero tokens.

    layer_lint.py <task-id|file> [--base <branch>] [--branch <branch>]

Exit: 0 clean · 1 FAIL (rule broken) · 3 clean but needs human approval (C++/ObjC/IDL or a Zen patch
was changed — ADR-0002 §2 p.5). WARN lines never fail. Run by qa, by merge_task.py and by hand.
"""
import argparse
import os
import re
import subprocess
import sys

import config
import pipeline_lib as pl
from taskfile import TaskFile

CLASS2 = [r"^src/zen/", r"^src/browser/base/content/zen-[^/]*\.inc\.", r"^src/browser/base/content/zen-assets",
          r"^prefs/zen/", r"^configs/(common|macos)/mozconfig$", r"^package\.json$", r"^surfer\.json$"]
SCOPE_FREE = [r"^tasks/", r"^logs/", r"^docs/notes/", r"^docs/reports/", r"^tasks/backlog\.md$", r"^\.claude/agent-memory/"]
PROD_EXCLUDE = [r"(^|/)README\.md$", r"\.md$", r"^tasks/", r"^docs/", r"(^|/)tests?/", r"^\.claude/agent-memory/"]
README_KEYS = ("epic", "adr", "files", "rebuild")
ZEN_PREF_DIRS = ("prefs/zen", "prefs/firefox", "prefs/fastfox", "prefs/privatefox")
STRIP_YAML = "prefs/bb/strip.yaml"
PREF_NAME_RE = re.compile(r"^\s*-\s*name:\s*([^\s#]+)", re.M)


def zen_pref_names(branch):
    files = pl.git_out("ls-tree", "-r", "--name-only", branch, "--", *ZEN_PREF_DIRS).splitlines()
    return {m for f in files if f.endswith(".yaml") for m in PREF_NAME_RE.findall(file_text(f, branch))}


def prefs_fails(path, text, zen_names):
    fails = []
    for name in PREF_NAME_RE.findall(text):
        if name.startswith("bb."):
            continue
        if path != STRIP_YAML:
            fails.append(f"{path}: pref {name} outside the bb.* namespace (Zen defaults change in prefs/zen/)")
        elif name in zen_names:
            fails.append(f"{path}: pref {name}: Zen задаёт этот pref: не дублировать")
    return fails


def changed_files(base, branch):
    names = pl.git_out("diff", "--name-only", f"{base}...{branch}").splitlines()
    if pl.current_branch() == branch:          # uncommitted work counts too
        names += pl.git_out("diff", "--name-only", "HEAD").splitlines()
        names += pl.git_out("ls-files", "--others", "--exclude-standard").splitlines()
    return sorted({n for n in names if n})


def file_text(path, branch):
    if pl.current_branch() == branch and os.path.exists(os.path.join(config.ROOT, path)):
        with open(os.path.join(config.ROOT, path), encoding="utf-8", errors="replace") as f:
            return f.read()
    r = pl.git("show", f"{branch}:{path}", check=False)
    return r.stdout if r.returncode == 0 else ""


def added_lines(path, base, branch):
    r = pl.git("diff", f"{base}...{branch}", "--", path, check=False)
    out = r.stdout.splitlines() if r.returncode == 0 else []
    if pl.current_branch() == branch:
        out += pl.git("diff", "HEAD", "--", path, check=False).stdout.splitlines()
    return [l[1:] for l in out if l.startswith("+") and not l.startswith("+++")]


def patch_targets(text):
    return [m.group(1) for m in re.finditer(r"^\+\+\+ (?:b/)?(\S+)", text, re.M) if m.group(1) != "/dev/null"]


def match(path, patterns):
    return any(re.search(p, path) for p in patterns)


def glob_to_re(pattern):
    out, i = "^", 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out += "(?:.*/)?"; i += 3
        elif pattern.startswith("**", i):
            out += ".*"; i += 2
        elif pattern[i] == "*":
            out += "[^/]*"; i += 1
        else:
            out += re.escape(pattern[i]); i += 1
    return out + "$"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("task")
    ap.add_argument("--base")
    ap.add_argument("--branch")
    a = ap.parse_args()
    tf = TaskFile(pl.find_task(a.task))
    base = a.base or pl.task_base(tf)
    branch = a.branch or (pl.task_branch(tf) if pl.branch_exists(pl.task_branch(tf)) else "HEAD")
    files = changed_files(base, branch)
    fails, warns, notes = [], [], []
    needs_approval = False
    allowed = [glob_to_re(p) for p in tf.getlist("allowed_paths")] + [glob_to_re(pl.rel(tf.path))]
    layer_yaml = file_text("src/bb/layer.yaml", branch)
    if not layer_yaml:
        warns.append("src/bb/layer.yaml is missing on this branch — fine only for the task that creates it")

    prod_lines = 0
    for path in files:
        if match(path, [r"^engine/", r"^node_modules/", r"^\.surfer/"]):
            fails.append(f"{path}: generated tree changed (engine/ is reset by surfer; patch it instead)")
            continue
        if re.search(r"^src/zen/.*\.patch$", path):
            fails.append(f"{path}: .patch under src/zen/ can never apply (symlinks) — edit the Zen file directly (class 2)")
        elif path.endswith(".patch") and not path.startswith("src/bb/patches/"):
            if tf.getbool("allow_zen_patch"):
                needs_approval = True
                if layer_yaml and path not in layer_yaml:
                    fails.append(f"{path}: Zen patch changed but not listed under zen_patches in src/bb/layer.yaml")
                notes.append(f"{path}: Zen patch edited (allow_zen_patch) — human approval required")
            else:
                fails.append(f"{path}: Zen's patch changed; allowed only with allow_zen_patch: true when hunks intersect (ADR-0002 §2 p.4)")
        elif path.startswith("src/bb/patches/"):
            parts = path.split("/")          # src/bb/patches/<epic>/<name>/<file>
            if len(parts) != 6:
                fails.append(f"{path}: expected src/bb/patches/<epic>/<name>/<file>")
            elif path.endswith(".patch"):
                readme = "/".join(parts[:5]) + "/README.md"
                text = file_text(readme, branch)
                if not text:
                    fails.append(f"{path}: no README.md next to the patch")
                else:
                    fm = text.split("---")[1] if text.startswith("---") and text.count("---") >= 2 else ""
                    missing = [k for k in README_KEYS if not re.search(rf"^{k}:", fm, re.M)]
                    if missing:
                        fails.append(f"{readme}: frontmatter lacks {', '.join(missing)}")
                for target in patch_targets(file_text(path, branch)):
                    if re.search(config.APPROVAL_RE, target):
                        needs_approval = True
                        notes.append(f"{path}: patches {target} (C++/ObjC/IDL) — human approval required")
        if match(path, CLASS2):
            if layer_yaml and path not in layer_yaml:
                fails.append(f"{path}: Zen file edited but not registered in src/bb/layer.yaml (hooks/edits)")
            if not any("BB(" in l for l in added_lines(path, base, branch)):
                fails.append(f"{path}: Zen file edited without a `BB(eN)` marker on the added lines")
        if re.search(r"^prefs/bb/.*\.ya?ml$", path):
            fails += prefs_fails(path, file_text(path, branch), zen_pref_names(branch))
        if re.search(config.APPROVAL_RE, path):
            needs_approval = True
            notes.append(f"{path}: C++/ObjC/IDL source changed — human approval required")
        if not match(path, SCOPE_FREE) and allowed and not any(re.match(p, path) for p in allowed):
            fails.append(f"{path}: outside the task's allowed_paths")
        for l in added_lines(path, base, branch):
            if re.search(r"\b(TODO|FIXME|XXX)\b", l) and not re.search(r"\b(TODO|FIXME|XXX)\b\s*[:(]?\s*\d{4}", l):
                fails.append(f"{path}: TODO/FIXME without a task id: {l.strip()[:80]}")
                break
        if not match(path, PROD_EXCLUDE):
            prod_lines += len(added_lines(path, base, branch))

    size = tf.get("size", "M").upper()
    cap_lines, cap_files = config.SIZE_CAPS.get(size, config.SIZE_CAPS["M"])
    prod_files = [f for f in files if not match(f, PROD_EXCLUDE)]
    if prod_lines > cap_lines or len(prod_files) > cap_files:
        warns.append(f"size {size}: {prod_lines} added production lines in {len(prod_files)} files "
                     f"(cap {cap_lines}/{cap_files}) — teamlead: consider splitting next time")

    for l in fails:
        print("FAIL " + l)
    for l in warns:
        print("WARN " + l)
    for l in notes:
        print("NOTE " + l)
    print(f"layer_lint: {len(files)} files, {prod_lines} production lines, {len(fails)} fail, {len(warns)} warn"
          + (", NEEDS APPROVAL" if needs_approval else ""))
    if fails:
        return 1
    return 3 if needs_approval else 0


if __name__ == "__main__":
    sys.exit(main())
