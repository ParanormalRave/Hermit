#!/usr/bin/env bash
# lib/manifest.sh — read and write manifest.tsv.
# shellcheck shell=bash
#
# Requires: lib/common.sh (warn) and lib/paths.sh (_valid_rel).
# Source order: common.sh, paths.sh, manifest.sh.

MANIFEST_HEADER=$'type\tpath\tsize\tmode'

# _manifest_valid TYPE REL SIZE MODE
# Internal: every row must satisfy this before it is written or trusted.
_manifest_valid() {
  local type=${1:-}
  local rel=${2:-}
  local size=${3:-}
  local mode=${4:-}

  case "$type" in
    f | d) ;;
    *) return 1 ;;
  esac

  case "$rel" in
    '' | *$'\t'* | *$'\n'*) return 1 ;;
  esac
  _valid_rel "$rel" || return 1

  case "$size" in
    '' | *[!0-9]*) return 1 ;;
  esac

  case "$mode" in
    [0-7][0-7][0-7] | [0-7][0-7][0-7][0-7]) ;;
    *) return 1 ;;
  esac

  return 0
}

# manifest_init FILE
# Create or truncate FILE and write the header line.
manifest_init() {
  local file=${1:-}

  [ -n "$file" ] || return 1
  printf '%s\n' "$MANIFEST_HEADER" > "$file"
}

# manifest_add FILE TYPE REL SIZE MODE
# Append one validated row. Returns 1 and prints nothing on bad input, so the
# caller decides whether to warn, count, or abort.
manifest_add() {
  local file=${1:-}
  local type=${2:-}
  local rel=${3:-}
  local size=${4:-}
  local mode=${5:-}

  [ -n "$file" ] || return 1
  _manifest_valid "$type" "$rel" "$size" "$mode" || return 1

  printf '%s\t%s\t%s\t%s\n' "$type" "$rel" "$size" "$mode" >> "$file"
}

# manifest_read FILE
# Verify the header, then print each valid row to stdout. Blank lines and
# comments are skipped. A bad header returns 1; a bad data row warns and is
# skipped so restore can count it as failed.
manifest_read() {
  local file=${1:-}
  local line type rel size mode
  local header_seen=0
  local -a fields

  [ -r "$file" ] || return 1

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '' | '#'*) continue ;;
    esac

    if [ "$header_seen" -eq 0 ]; then
      [ "$line" = "$MANIFEST_HEADER" ] || return 1
      header_seen=1
      continue
    fi

    IFS=$'\t' read -r -a fields <<< "$line"
    if [ "${#fields[@]}" -ne 4 ]; then
      warn "manifest: skipping malformed line: $line"
      continue
    fi

    type=${fields[0]}
    rel=${fields[1]}
    size=${fields[2]}
    mode=${fields[3]}

    if ! _manifest_valid "$type" "$rel" "$size" "$mode"; then
      warn "manifest: skipping invalid row: $line"
      continue
    fi

    printf '%s\t%s\t%s\t%s\n' "$type" "$rel" "$size" "$mode"
  done < "$file"

  [ "$header_seen" -eq 1 ]
}
