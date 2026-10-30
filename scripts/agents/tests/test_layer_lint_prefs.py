#!/usr/bin/env python3
"""layer_lint.prefs_fails / zen_pref_names: strip.yaml may hold a non-bb.* pref only when no Zen yaml defines it."""
import os
import subprocess
import sys
import tempfile

AGENTS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, AGENTS)

import config  # noqa: E402
import layer_lint as ll  # noqa: E402

ENV = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t",
       "GIT_COMMITTER_EMAIL": "t@t"}
DUP = "Zen задаёт этот pref: не дублировать"
FIXTURES = {
    "prefs/firefox/ai.yaml": "- name: browser.ml.enable\n  value: false\n",
    "prefs/zen/x.yaml": "- name: zen.cond.pref\n  value: \"@cond\"\n",
    "prefs/privatefox/sub/y.yaml": "- name: privacy.nested.pref\n  value: true\n",
}


def entry(name):
    return f"- name: {name}\n  value: false\n"


def main():
    config.ROOT = tempfile.mkdtemp(prefix="layer_lint_prefs_")
    for rel, text in FIXTURES.items():
        full = os.path.join(config.ROOT, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8") as f:
            f.write(text)
    for args in (["init", "-q", "-b", "base"], ["add", "-A"], ["commit", "-q", "-m", "fixtures"]):
        subprocess.run(["git", *args], cwd=config.ROOT, env=ENV, capture_output=True, check=True)
    zen = ll.zen_pref_names("base")
    assert zen == {"browser.ml.enable", "zen.cond.pref", "privacy.nested.pref"}, zen

    assert ll.prefs_fails(ll.STRIP_YAML, entry("browser.discovery.enabled"), zen) == [], "a"
    for name in ("browser.ml.enable", "zen.cond.pref", "privacy.nested.pref"):   # b, c, d
        fails = ll.prefs_fails(ll.STRIP_YAML, entry(name), zen)
        assert len(fails) == 1 and DUP in fails[0], (name, fails)
    fails = ll.prefs_fails("prefs/bb/bb.yaml", entry("browser.discovery.enabled"), zen)
    assert len(fails) == 1 and "outside the bb.* namespace" in fails[0], fails   # e
    assert ll.prefs_fails(ll.STRIP_YAML, entry("bb.strip.ai"), zen) == [], "f"
    print("test_layer_lint_prefs: OK")


if __name__ == "__main__":
    main()
