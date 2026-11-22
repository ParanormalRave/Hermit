#!/usr/bin/env bash
# tests/test_lib.sh — plain-bash tests for lib/. No framework.
set -uo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FAKE_HOME=$(mktemp -d)
export HOME=$FAKE_HOME
cleanup() {
  case "$FAKE_HOME" in
    /tmp/*) rm -r -- "$FAKE_HOME" ;;
    *) printf 'refusing to remove %s\n' "$FAKE_HOME" >&2 ;;
  esac
}
trap cleanup EXIT

fails=0
pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

# shellcheck source=/dev/null
source "$REPO/lib/common.sh"
# shellcheck source=/dev/null
source "$REPO/lib/paths.sh"
# shellcheck source=/dev/null
source "$REPO/lib/manifest.sh"

# Fix 1: a data row must contain exactly 3 tabs (4 fields).
test_manifest_rejects_extra_field() {
  local file=$FAKE_HOME/manifest.tsv err=$FAKE_HOME/err out
  # 5 fields: f, path, empty, size, mode — four tabs.
  printf '%s\n' "$MANIFEST_HEADER" $'f\tDocs/a.txt\t\t12\t644' > "$file"
  out=$(manifest_read "$file" 2>"$err")
  if [ -z "$out" ] && grep -q 'skipping malformed line' "$err"; then
    pass "manifest_read rejects a 5-field row"
  else
    fail "manifest_read rejects a 5-field row (stdout=$out)"
  fi
}

# Fix 3: manifest_init writes the spec comment line before the header.
test_manifest_init_writes_comment() {
  local file=$FAKE_HOME/init.tsv first second
  manifest_init "$file"
  first=$(sed -n '1p' "$file")
  second=$(sed -n '2p' "$file")
  if [ "$first" = "# hermit manifest v1" ] && [ "$second" = "$MANIFEST_HEADER" ]; then
    pass "manifest_init writes the comment then the header"
  else
    fail "manifest_init writes the comment then the header (line1=$first line2=$second)"
  fi
}

# manifest_read must still accept a manifest that starts with the comment.
test_manifest_read_skips_comment() {
  local file=$FAKE_HOME/comment.tsv err=$FAKE_HOME/err out expected
  manifest_init "$file"
  manifest_add "$file" f 'Documents/notes/a.txt' 12 644
  expected=$'f\tDocuments/notes/a.txt\t12\t644'
  out=$(manifest_read "$file" 2>"$err")
  if [ "$out" = "$expected" ]; then
    pass "manifest_read skips the comment line"
  else
    fail "manifest_read skips the comment line (stdout=$out)"
  fi
}

# Fix 2: _valid_rel must reject a newline, for every caller.
test_valid_rel_rejects_newline() {
  if _valid_rel $'a\nb'; then
    fail "_valid_rel rejects a newline"
  else
    pass "_valid_rel rejects a newline"
  fi
}

test_home_abs_rejects_newline() {
  local out
  if out=$(home_abs $'a\nb'); then
    fail "home_abs rejects a newline (printed: $out)"
  else
    pass "home_abs rejects a newline"
  fi
}

test_home_rel_rejects_newline() {
  local out
  if out=$(home_rel "$HOME/a"$'\n'"b"); then
    fail "home_rel rejects a newline (printed: $out)"
  else
    pass "home_rel rejects a newline"
  fi
}

# Follow-up: _valid_rel must reject a tab in a name, for every caller.
test_valid_rel_rejects_tab() {
  if _valid_rel $'a\tb'; then
    fail "_valid_rel rejects a tab"
  else
    pass "_valid_rel rejects a tab"
  fi
}

test_home_abs_rejects_tab() {
  local out
  if out=$(home_abs $'a\tb'); then
    fail "home_abs rejects a tab (printed: $out)"
  else
    pass "home_abs rejects a tab"
  fi
}

test_home_rel_rejects_tab() {
  local out
  if out=$(home_rel "$HOME/a"$'\t'"b"); then
    fail "home_rel rejects a tab (printed: $out)"
  else
    pass "home_rel rejects a tab"
  fi
}

# Regression cases: these must keep behaving the same after every fix.
test_valid_rel_regressions() {
  local p
  for p in '../x' '/abs' 'a//b' 'a/' ''; do
    if _valid_rel "$p"; then
      fail "_valid_rel rejects $(printf '%q' "$p")"
    else
      pass "_valid_rel rejects $(printf '%q' "$p")"
    fi
  done

  if _valid_rel 'Documents/notes/a.txt'; then
    pass "_valid_rel accepts a nested path"
  else
    fail "_valid_rel accepts a nested path"
  fi

  # A tab in a name would add a field to the tab-separated row.
  if _manifest_valid f $'a\tb' 1 644; then
    fail "_manifest_valid rejects a tab in the name"
  else
    pass "_manifest_valid rejects a tab in the name"
  fi
}

test_manifest_rejects_extra_field
test_manifest_init_writes_comment
test_manifest_read_skips_comment
test_valid_rel_rejects_newline
test_home_abs_rejects_newline
test_home_rel_rejects_newline
test_valid_rel_rejects_tab
test_home_abs_rejects_tab
test_home_rel_rejects_tab
test_valid_rel_regressions

printf '\n%d failure(s)\n' "$fails"
[ "$fails" -eq 0 ]
