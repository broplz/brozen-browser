#!/usr/bin/env python3
"""PreToolUse hook for Edit | Write | MultiEdit | NotebookEdit.

Blocks writes (1) to protected paths, (2) that break ADR-0002 layer rules (.patch under src/zen,
Zen patches without allow_zen_patch), (3) to existing tests in non-test tasks, (4) outside the
task's allowed_paths plus the role's standing paths. Exit 2 blocks; stderr reaches the model.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bb_hooklib as h  # noqa: E402

PROTECTED = [
    ".claude/**", "CLAUDE.md", ".github/**", ".husky/**", "node_modules/**", ".surfer/**",
    "package-lock.json", "build/signing/**", "**/.env", "**/*.env", "**/*secret*", "**/*Secret*",
    "tasks/approvals.txt", ".git/**",
]
# engine/ is generated and git-ignored: scratch for AUTHORING a Firefox patch (then
# scripts/bb/patches.sh export captures it), never a place to keep changes. Only patch authors edit it.
ENGINE_EDITORS = ("developer-hard", "rebaser")
TEST_PATHS = ["src/bb/tests/**", "src/zen/tests/**", "**/test_*.py", "**/*.test.mjs", "**/browser_*.js"]
SCRATCH = ["logs/**"]
SHARED = ["tasks/backlog.md", "docs/notes/**"]          # "Found by agents" and API notes, any pipeline role
ROLE_PATHS = {
    "teamlead": ["tasks/**", "docs/plans/**", "docs/reports/**", "docs/notes/**"] + SCRATCH,
    "developer": SHARED + SCRATCH,
    "developer-hard": SHARED + SCRATCH,
    "reviewer": ["tasks/backlog.md"] + SCRATCH,
    "qa": ["tasks/backlog.md", "tasks/bugs/**"] + TEST_PATHS + SCRATCH,
    "rebaser": ["src/**", "prefs/**", "configs/**", "docs/rebase/**", "tasks/**", "package.json", "surfer.json", ".nvmrc", "rust-toolchain.toml", "requirements.txt", "locales/**"] + SCRATCH,
    "architect": ["docs/**", "tasks/backlog.md"] + SCRATCH,
    "log-triage": SCRATCH,
}
ALLOWED_PATHS_APPLY = ("developer", "developer-hard", "rebaser")


def on_base(root, base, rel):
    import subprocess
    for ref in (base, f"origin/{base}"):
        r = subprocess.run(["git", "cat-file", "-e", f"{ref}:{rel}"], cwd=root,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if r.returncode == 0:
            return True
    return False


def main():
    if h.unlocked():
        sys.exit(0)
    data = h.load()
    ti = data.get("tool_input") or {}
    file_path = ti.get("file_path") or ti.get("notebook_path") or ""
    if not file_path:
        sys.exit(0)
    root = h.root(data)
    rel = h.relpath(data, file_path)
    role = h.role(data)
    task = h.read_task(data)
    own = h.relpath(data, h.task_path()) if h.task_path() else ""

    if os.path.exists(h.stop_file(data)) and rel != own:
        h.block("session is stopped (strikes/loop). Only your own task file may be edited now: "
                f"{own or '(none)'} — write ## Handoff, set status: blocked, commit, end.")
    if rel.startswith(".."):
        h.block(f"{rel} is outside the repository.")
    if rel.startswith(f".claude/agent-memory/{role}/") or (role == "human" and rel.startswith(".claude/agent-memory/")):
        sys.exit(0)
    if h.matches(rel, PROTECTED):
        h.block(f"{rel} is protected (pipeline config, generated trees, secrets). Only the human changes it.")
    if rel.startswith("engine/") and role not in ENGINE_EDITORS and role != "human":
        h.block(f"{rel}: engine/ is generated (surfer resets it). Zen files live under src/ (symlinked); Firefox files "
                "are changed with a BB patch — a developer-hard task. Say so in ## Handoff if this task needs it.")
    if rel.startswith("engine/") and role in ENGINE_EDITORS:
        sys.exit(0)
    if rel.startswith("src/zen/") and rel.endswith(".patch"):
        h.block(f"{rel}: a .patch under src/zen/ can never apply (engine/zen is a symlink). Edit the Zen file directly — class 2 in ADR-0002.")
    if rel.endswith(".patch") and rel.startswith("src/") and not rel.startswith("src/bb/patches/"):
        if not (task and task.getbool("allow_zen_patch")):
            h.block(f"{rel} is one of Zen's patches. BB patches live in src/bb/patches/<epic>/<name>/ with a README. "
                    "Editing a Zen patch is allowed only in a task with allow_zen_patch: true (hunks intersect, ADR-0002 §2 p.4).")
    if role == "human":
        sys.exit(0)

    kind = task.get("kind", "") if task else ""
    base = os.environ.get("BB_BASE") or (task.get("base", "main") if task else "main")
    if h.matches(rel, TEST_PATHS) and kind != "test" and role != "qa":
        if os.path.exists(os.path.join(root, rel)) and on_base(root, base, rel):
            h.block(f"{rel} is a test that already exists on {base}. Feature tasks may only add new test files "
                    "(and edit those); existing tests change only in kind: test tasks or by qa. Fix the code, not the test.")

    scope = list(ROLE_PATHS.get(role, []))
    if own:
        scope.append(own)
    if task and role in ALLOWED_PATHS_APPLY:
        scope += task.getlist("allowed_paths")
    if not scope:
        h.block(f"role '{role}' has no write scope here.")
    if not h.matches(rel, scope):
        h.block(f"{rel} is outside this task's allowed_paths. Allowed: {', '.join(scope)}. "
                "If the task really needs this file, stop and say so in ## Handoff (or one line in tasks/backlog.md under Found by agents).")
    sys.exit(0)


if __name__ == "__main__":
    main()
