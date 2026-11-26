#!/usr/bin/env bash
# tests/test_lib.sh — plain-bash tests for lib/. No framework.
set -uo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FAKE_HOME=$(mktemp -d)
export HOME=$FAKE_HOME
safe_to_remove() {
  case "$1" in
    *..*)    return 1 ;;
    /tmp/?*) return 0 ;;
    *)       return 1 ;;
  esac
}

cleanup() {
  if safe_to_remove "$FAKE_HOME"; then
    rm -r -- "$FAKE_HOME"
  else
    printf 'refusing to remove %s\n' "$FAKE_HOME" >&2
  fi
}
trap cleanup EXIT

fails=0
pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

check_guard() {
  local expected=$1 value=$2
  local got=refused
  if safe_to_remove "$value"; then got=allowed; fi
  if [ "$got" = "$expected" ]; then
    pass "guard $expected [$value]"
  else
    fail "guard $expected [$value] (got $got)"
  fi
}

check_guard allowed "/tmp/tmp.AbC123"
check_guard refused "/tmp/"
check_guard refused "/tmp/../etc"
check_guard refused "/tmp/x/../../home"
check_guard refused "/etc"
check_guard refused ""

# shellcheck source=/dev/null
source "$REPO/lib/common.sh"

if (require_cmd bash) 2>/dev/null; then
  pass "require_cmd finds bash"
else
  fail "require_cmd finds bash"
fi

if (require_cmd no-such-command-xyz) 2>/dev/null; then
  fail "require_cmd rejects a missing command"
else
  pass "require_cmd rejects a missing command"
fi

# shellcheck source=/dev/null
source "$REPO/lib/paths.sh"
# shellcheck source=/dev/null
source "$REPO/lib/manifest.sh"
# shellcheck source=/dev/null
source "$REPO/lib/restore.sh"

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


BUILD_SRC="$FAKE_HOME/build_src"
BUILD_OUT="$FAKE_HOME/built.tsv"
mkdir -p "$BUILD_SRC/Documents/sub"
chmod 755 "$BUILD_SRC/Documents" "$BUILD_SRC/Documents/sub"
echo hi > "$BUILD_SRC/Documents/my notes.txt"
echo x > "$BUILD_SRC/Documents/sub/a.txt"
chmod 644 "$BUILD_SRC/Documents/my notes.txt"
chmod 600 "$BUILD_SRC/Documents/sub/a.txt"
touch "$BUILD_SRC/Documents/tab"$'\t'"name.txt"

manifest_build "$BUILD_SRC" "$BUILD_OUT" 2>/dev/null
rows=$(manifest_read "$BUILD_OUT" 2>/dev/null)

has_row() { printf '%s\n' "$rows" | grep -qxF -- "$1"; }

if has_row $'f\tDocuments/my notes.txt\t3\t644'; then
  pass "manifest_build records a file with size and mode"
else
  fail "manifest_build records a file with size and mode"
fi

if has_row $'d\tDocuments/sub\t0\t755'; then
  pass "manifest_build records a directory with size 0"
else
  fail "manifest_build records a directory with size 0"
fi

if has_row $'f\tDocuments/sub/a.txt\t2\t600'; then
  pass "manifest_build keeps mode 600"
else
  fail "manifest_build keeps mode 600"
fi

if printf '%s\n' "$rows" | grep -qF 'tab'; then
  fail "manifest_build skips a name containing a tab"
else
  pass "manifest_build skips a name containing a tab"
fi

docs_line=$(printf '%s\n' "$rows" | grep -nF $'d\tDocuments\t' | head -1 | cut -d: -f1)
sub_line=$(printf '%s\n' "$rows" | grep -nF $'d\tDocuments/sub\t' | head -1 | cut -d: -f1)
if [ "${docs_line:-99}" -lt "${sub_line:-0}" ]; then
  pass "manifest_build lists a parent before its child"
else
  fail "manifest_build lists a parent before its child"
fi

META_OUT="$FAKE_HOME/meta.env"
meta_write "$META_OUT" "0.1.0-test" "tester" "/home/tester" 2>/dev/null

if grep -qx 'HERMIT_VERSION=0.1.0-test' "$META_OUT" 2>/dev/null &&
  grep -qx 'SOURCE_USER=tester' "$META_OUT" &&
  grep -qx 'SOURCE_HOME=/home/tester' "$META_OUT"; then
  pass "meta_write records version, user and home"
else
  fail "meta_write records version, user and home"
fi

if grep -qE '^BACKUP_DATE=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$META_OUT" 2>/dev/null; then
  pass "meta_write writes an ISO 8601 UTC date"
else
  fail "meta_write writes an ISO 8601 UTC date"
fi

if meta_write "$META_OUT" "x" $'bad\nuser' "/h" 2>/dev/null; then
  fail "meta_write rejects a newline in a value"
else
  pass "meta_write rejects a newline in a value"
fi

( die 42 "boom" ) 2>/dev/null
code=$?
if [ "$code" -eq 42 ]; then
  pass "die exits with the code it is given"
else
  fail "die exits with the code it is given"
fi

msg=$( ( die 3 "drive gone" ) 2>&1 )
if [ "$msg" = "[hermit] ERROR: drive gone" ]; then
  pass "die prints the message on stderr"
else
  fail "die prints the message on stderr"
fi

( require_cmd no-such-command-xyz ) 2>/dev/null
code=$?
if [ "$code" -eq 7 ]; then
  pass "require_cmd exits 7 when a tool is missing"
else
  fail "require_cmd exits 7 when a tool is missing"
fi

( error "x" ) 2>/dev/null
code=$?
if [ "$code" -eq 1 ]; then
  pass "error still exits 1"
else
  fail "error still exits 1"
fi

table="${EX_USAGE:-?}.${EX_DRIVE:-?}.${EX_SPACE:-?}.${EX_BACKUP:-?}.${EX_PARTIAL:-?}.${EX_DEPENDENCY:-?}"
if [ "$table" = "2.3.4.5.6.7" ]; then
  pass "exit code table is stable"
else
  fail "exit code table is stable (got $table)"
fi

PLAN_BACKUP="$FAKE_HOME/plan_backup"
mkdir -p "$PLAN_BACKUP/files/Documents/sub" "$PLAN_BACKUP/files/Videos"
echo a > "$PLAN_BACKUP/files/Documents/new.txt"
echo b > "$PLAN_BACKUP/files/Documents/have.txt"
echo c > "$PLAN_BACKUP/files/Documents/sub/deep.txt"
manifest_init "$PLAN_BACKUP/manifest.tsv"
manifest_add "$PLAN_BACKUP/manifest.tsv" d Documents 0 755
manifest_add "$PLAN_BACKUP/manifest.tsv" f Documents/new.txt 2 644
manifest_add "$PLAN_BACKUP/manifest.tsv" f Documents/have.txt 2 644
manifest_add "$PLAN_BACKUP/manifest.tsv" f Documents/gone.txt 2 644
manifest_add "$PLAN_BACKUP/manifest.tsv" d Documents/sub 0 755
manifest_add "$PLAN_BACKUP/manifest.tsv" f Documents/sub/deep.txt 2 644
manifest_add "$PLAN_BACKUP/manifest.tsv" d Videos 0 755
manifest_add "$PLAN_BACKUP/manifest.tsv" d Linked 0 755
manifest_add "$PLAN_BACKUP/manifest.tsv" f Linked/x.txt 2 644

mkdir -p "$HOME/Documents" "$HOME/real_elsewhere"
echo old > "$HOME/Documents/have.txt"
ln -s "$HOME/real_elsewhere" "$HOME/Linked"

plan=$(restore_plan "$PLAN_BACKUP" 2>/dev/null)
has_plan() { printf '%s\n' "$plan" | grep -qxF -- "$1"; }
check_plan() { if has_plan "$1"; then pass "restore_plan: $2"; else fail "restore_plan: $2"; fi; }
check_plan $'have-dir\td\tDocuments' "an existing folder needs nothing"
check_plan $'copy\tf\tDocuments/new.txt' "a missing file is copied"
check_plan $'skip-exists\tf\tDocuments/have.txt' "an existing file is never overwritten"
check_plan $'skip-missing\tf\tDocuments/gone.txt' "a file absent from the backup is skipped"
check_plan $'mkdir\td\tDocuments/sub' "a missing folder is created"
check_plan $'copy\tf\tDocuments/sub/deep.txt' "a file in a new folder is copied"
check_plan $'mkdir\td\tVideos' "a missing top-level folder is created"
check_plan $'conflict\td\tLinked' "a symlink where a folder belongs is a conflict"
check_plan $'blocked\tf\tLinked/x.txt' "files inside a conflict are blocked"
if [ ! -e "$HOME/Documents/new.txt" ] && [ ! -d "$HOME/Videos" ]; then
  pass "restore_plan changes nothing on disk"
else
  fail "restore_plan changes nothing on disk"
fi

AB="$FAKE_HOME/apply_backup"
AH="$FAKE_HOME/apply_home"
OUTSIDE="$FAKE_HOME/outside"
mkdir -p "$AB/files/Documents/sub" "$AB/files/Escape" "$AH/Documents" "$OUTSIDE"
echo new > "$AB/files/Documents/new.txt"
echo fresh > "$AB/files/Documents/have.txt"
echo deep > "$AB/files/Documents/sub/deep.txt"
echo evil > "$AB/files/Escape/x.txt"
touch -d '2023-03-05 10:00:00' "$AB/files/Documents/new.txt"
manifest_init "$AB/manifest.tsv"
manifest_add "$AB/manifest.tsv" d Documents 0 755
manifest_add "$AB/manifest.tsv" f Documents/new.txt 4 644
manifest_add "$AB/manifest.tsv" f Documents/have.txt 6 644
manifest_add "$AB/manifest.tsv" d Documents/sub 0 755
manifest_add "$AB/manifest.tsv" f Documents/sub/deep.txt 5 644
manifest_add "$AB/manifest.tsv" f Escape/x.txt 5 644
echo old > "$AH/Documents/have.txt"
ln -s "$OUTSIDE" "$AH/Escape"

( HOME="$AH"; restore_apply "$AB" ) >/dev/null 2>&1
code=$?

if [ "$(cat "$AH/Documents/new.txt" 2>/dev/null)" = "new" ]; then pass "restore_apply copies a missing file"; else fail "restore_apply copies a missing file"; fi
if [ "$(cat "$AH/Documents/sub/deep.txt" 2>/dev/null)" = "deep" ]; then pass "restore_apply creates a folder and fills it"; else fail "restore_apply creates a folder and fills it"; fi
if [ "$(stat -c %Y "$AH/Documents/new.txt" 2>/dev/null)" = "$(stat -c %Y "$AB/files/Documents/new.txt")" ]; then pass "restore_apply keeps the modification time"; else fail "restore_apply keeps the modification time"; fi
if [ "$(cat "$AH/Documents/have.txt")" = "old" ]; then pass "restore_apply never overwrites an existing file"; else fail "restore_apply never overwrites an existing file"; fi
if [ ! -e "$OUTSIDE/x.txt" ]; then pass "restore_apply refuses to write through a symlink out of home"; else fail "restore_apply refuses to write through a symlink out of home"; fi
if [ "$code" -eq 6 ]; then pass "restore_apply exits 6 when something was refused"; else fail "restore_apply exits 6 when something was refused (got $code)"; fi

AB2="$FAKE_HOME/apply_backup2"
AH2="$FAKE_HOME/apply_home2"
mkdir -p "$AB2/files/Pictures" "$AH2"
echo p > "$AB2/files/Pictures/p.txt"
manifest_init "$AB2/manifest.tsv"
manifest_add "$AB2/manifest.tsv" d Pictures 0 755
manifest_add "$AB2/manifest.tsv" f Pictures/p.txt 2 644
( HOME="$AH2"; restore_apply "$AB2" ) >/dev/null 2>&1; code1=$?
( HOME="$AH2"; restore_apply "$AB2" ) >/dev/null 2>&1; code2=$?
if [ "$code1" -eq 0 ] && [ "$code2" -eq 0 ] && [ "$(cat "$AH2/Pictures/p.txt")" = "p" ]; then
  pass "restore_apply exits 0 on a clean run, and again on a re-run"
else
  fail "restore_apply clean run (got $code1 and $code2)"
fi

msg=$( ( HERMIT_COLOR=always die 3 "boom" ) 2>&1 )
if [ "$msg" = $'\033[31m[hermit] ERROR:\033[0m boom' ]; then pass "die is red when color is forced on"; else fail "die is red when color is forced on"; fi

msg=$( ( HERMIT_COLOR=always warn "careful" ) 2>&1 )
if [ "$msg" = $'\033[33m[hermit] WARN:\033[0m careful' ]; then pass "warn is yellow when color is forced on"; else fail "warn is yellow when color is forced on"; fi

msg=$( ( HERMIT_COLOR=always ok "done" ) 2>&1 )
if [ "$msg" = $'\033[32m[hermit] OK:\033[0m done' ]; then pass "ok is green when color is forced on"; else fail "ok is green when color is forced on"; fi

msg=$( ( HERMIT_COLOR=never warn "careful" ) 2>&1 )
if [ "$msg" = "[hermit] WARN: careful" ]; then pass "color can be forced off"; else fail "color can be forced off"; fi

msg=$( ( warn "careful" ) 2>&1 )
if [ "$msg" = "[hermit] WARN: careful" ]; then pass "no color when output is not a terminal"; else fail "no color when output is not a terminal"; fi

msg=$( ( HERMIT_COLOR=always info "plain" ) 2>&1 )
if [ "$msg" = "[hermit] plain" ]; then pass "info stays uncolored"; else fail "info stays uncolored"; fi

# ---- add new tests ABOVE this line ----
printf '\n%d failure(s)\n' "$fails"
[ "$fails" -eq 0 ]