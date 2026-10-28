#!/usr/bin/env bash
# l10n.sh — materialize locales/firefox-l10n from a cached bare mirror (ADR-0002, decision 4).
# Fetches only the pinned commit (--depth 1) and sparse-checks-out the languages we ship.
# Env: BB_REPO_DIR, BB_L10N_CACHE, BB_L10N_URL, BB_LOG_DIR.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REPO="${BB_REPO_DIR:-$BB_ROOT}"
CACHE="${BB_L10N_CACHE:-$HOME/zen-bro/cache/firefox-l10n}"
URL="${BB_L10N_URL:-https://github.com/mozilla-l10n/firefox-l10n}"
HASH_FILE="$REPO/build/firefox-cache/l10n-last-commit-hash"
LANGS_FILE="$REPO/locales/supported-languages"
MAPS_FILE="$REPO/locales/language-maps"
DEST="$REPO/locales/firefox-l10n"

HASH=""
[ -f "$HASH_FILE" ] && HASH="$(tr -d '\r\n' <"$HASH_FILE")"
if [ -z "$HASH" ]; then
  echo "l10n: missing or empty commit hash file: $HASH_FILE" >&2
  exit 1
fi

# file_lines <file> — non-empty lines, \r stripped, a final line without newline included.
file_lines() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    [ -n "$line" ] && echo "$line"
  done <"$1"
  return 0
}

# lang_dir <id> — directory for a language id via language-maps (<id>:<dir>), else the id itself.
lang_dir() {
  local id="$1" key dir
  while IFS=: read -r key dir; do
    if [ "$key" = "$id" ] && [ -n "$dir" ]; then
      echo "$dir"
      return 0
    fi
  done < <(file_lines "$MAPS_FILE")
  echo "$id"
}

# fetch_commit <hash> — make the commit available in the cache; print cached|fetched.
fetch_commit() {
  local hash="$1"
  [ -d "$CACHE" ] || git init -q --bare "$CACHE"
  if git -C "$CACHE" cat-file -e "$hash^{commit}" 2>/dev/null; then
    echo "l10n: cached $hash"
  else
    git -C "$CACHE" fetch --depth 1 --progress "$URL" "$hash" || return 1
    echo "l10n: fetched $hash"
  fi
  git -C "$CACHE" update-ref refs/bb/l10n "$hash" || return 1
}

# checkout_langs <dir>… — fresh sparse checkout of the cached commit into $DEST.
checkout_langs() {
  rm -rf "$DEST" &&
    mkdir -p "$DEST" &&
    git -C "$DEST" init -q &&
    git -C "$DEST" sparse-checkout set "$@" &&
    git -C "$DEST" fetch -q --depth 1 "$CACHE" refs/bb/l10n &&
    git -C "$DEST" checkout -q FETCH_HEAD
}

run() {
  local line dirs=(en-US)
  while IFS= read -r line; do
    dirs+=("$(lang_dir "$line")")
  done < <(file_lines "$LANGS_FILE")
  # step runs us inside a list, where set -e is off: propagate failures explicitly.
  fetch_commit "$HASH" || return 1
  checkout_langs "${dirs[@]}" || return 1
}

bb_log_open l10n >/dev/null
if ! step l10n run; then
  echo "l10n: failed to provide commit $HASH" >&2
  exit 1
fi
