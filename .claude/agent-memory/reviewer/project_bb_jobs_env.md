---
name: bb-jobs-env
description: agent sessions export BB_JOBS=10 (.claude/settings.json), so rebase tests that expect --jobs 6 fail unless BB_JOBS is unset
metadata:
  type: project
---
`.claude/settings.json` exports `BB_JOBS=10` into every agent session. Since task 0019, rebase.sh reads `BB_JOBS`, and the older rebase tests (rebase_final_test.sh, rebase_post_test.sh) expect `--jobs 6`.

**Why:** task 0019's developer saw those tests fail only because of this env var, and `env -u` was denied in their session.

**How to apply:** when a rebase test fails on a `--jobs` check, look at the environment before blaming the code. A new test should `unset BB_JOBS` itself.
