#!/usr/bin/env python3
"""run_task driver checks, in-process with subprocess, git and notify stubbed:
run_agent blocks only when no session started, set_blocked keeps an already blocked task,
--once returns 2 when the step left the task blocked.

    python3 scripts/agents/tests/check_run_task.py      (from the repo root; exit 1 on any FAIL)
"""
import json
import os
import sys
import tempfile
import types

AGENTS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TMP_DIR = tempfile.TemporaryDirectory(prefix="bb-check-run-task-")   # removed at exit
TMP = TMP_DIR.name
os.environ["BB_LOG_DIR"] = os.path.join(TMP, "logs")
sys.path.insert(0, AGENTS)

import config  # noqa: E402
import pipeline_lib as pl  # noqa: E402
import run_task  # noqa: E402
from taskfile import TaskFile  # noqa: E402

with open(os.path.join(config.ROOT, "tasks", "TEMPLATE.md"), encoding="utf-8") as f:
    TEMPLATE = f.read()
TASK = os.path.join(TMP, "0999-probe.md")
failed = []
notes = []
pl.notify = notes.append


def check(ok, name, got):
    print("OK  " if ok else "FAIL", name, "->", got)
    if not ok:
        failed.append(name)


def fresh(status, reason=""):
    with open(TASK, "w", encoding="utf-8") as f:
        f.write(TEMPLATE.replace("id: 0000", "id: 0999").replace("status: draft", f"status: {status}")
                .replace("blocked_reason:", f"blocked_reason: {reason}"))


def reset_log(lines=()):
    os.makedirs(config.LOG_DIR, exist_ok=True)
    with open(config.SESSIONS_LOG, "w", encoding="utf-8") as f:
        f.writelines(json.dumps(r) + "\n" for r in lines)


def fake_run(rc, record):
    def run(cmd, **kw):
        if record:
            with open(config.SESSIONS_LOG, "a", encoding="utf-8") as f:
                f.write(json.dumps(record) + "\n")
        return types.SimpleNamespace(returncode=rc)
    return run


# --- run_agent: set_blocked stubbed --------------------------------------------------
calls = []
real_set_blocked = run_task.set_blocked
run_task.set_blocked = lambda tf, reason, message="": calls.append(reason)
mine = {"role": "developer", "task": "0999"}
cases = [
    ("rc0, no record", 0, None, [], []),
    ("rc1 + record of this session", 1, mine, [], []),
    ("rc1, no record", 1, None, [], ["agent_not_started"]),
    ("rc1, record before offset only", 1, None, [mine], ["agent_not_started"]),
    ("rc1, record for other task", 1, {"role": "developer", "task": "0001"}, [], ["agent_not_started"]),
    ("rc1, record for other role", 1, {"role": "qa", "task": "0999"}, [], ["agent_not_started"]),
]
fresh("in_progress")
for name, rc, rec, pre, want in cases:
    calls.clear()
    reset_log(pre)
    run_task.subprocess.run = fake_run(rc, rec)
    run_task.run_agent("developer", TASK, session=1)
    check(calls == want, f"run_agent {name}", calls)

calls.clear()
reset_log()
run_task.subprocess.run = fake_run(2, None)
try:
    run_task.run_agent("developer", TASK)
    check(False, "run_agent rc2 dies", "returned")
except SystemExit as e:
    check(e.code == 1 and not calls, "run_agent rc2 dies", f"exit {e.code} {calls}")
run_task.set_blocked = real_set_blocked

# --- set_blocked: commit_task stubbed -----------------------------------------------------
commits = []
run_task.commit_task = lambda path, msg: commits.append(msg)
for status, reason, want_reason, want_commits in (("in_progress", "", "agent_not_started", 1),
                                                  ("blocked", "too_big", "too_big", 0)):
    commits.clear()
    notes.clear()
    fresh(status, reason)
    run_task.set_blocked(TaskFile(TASK), "agent_not_started", "msg")
    tf = TaskFile(TASK)
    got = (tf.get("status"), tf.get("blocked_reason"), len(commits), len(notes))
    check(got == ("blocked", want_reason, want_commits, 1), f"set_blocked from {status}", got)

# --- run_task --once: one developer step by a stub agent that sets the status -------------------
run_task.ensure_branch = lambda tf: TaskFile(tf.path)
pl.autocommit = lambda msg: None
pl.live_task = TaskFile
for after, want in (("blocked", 2), ("review", 0), ("in_progress", 0)):
    fresh("in_progress")
    run_task.run_agent = lambda role, path, **kw: TaskFile(path).set("status", after)
    rc = run_task.run_task(TASK, once=True)
    check(rc == want, f"--once, agent leaves {after}", rc)

print(f"{len(failed)} failed" if failed else "all OK")
sys.exit(1 if failed else 0)
