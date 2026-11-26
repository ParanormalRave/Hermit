#!/usr/bin/env bash
# tests/test_install.sh — install.sh, run against this checkout instead of GitHub.
# Everything happens in a temporary fake home. Nothing real is touched.
set -uo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INSTALL="$REPO/install.sh"
WORK=$(mktemp -d)

safe_to_remove() {
  case "$1" in
    *..*)    return 1 ;;
    /tmp/?*) return 0 ;;
    *)       return 1 ;;
  esac
}

cleanup() {
  if safe_to_remove "$WORK"; then
    rm -r -- "$WORK"
  else
    printf 'refusing to remove %s\n' "$WORK" >&2
  fi
}
trap cleanup EXIT

fails=0
pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
check() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then pass "$name"; else fail "$name"; fi
}

# inst HOME [PATH_EXTRA] -- runs the installer; sets OUT and RC
inst() {
  local home=$1
  OUT=$(env HOME="$home" HERMIT_REPO="$REPO" bash "$INSTALL" 2>&1)
  RC=$?
}

H1="$WORK/h1"
mkdir -p "$H1"
inst "$H1"
if [ "$RC" -eq 0 ]; then pass "a fresh install exits 0"; else fail "a fresh install exits 0 ($OUT)"; fi
check "the hermit command is a link to the checkout" test -L "$H1/.local/bin/hermit"
check "the installed command runs" "$H1/.local/bin/hermit" --version
check "the libraries came along" test -f "$H1/.local/share/hermit/lib/common.sh"
if printf '%s' "$OUT" | grep -q 'installed: '; then pass "it reports what it installed"; else fail "it reports what it installed"; fi
if printf '%s' "$OUT" | grep -q 'not in your PATH'; then pass "it warns when the bin folder is not in PATH"; else fail "it warns when the bin folder is not in PATH"; fi

inst "$H1"
if [ "$RC" -eq 0 ]; then pass "running it again (update) exits 0"; else fail "running it again (update) exits 0 ($OUT)"; fi
if printf '%s' "$OUT" | grep -q 'updating'; then pass "the second run updates instead of downloading again"; else fail "the second run updates instead of downloading again"; fi

H2="$WORK/h2"
mkdir -p "$H2/.local/bin"
OUT=$(env HOME="$H2" PATH="$H2/.local/bin:$PATH" HERMIT_REPO="$REPO" bash "$INSTALL" 2>&1)
if printf '%s' "$OUT" | grep -q 'not in your PATH'; then fail "no PATH warning when the bin folder is already in PATH"; else pass "no PATH warning when the bin folder is already in PATH"; fi

H3="$WORK/h3"
mkdir -p "$H3/.local/bin"
echo "my own program" > "$H3/.local/bin/hermit"
inst "$H3"
if [ "$RC" -ne 0 ]; then pass "it refuses to replace a real file named hermit"; else fail "it refuses to replace a real file named hermit"; fi
check "that file is left untouched" test "$(cat "$H3/.local/bin/hermit")" = "my own program"

H4="$WORK/h4"
mkdir -p "$H4/.local/share/hermit"
echo keep > "$H4/.local/share/hermit/notes.txt"
inst "$H4"
if [ "$RC" -ne 0 ]; then pass "it refuses an existing folder that is not a Hermit checkout"; else fail "it refuses an existing folder that is not a Hermit checkout"; fi
check "that folder is left untouched" test -f "$H4/.local/share/hermit/notes.txt"

H5="$WORK/h5"
mkdir -p "$H5"
OUT=$(cat "$INSTALL" | env HOME="$H5" HERMIT_REPO="$REPO" bash 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && [ -x "$H5/.local/bin/hermit" ]; then pass "it works when piped into bash (curl | bash)"; else fail "it works when piped into bash ($OUT)"; fi

H6="$WORK/h6"
mkdir -p "$H6"
OUT=$(env HOME="$H6" HERMIT_REPO="$REPO" HERMIT_REF=no-such-version bash "$INSTALL" 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then pass "an unknown HERMIT_REF fails instead of installing something else"; else fail "an unknown HERMIT_REF fails"; fi

printf '\n%d failure(s)\n' "$fails"
[ "$fails" -eq 0 ]