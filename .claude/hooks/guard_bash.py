#!/usr/bin/env python3
"""PreToolUse hook for Bash.

Blocks destructive git/shell for everyone (BB_UNLOCK=1 overrides), and for agents: shell-side
file writes (Write/Edit only, so guard_paths sees them), direct surfer/mach/npm (build.sh/test.sh
only), raw logs (triage), branch switching/merging/pushing (the driver's job), and role-gated
commands (full build, rebase, merge). Exit 2 blocks; stderr reaches the model.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bb_hooklib as h  # noqa: E402

ALWAYS_BLOCK = [
    (r"\bgit\s+push\b[^|;&]*(\s--force(?!-with-lease)\b|\s-f\b)", "force push without lease (rebase.sh uses --force-with-lease)"),
    (r"\bgit\s+reset\s+--hard", "git reset --hard"),
    (r"\bgit\s+clean\b", "git clean"),
    (r"\bgit\s+branch\s+-D\b", "force branch delete"),
    (r"\bgit\s+config\s+--global", "global git config"),
    (r"\brm\s+-[a-zA-Z]*[rR]", "recursive rm"),
    (r"\bsudo\b", "sudo"),
    (r"\b(brew|pip3?|cargo|gem)\s+(install|uninstall)\b|\bnpm\s+(i|install|ci|uninstall|update)\b", "package install (ask via tasks/backlog.md)"),
    (r"\bchmod\s+-R", "recursive chmod"),
    (r">\s*\S*(\.env|secret)", "writing secrets"),
    (r"(^|[;&|]\s*)claude\b", "nested claude sessions"),
]
# Agents: raw command (before quote stripping) — substitutions hide inside quotes.
AGENT_RAW_BLOCK = [
    (r"\$\(|`", "command substitution — one plain command per Bash call"),
    (r"\$\{?[A-Za-z_?#@*0-9]", "shell variables — write literal values"),
    (r"<<", "heredocs — create files with the Write tool"),
]
AGENT_ONLY_BLOCK = [
    (r"(;|&&|\|\|)", "command chaining — one command per Bash call"),
    (r"\|(?!\s*(tail|head|grep|wc|sort|uniq|cut|cat)\b)", "pipes only into tail/head/grep/wc/sort/uniq/cut"),
    (r"(?<![0-9&<])>>?(?!\s*/dev/null)", "redirect into a file — use the Write/Edit tools"),
    (r"\btee\b", "tee (scripts already log into logs/)"),
    (r"\bsed\s+-[a-zA-Z]*i", "in-place sed — use the Edit tool"),
    (r"\b(perl|ruby)\s+-[a-zA-Z]*[pie]\b", "in-place one-liners — use the Edit tool"),
    (r"\bpython3?\s+-c\b", "python -c — use Write/Edit or a script under scripts/"),
    (r"\b(cp|mv|ln|install|truncate|dd|rsync)\b", "copy/move from shell — use Write/Edit"),
    (r"\b(bash|sh|zsh)\s+-c\b|\beval\b|\bsource\b|\bxargs\b", "sub-shells/eval — one plain command per call"),
    (r"(^|\s)cd\s", "cd — run everything from the repo root"),
    (r"\bgit\s+-C\b", "git -C (engine/ is generated; patch it, never commit inside it)"),
    (r"\bgit\s+(switch|checkout|merge|rebase|push|pull|fetch|stash|worktree|cherry-pick|revert|reset)\b",
     "git branch/remote operations are the driver's job (scripts/agents/run_task.py)"),
    (r"\b(surfer|npx\s+surfer)\b|\bnpm\s+run\s+(build|build:ui|import|export|init|download|bootstrap|package|sync|reset-ff|start|ci|lint)\b|\bnpm\s+(start|test)\b",
     "direct surfer/npm — use scripts/agents/build.sh and scripts/agents/test.sh (lock, log, triage)"),
    (r"(^|\s|/)mach\b", "direct mach — use scripts/agents/build.sh / test.sh"),
    (r"\b(cat|head|less|more|bat)\s+[^|]*\.log\b", "raw log — python3 scripts/agents/triage_log.py <log> (or tail -n 40)"),
    (r"\btail\s+(-n\s*|-)?(\d{3,})\b[^|]*\.log\b", "tail of a log over 99 lines — use triage_log.py"),
    (r"\b(curl|wget|nc|ssh|scp|rsync)\b", "network from the shell"),
    (r"\bopen\b|\bosascript\b", "GUI from the shell"),
]
ROLE_GATED = [
    (r"scripts/agents/build\.sh\b.*\b(full|--full)\b", {"developer-hard", "qa", "rebaser"},
     "full builds (~40 min) run only for developer-hard, qa, rebaser — this task needs role developer-hard"),
    (r"scripts/agents/build\.sh\b", {"developer", "developer-hard", "qa", "rebaser"}, "building"),
    (r"scripts/agents/test\.sh\b", {"developer", "developer-hard", "qa", "rebaser"}, "running tests"),
    (r"scripts/bb/rebase\.sh\b", {"rebaser"}, "rebases"),
    (r"scripts/bb/patches\.sh\s+export\b", {"developer", "developer-hard", "rebaser"}, "patch export"),
    (r"scripts/agents/(run_task|run_queue|run_agent|merge_task|finish_feature|new_feature)\b", set(), "driver scripts"),
    (r"scripts/bb/smoke\.sh\b", {"rebaser", "qa"}, "smoke"),
    (r"\bgit\s+apply\b", {"developer-hard", "rebaser"}, "git apply (patch authoring)"),
]
QUOTED = re.compile(r'"(?:\\.|[^"\\])*"|\'[^\']*\'')


def main():
    if h.unlocked():
        sys.exit(0)
    data = h.load()
    raw = (data.get("tool_input") or {}).get("command") or ""
    if not raw:
        sys.exit(0)
    if os.path.exists(h.stop_file(data)):
        h.block("session is stopped (strikes/loop). No more commands: write ## Handoff in the task file, set status: blocked, commit with the Edit tool only, and end.")
    short = raw.strip().replace("\n", " ")[:140]
    cmd = QUOTED.sub('""', raw)
    for pattern, why in ALWAYS_BLOCK:
        if re.search(pattern, cmd):
            h.block(f"{why}: `{short}`")
    role = h.role(data)
    if role == "human":
        sys.exit(0)
    for pattern, why in AGENT_RAW_BLOCK:
        if re.search(pattern, raw):
            h.block(f"{why}: `{short}`")
    for pattern, why in AGENT_ONLY_BLOCK:
        if re.search(pattern, cmd):
            h.block(f"{why}: `{short}`")
    for pattern, roles, why in ROLE_GATED:
        if re.search(pattern, cmd) and role not in roles:
            h.block(f"{why}; role '{role}' may not run `{short}`")
    sys.exit(0)


if __name__ == "__main__":
    main()
