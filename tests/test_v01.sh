#!/usr/bin/env bash
# tests/test_v01.sh — end-to-end: back up a fake home, restore it, check the result.
# Never touches your real home or drives: everything lives in one temp folder.
set -uo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HERMIT="$REPO/hermit"
WORK=$(mktemp -d)

safe_to_remove() {
  # macOS mktemp lives under $TMPDIR (/var/folders/...), not /tmp.
  local base=${TMPDIR:-/tmp}
  base=${base%/}
  case "$1" in
    *..*) return 1 ;;
    /tmp/?* | "$base"/?*) return 0 ;;
    *) return 1 ;;
  esac
}

# file_mode FILE — portable octal mode (GNU stat -c, else BSD stat -f).
file_mode() {
  local m
  m=$(stat -c %a -- "$1" 2>/dev/null) && printf '%s\n' "$m" && return 0
  stat -f %Lp -- "$1" 2>/dev/null
}

# mtime_equal A B — true when neither file is older than the other.
mtime_equal() {
  [ ! "$1" -ot "$2" ] && [ ! "$1" -nt "$2" ]
}

cleanup() {
  chmod -R u+w "$WORK" 2>/dev/null
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

# check NAME COMMAND...   passes when the command succeeds
check() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then pass "$name"; else fail "$name"; fi
}

# run HOME ANSWER ARGS...   runs hermit with a fake HOME; sets OUT and RC
run() {
  local home=$1 answer=$2
  shift 2
  OUT=$(printf '%s' "$answer" | env HOME="$home" "$HERMIT" "$@" 2>&1)
  RC=$?
}

check_rc() {
  if [ "$RC" -eq "$2" ]; then pass "$1"; else fail "$1 (exit $RC, wanted $2)"; fi
}

contains() { printf '%s' "$OUT" | grep -qF -- "$1"; }

# ---- the fake world -------------------------------------------------------
SRC="$WORK/src_home"
DRIVE="$WORK/drive"
DST="$WORK/dst_home"
OUTSIDE="$WORK/outside"

mkdir -p "$SRC/Documents/sub/deep" "$SRC/Documents/emptydir" "$SRC/Documents/private" \
  "$SRC/Pictures" "$SRC/Videos" "$DRIVE" "$DST" "$OUTSIDE"
echo "hello" > "$SRC/Documents/a.txt"
echo "spaced" > "$SRC/Documents/my notes.txt"
echo "deep" > "$SRC/Documents/sub/deep/c.txt"
echo "secret" > "$SRC/Documents/private/s.txt"
chmod 600 "$SRC/Documents/private/s.txt"
chmod 750 "$SRC/Documents/private"
touch -t 202303051000.00 "$SRC/Documents/a.txt"
echo "pic" > "$SRC/Pictures/p.png"
ln -s "$SRC/Documents/a.txt" "$SRC/Pictures/link"
echo "vid" > "$SRC/Videos/ok.mp4"
echo "tabbed" > "$SRC/Videos/bad"$'\t'"name.mp4"
chmod 755 "$SRC/Documents" "$SRC/Documents/sub" "$SRC/Documents/sub/deep" \
  "$SRC/Documents/emptydir" "$SRC/Pictures" "$SRC/Videos"
# ---- backup ---------------------------------------------------------------
run "$SRC" "" backup "$DRIVE"
check_rc "backup exits 0" "$RC" 0
BK="$DRIVE/hermit-backup"
check "backup wrote files/, manifest.tsv and meta.env" test -d "$BK/files" -a -f "$BK/manifest.tsv" -a -f "$BK/meta.env"
if contains "not a regular file"; then pass "backup reports the symlink it skipped"; else fail "backup reports the symlink it skipped"; fi
check "the drive holds a copy of the spaced filename" test -f "$BK/files/Documents/my notes.txt"
check "the drive copy contains no symlinks" test -z "$(find "$BK/files" -type l)"
check "backup left no probe file behind" test -z "$(find "$DRIVE" -name '.hermit-probe.*')"

# ---- dry run changes nothing ---------------------------------------------
run "$DST" "" restore "$DRIVE" --dry-run
check_rc "restore --dry-run exits 0" "$RC" 0
if contains "dry run: would copy"; then pass "dry run prints a plan"; else fail "dry run prints a plan"; fi
check "dry run leaves the new home empty" test -z "$(ls -A "$DST")"

# ---- real restore ---------------------------------------------------------
run "$DST" "" restore "$DRIVE"
check_rc "restore exits 0" "$RC" 0
check "Documents restored identically (spaces, nesting, empty folder)" diff -r "$SRC/Documents" "$DST/Documents"
check "empty folder came back" test -d "$DST/Documents/emptydir"
check "modification time is preserved" mtime_equal "$DST/Documents/a.txt" "$SRC/Documents/a.txt"
check "file mode 600 is preserved" test "$(file_mode "$DST/Documents/private/s.txt")" = 600
check "folder mode 750 is applied" test "$(file_mode "$DST/Documents/private")" = 750
check "Pictures: the regular file is restored" test -f "$DST/Pictures/p.png"
check "Pictures: the symlink is not restored" test ! -e "$DST/Pictures/link" -a ! -L "$DST/Pictures/link"
check "Videos: the normal file is restored" test -f "$DST/Videos/ok.mp4"
check "Videos: the tab-named file is not restored" test -z "$(find "$DST/Videos" -name $'*\t*')"

# ---- re-running is safe ---------------------------------------------------
echo "changed on the new machine" > "$DST/Documents/a.txt"
run "$DST" "" restore "$DRIVE"
check_rc "a second restore exits 0" "$RC" 0
if contains "restored 0 file(s)"; then pass "a second restore copies nothing"; else fail "a second restore copies nothing"; fi
check "an existing file is never overwritten" test "$(cat "$DST/Documents/a.txt")" = "changed on the new machine"

# ---- restore never writes outside the home --------------------------------
DST2="$WORK/dst_home2"
mkdir -p "$DST2"
ln -s "$OUTSIDE" "$DST2/Pictures"
run "$DST2" "" restore "$DRIVE"
check "a folder that is a symlink out of home is left alone" test -z "$(ls -A "$OUTSIDE")"
check "the rest of that restore still worked" test -f "$DST2/Documents/a.txt"

# ---- error paths and exit codes -------------------------------------------
run "$DST" "" restore "$WORK/no_such_drive"
check_rc "restore from a missing drive exits 3" "$RC" 3
mkdir -p "$WORK/empty_drive"
run "$DST" "" restore "$WORK/empty_drive"
check_rc "restore from a drive with no backup exits 5" "$RC" 5
run "$SRC" "" backup
check_rc "backup with no drive exits 2" "$RC" 2
run "$SRC" "" backup "$WORK/no_such_drive"
check_rc "backup to a missing drive exits 3" "$RC" 3
run "$SRC" "" --version
check_rc "--version exits 0" "$RC" 0

RO="$WORK/readonly_drive"
mkdir -p "$RO"
chmod 555 "$RO"
if [ "$(id -u)" -eq 0 ]; then
  pass "backup to a read-only drive exits 3 (skipped: running as root)"
else
  run "$SRC" "" backup "$RO"
  check_rc "backup to a read-only drive exits 3" "$RC" 3
fi
chmod 755 "$RO"

# ---- the overwrite prompt (last: it moves the backup) ---------------------
run "$SRC" "n
" backup "$DRIVE"
check_rc "answering no to the overwrite prompt exits 1" "$RC" 1
check "answering no changes nothing" test "$(find "$DRIVE" -maxdepth 1 -name 'hermit-backup.old-*' | wc -l)" -eq 0
run "$SRC" "y
" backup "$DRIVE"
check_rc "answering yes makes a fresh backup and exits 0" "$RC" 0
check "answering yes keeps a dated copy of the old backup" test "$(find "$DRIVE" -maxdepth 1 -name 'hermit-backup.old-*' | wc -l)" -eq 1

printf '\n%d failure(s)\n' "$fails"
[ "$fails" -eq 0 ]