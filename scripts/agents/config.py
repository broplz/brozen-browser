"""Pipeline constants. Models and effort live in .claude/agents/<role>.md; here are the
per-run limits the driver passes to `claude -p` and the loop policy. Override any
value with an environment variable of the same name prefixed BB_ (e.g. BB_MAX_RETURNS=2).
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LOG_DIR = os.environ.get("BB_LOG_DIR", os.path.join(ROOT, "logs"))
SESSIONS_LOG = os.path.join(LOG_DIR, "agent-sessions.jsonl")
TASK_DIR = os.path.join(ROOT, "tasks")
BACKLOG = os.path.join(TASK_DIR, "backlog.md")
APPROVALS = os.path.join(TASK_DIR, "approvals.txt")
DECISIONS = os.path.join(ROOT, "docs", "reports", "decisions-needed.md")
SKILLS_DIR = os.path.join(ROOT, ".claude", "skills")

DEV_ROLES = ("developer", "developer-hard")

# `claude -p --max-turns` per role; developer roles scale with the task size.
MAX_TURNS = {
    "developer": {"S": 25, "M": 40, "L": 60},
    "developer-hard": {"S": 30, "M": 50, "L": 70},
    "reviewer": 15,
    "qa": 25,
    "teamlead": 30,
    "rebaser": 60,
    "log-triage": 8,
}

# `--max-budget-usd` per session: ~2-3x the typical cost seen on Rise of the Sentinels
# (dev S $0.2-0.4, dev-hard M $0.8-1.1, reviewer $0.3-0.45, qa $0.13-0.16, teamlead $0.7-1.0).
# It is a runaway stop, not a target. Claude Code may overshoot it by a turn.
MAX_BUDGET_USD = {
    "developer": {"S": 1.0, "M": 2.5, "L": 5.0},
    "developer-hard": {"S": 2.0, "M": 4.0, "L": 8.0},
    "reviewer": 1.5,
    "qa": 1.5,
    "teamlead": 3.0,
    "rebaser": 8.0,
    "log-triage": 0.3,
}

# Shared rule-sets injected into the system prompt per role (order matters; frontmatter stripped).
SKILLS = {
    "developer": ["bb-task", "bb-layer", "bb-build"],
    "developer-hard": ["bb-task", "bb-layer", "bb-build"],
    "reviewer": ["bb-task", "bb-layer"],
    "qa": ["bb-task", "bb-build"],
    "teamlead": ["bb-task", "bb-layer"],
    "rebaser": ["bb-task", "bb-layer", "bb-build"],
    "log-triage": [],
}

# Loop policy
MAX_RETURNS = int(os.environ.get("BB_MAX_RETURNS", "3"))        # review/QA returns before blocked
MAX_SESSIONS = int(os.environ.get("BB_MAX_SESSIONS", "3"))      # developer sessions before blocked:too_big
MAX_LOOP_STEPS = int(os.environ.get("BB_MAX_LOOP_STEPS", "14"))  # safety cap on role runs per run_task
AUTO_UNBLOCK = os.environ.get("BB_AUTO_UNBLOCK", "1") == "1"    # run teamlead once on blocked
SESSION_TIMEOUT_S = int(os.environ.get("BB_SESSION_TIMEOUT_S", str(3 * 3600)))
PUSH_TIMEOUT_S = int(os.environ.get("BB_PUSH_TIMEOUT_S", "180"))
PLAN_BATCH = int(os.environ.get("BB_PLAN_BATCH", "3"))          # tasks per teamlead planning run

# Size caps the teamlead must respect (production lines of diff, files touched)
SIZE_CAPS = {"S": (150, 5), "M": (300, 10), "L": (500, 15)}

# Paths whose change makes a task "full build" / "needs human approval" (ADR-0002 §2 p.5)
FULL_BUILD_RE = r"\.(c|cc|cpp|cxx|m|mm|h|hpp|idl|webidl|ipdl|rs|toml|configure|build)$|(^|/)moz\.build$|(^|/)mozconfig|\.mozconfig$|(^|/)Cargo\.lock$"
APPROVAL_RE = r"\.(c|cc|cpp|cxx|m|mm|h|hpp|idl|webidl|ipdl)$"

FINAL_STATUSES = ("done", "split")
STOP_STATUSES = ("blocked",)


def turns_for(role: str, size: str) -> int:
    v = MAX_TURNS.get(role, 25)
    return v.get(size.upper(), v.get("M")) if isinstance(v, dict) else v


def budget_for(role: str, size: str) -> float:
    v = MAX_BUDGET_USD.get(role, 1.0)
    return v.get(size.upper(), v.get("M")) if isinstance(v, dict) else v
