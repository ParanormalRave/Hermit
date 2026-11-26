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
drive_free_bytes() {
  local dir=${1:-} free
  free=$(df -P -B1 -- "$dir" 2>/dev/null | awk 'NR==2 {print $4}') || return 1
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
# Prints the filesystem type under DIR (ext4, vfat, ...), or nothing if unknown.
drive_fstype() {
  command -v findmnt >/dev/null 2>&1 || return 0
  findmnt -no FSTYPE -T "${1:-}" 2>/dev/null | head -n 1 || true
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
backup_size_bytes() {
  local size total=0
  while IFS= read -r size; do
    total=$(( total + size ))
  done < <(find "$@" -type f -printf '%s\n' 2>/dev/null)
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