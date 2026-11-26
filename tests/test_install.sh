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

crab_file="$REPO/assets/crab.txt"
first_crab_line=$(grep -m1 -v '^[[:space:]]*$' "$crab_file")
crab_width=$(awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }' "$crab_file")

# a wide terminal: the facts sit beside the crab, on the same lines
H7="$WORK/h7"
mkdir -p "$H7"
OUT=$(env HOME="$H7" HERMIT_REPO="$REPO" HERMIT_CRAB=always HERMIT_COLS=200 bash "$INSTALL" 2>&1)
if printf '%s\n' "$OUT" | grep -qF -- "$first_crab_line"; then pass "HERMIT_CRAB=always shows the crab"; else fail "HERMIT_CRAB=always shows the crab"; fi
if printf '%s\n' "$OUT" | grep -qE "^.{$crab_width,}installed: hermit"; then pass "wide terminal: the facts sit beside the crab"; else fail "wide terminal: the facts sit beside the crab"; fi
if printf '%s\n' "$OUT" | grep -qF -- 'command:   ~/.local/bin/hermit'; then pass "the command path is shown with ~"; else fail "the command path is shown with ~"; fi

# a medium terminal: the crab fits, the facts go underneath
H7B="$WORK/h7b"
mkdir -p "$H7B"
OUT=$(env HOME="$H7B" HERMIT_REPO="$REPO" HERMIT_CRAB=always HERMIT_COLS=$((crab_width + 4)) bash "$INSTALL" 2>&1)
if printf '%s\n' "$OUT" | grep -qF -- "$first_crab_line"; then pass "medium terminal: the crab is shown"; else fail "medium terminal: the crab is shown"; fi
if printf '%s\n' "$OUT" | grep -qE "^.{$crab_width,}installed: hermit"; then fail "medium terminal: the facts go under the crab"; elif printf '%s\n' "$OUT" | grep -qF -- 'installed: hermit'; then pass "medium terminal: the facts go under the crab"; else fail "medium terminal: the facts go under the crab"; fi

# a narrow terminal: no crab, plain text only
H7C="$WORK/h7c"
mkdir -p "$H7C"
OUT=$(env HOME="$H7C" HERMIT_REPO="$REPO" HERMIT_CRAB=always HERMIT_COLS=40 bash "$INSTALL" 2>&1)
if printf '%s\n' "$OUT" | grep -qF -- "$first_crab_line"; then fail "narrow terminal: no crab"; else pass "narrow terminal: no crab"; fi
if printf '%s\n' "$OUT" | grep -qF -- 'installed: hermit'; then pass "narrow terminal: still says what was installed"; else fail "narrow terminal: still says what was installed"; fi

H8="$WORK/h8"
mkdir -p "$H8"
OUT=$(env HOME="$H8" HERMIT_REPO="$REPO" bash "$INSTALL" 2>&1)
if printf '%s\n' "$OUT" | grep -qF -- "$first_crab_line"; then fail "no crab when output is not a terminal"; else pass "no crab when output is not a terminal"; fi
if printf '%s\n' "$OUT" | grep -qF -- 'installed: hermit'; then pass "plain output still says what was installed"; else fail "plain output still says what was installed"; fi

H9="$WORK/h9"
mkdir -p "$H9"
OUT=$(env HOME="$H9" HERMIT_REPO="$REPO" HERMIT_CRAB=never bash "$INSTALL" 2>&1)
if printf '%s\n' "$OUT" | grep -qF -- "$first_crab_line"; then fail "HERMIT_CRAB=never hides the crab"; else pass "HERMIT_CRAB=never hides the crab"; fi

printf '\n%d failure(s)\n' "$fails"
[ "$fails" -eq 0 ]