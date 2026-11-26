#!/usr/bin/env bash
# lib/drive.sh — checks on the drive before we copy to it, and after.
# shellcheck shell=bash

# drive_probe DIR
# Really try to write to DIR. Permission bits can lie (read-only mounts, full disks).
drive_probe() {
  local dir=${1:-} probe
  [ -d "$dir" ] || return 1
  probe=$(mktemp "$dir/.hermit-probe.XXXXXX" 2>/dev/null) || return 1
  if ! printf 'x' > "$probe" 2>/dev/null; then
    rm -f -- "$probe"
    return 1
  fi
  rm -f -- "$probe"
}

# drive_free_bytes DIR
# Prints the free space, in bytes, on the filesystem that holds DIR.
# Uses -k (BSD and GNU agree on it) and multiplies by 1024, because -B1
# is GNU-only and the capacity columns differ between the two.
drive_free_bytes() {
  local dir=${1:-} free
  [ -n "$dir" ] || return 1
  free=$(df -P -k "$dir" 2>/dev/null | awk 'NR==2 {print $4 * 1024}') || return 1
  case "$free" in '' | *[!0-9]*) return 1 ;; esac
  printf '%s\n' "$free"
}

# space_ok FREE NEEDED
# True if FREE bytes cover NEEDED bytes plus a 5% margin.
space_ok() {
  local free=${1:-} need=${2:-}
  case "$free" in '' | *[!0-9]*) return 1 ;; esac
  case "$need" in '' | *[!0-9]*) return 1 ;; esac
  [ "$free" -ge $(( need + need / 20 )) ]
}

# drive_fstype DIR
# Prints the filesystem type under DIR (ext4, apfs, ...), or nothing if unknown.
# On Linux this asks findmnt. On macOS there is no findmnt, so we parse the
# `mount` table (`<dev> on <mp> (<fstype>,...)`) and take the longest mount
# point that holds DIR. Best effort: when nothing parses, stay silent.
drive_fstype() {
  local dir=${1:-}
  [ -n "$dir" ] || return 0
  if command -v findmnt >/dev/null 2>&1; then
    findmnt -no FSTYPE -T "$dir" 2>/dev/null | head -n 1 || true
    return 0
  fi
  local canon line rest mp opts best="" best_len=-1
  if canon=$(cd -P -- "$dir" 2>/dev/null && pwd -P); then
    dir=$canon
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in *" on "*\(*\)*) ;; *) continue ;; esac
    rest=${line#* on }
    mp=${rest%% \(*}
    opts=${rest#*(}
    opts=${opts%%[,)]*}
    [ -n "$mp" ] || continue
    if [ "$mp" = / ]; then
      case "$dir" in /*) ;; *) continue ;; esac
    else
      case "$dir" in "$mp" | "$mp"/*) ;; *) continue ;; esac
    fi
    if [ "${#mp}" -gt "$best_len" ]; then
      best=$opts
      best_len=${#mp}
    fi
  done < <(mount 2>/dev/null)
  [ -n "$best" ] && printf '%s\n' "$best"
  return 0
}

# fs_is_lossy FSTYPE
# True for filesystems that cannot keep Linux permissions or symlinks.
fs_is_lossy() {
  case "${1:-}" in
    vfat | msdos | exfat | ntfs | ntfs3 | fuseblk) return 0 ;;
    *) return 1 ;;
  esac
}

# backup_size_bytes DIR...
# Prints the total size of the regular files under the given folders.
# Symlinks are not counted, because the backup does not copy them.
# find -print0 plus stat_size replaces the GNU-only -printf '%s'.
backup_size_bytes() {
  local path size total=0
  while IFS= read -r -d '' path; do
    size=$(stat_size "$path" 2>/dev/null) || continue
    total=$(( total + size ))
  done < <(find "$@" -type f -print0 2>/dev/null)
  printf '%s\n' "$total"
}

# rsync_exit_to_hermit CODE
# Maps an rsync exit code to a Hermit exit code.
rsync_exit_to_hermit() {
  case "${1:-}" in
    0 | 24) printf '%s\n' 0 ;;
    23) printf '%s\n' "$EX_PARTIAL" ;;
    11 | 12) printf '%s\n' "$EX_DRIVE" ;;
    *) printf '%s\n' "$EX_FAIL" ;;
  esac
}