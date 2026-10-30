# shellcheck shell=bash
# Shared stubs for the rebase.sh tests (source it; needs $T, a mktemp -d dir).
#   stub_env     — stub npm/caffeinate/nvm/patches under $T/stubs, exports PATH NVM_DIR CALLS
#                  BB_PATCHES BB_ENGINE_DIR BB_TARBALL_DIR BB_SMOKE BB_DIST_DIR BB_APPS_DIR
#                  BB_PUSH_REMOTE BB_POST_STEPS (steps 5-9 only); stubs npm caffeinate hdiutil smoke
#   make_engine  — $BB_ENGINE_DIR as a git repo: tracked tracked.txt, untracked junk, obj-x/keep
#   ff_cfg <v>   — a surfer.json with Firefox version <v>

ff_cfg() { printf '{\n  "version": {\n    "product": "firefox",\n    "version": "%s"\n  }\n}\n' "$1"; }

stub_env() {
  local s="$T/stubs"
  mkdir -p "$s/bin" "$s/nvm" "$T/tarballs"
  export CALLS="$s/calls"
  : >"$CALLS"
  # npm: log argv; `run download` recreates an empty engine (and notes a leftover one);
  # fails on `run build` when STUB_FAIL_BUILD is set
  cat >"$s/bin/npm" <<'EOF'
#!/bin/sh
echo "npm $*" >>"$CALLS"
if [ "$*" = "run download" ]; then
  [ -e "$BB_ENGINE_DIR" ] && echo "ENGINE-EXISTS" >>"$CALLS"
  mkdir -p "$BB_ENGINE_DIR"
fi
[ "$*" = "run build -- --jobs 6" ] && [ -n "$STUB_FAIL_BUILD" ] && exit 1
exit 0
EOF
  # caffeinate: log argv, then run the wrapped command (as the real one does)
  cat >"$s/bin/caffeinate" <<'EOF'
#!/bin/sh
echo "caffeinate $*" >>"$CALLS"
shift
"$@"
EOF
  printf '#!/bin/sh\nexit 0\n' >"$s/patches.sh"
  printf 'nvm() { echo "nvm $*" >>"$CALLS"; [ -z "$STUB_FAIL_NVM" ]; }\n' >"$s/nvm/nvm.sh"
  # hdiutil: log argv; `attach … -mountpoint <m> …` fakes a mounted BB.app
  cat >"$s/bin/hdiutil" <<'EOF'
#!/bin/sh
echo "hdiutil $*" >>"$CALLS"
if [ "$1" = attach ]; then
  while [ $# -gt 1 ] && [ "$1" != -mountpoint ]; do shift; done
  mkdir -p "$2/BB.app" && echo x >"$2/BB.app/x"
fi
exit 0
EOF
  # smoke: the checklist result; fails when STUB_FAIL_SMOKE is set
  cat >"$s/smoke.sh" <<'EOF'
#!/bin/sh
if [ -n "$STUB_FAIL_SMOKE" ]; then echo "smoke: n e0 window"; echo "smoke: result 0/1"; exit 1; fi
echo "smoke: y e0 window"
echo "smoke: result 1/1"
EOF
  chmod +x "$s/bin/npm" "$s/bin/caffeinate" "$s/bin/hdiutil" "$s/smoke.sh"
  export PATH="$s/bin:$PATH" NVM_DIR="$s/nvm" BB_PATCHES="$s/patches.sh"
  export BB_ENGINE_DIR="$T/engine" BB_TARBALL_DIR="$T/tarballs"
  export BB_SMOKE="$s/smoke.sh" BB_DIST_DIR="$T/dist" BB_APPS_DIR="$T/Applications" BB_PUSH_REMOTE="$T/no-such-remote.git"
  # steps 5-9 tests stop before smoke/publish; rebase_final_test.sh unsets this
  export BB_POST_STEPS="deps engine patches import build lint"
  export STUB_FAIL_BUILD= STUB_FAIL_NVM= STUB_FAIL_SMOKE=
  mkdir -p "$T/dist"
  : >"$T/dist/BB.dmg"
}

make_engine() {
  rm -rf "$BB_ENGINE_DIR"
  mkdir -p "$BB_ENGINE_DIR"
  git -C "$BB_ENGINE_DIR" init -q -b main
  echo orig >"$BB_ENGINE_DIR/tracked.txt"
  git -C "$BB_ENGINE_DIR" add -A
  git -C "$BB_ENGINE_DIR" commit -qm engine
  mkdir -p "$BB_ENGINE_DIR/obj-x"
  echo keep >"$BB_ENGINE_DIR/obj-x/keep"
  echo junk >"$BB_ENGINE_DIR/junk"
}
