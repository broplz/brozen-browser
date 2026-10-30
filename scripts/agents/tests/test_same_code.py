#!/usr/bin/env python3
"""pipeline_lib.same_code: a verdict sha survives a clean rebase (same patch-id) but not a code change."""
import os
import subprocess
import sys
import tempfile

AGENTS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, AGENTS)

import config  # noqa: E402
import pipeline_lib as pl  # noqa: E402

ENV = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t",
       "GIT_COMMITTER_EMAIL": "t@t", "GIT_EDITOR": "true"}


def g(*args, check=True):
    r = subprocess.run(["git", *args], cwd=config.ROOT, env=ENV, capture_output=True, text=True, check=False)
    assert not check or r.returncode == 0, f"git {args}: {r.stderr}"
    return r


def commit(path, text, msg):
    full = os.path.join(config.ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as f:
        f.write(text)
    g("add", "-A")
    g("commit", "-q", "-m", msg)
    return g("rev-parse", "HEAD").stdout.strip()


def sha(rev):
    return g("rev-parse", rev).stdout.strip()


def main():
    config.ROOT = tempfile.mkdtemp(prefix="same_code_")
    g("init", "-q", "-b", "base")
    commit("a.txt", "".join(f"line {i}\n" for i in range(20)), "init")

    # a, b: code commit then a tasks/ commit
    g("switch", "-q", "-c", "task")
    code = commit("src/b.txt", "feature\n", "code")
    commit("tasks/t.md", "x\n", "task file")
    assert pl.same_code("base", code, "task"), "a/b: verdict = code head"
    assert pl.same_code("base", sha("task"), "task"), "a: sha == branch head"

    # c: base gains an unrelated commit, task rebased onto it
    g("switch", "-q", "base")
    commit("other.txt", "unrelated\n", "unrelated")
    g("switch", "-q", "task")
    g("rebase", "base")
    assert sha(pl.code_head("task")) != code, "rebase must change the sha"
    assert pl.same_code("base", code, "task"), "c: clean rebase keeps patch-id"

    # d: code added after the verdict
    commit("src/c.txt", "more\n", "more code")
    assert not pl.same_code("base", code, "task"), "d: code changed after the verdict"

    # e: conflict resolved differently
    g("switch", "-q", "base")
    g("switch", "-q", "-c", "task2")
    old = commit("a.txt", "".join(f"line {i}\n" for i in range(19)) + "task side\n", "task edit")
    g("switch", "-q", "base")
    commit("a.txt", "".join(f"line {i}\n" for i in range(19)) + "base side\n", "base edit")
    g("switch", "-q", "task2")
    assert g("rebase", "base", check=False).returncode != 0, "e: conflict expected"
    with open(os.path.join(config.ROOT, "a.txt"), "w", encoding="utf-8") as f:
        f.write("".join(f"line {i}\n" for i in range(19)) + "resolved differently\n")
    g("add", "a.txt")
    g("rebase", "--continue")
    assert not pl.same_code("base", old, "task2"), "e: different resolution"

    # f: unknown sha
    assert pl.same_code("base", "0" * 40, "task") is False, "f: missing object"

    import merge_task  # noqa: E402
    assert hasattr(merge_task, "gates"), "merge_task.gates missing"
    print("test_same_code: OK")


if __name__ == "__main__":
    main()
