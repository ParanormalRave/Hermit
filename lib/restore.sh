#!/usr/bin/env bash
# lib/restore.sh — decide what restore will do with every manifest row.
# shellcheck shell=bash

# restore_plan BACKUP_DIR
# Prints ACTION<TAB>TYPE<TAB>REL for every manifest row. Changes nothing.
restore_plan() {
  local backup=${1:-}
  local manifest="$backup/manifest.tsv"
  local type rel target action b
  local -a blocked=()

  [ -r "$manifest" ] || return 1

  while IFS=$'\t' read -r type rel _ _; do
    action=""

    if ! target=$(home_abs "$rel"); then
      action=skip-unsafe
    fi

    if [ -z "$action" ]; then
      for b in "${blocked[@]+"${blocked[@]}"}"; do
        if [[ "$rel" == "$b"/* ]]; then
          action=blocked
          break
        fi
      done
    fi

    if [ -z "$action" ]; then
      if [ "$type" = d ]; then
        if [ -L "$target" ]; then
          action=conflict
        elif [ -d "$target" ]; then
          action=have-dir
        elif [ -e "$target" ]; then
          action=conflict
        else
          action="mkdir"
        fi
      elif [ -L "$backup/files/$rel" ] || [ ! -f "$backup/files/$rel" ]; then
        action=skip-missing
      elif [ -e "$target" ] || [ -L "$target" ]; then
        action=skip-exists
      else
        action=copy
      fi
    fi

    if [ "$action" = conflict ]; then
      blocked+=("$rel")
    fi
    printf '%s\t%s\t%s\n' "$action" "$type" "$rel"
  done < <(manifest_read "$manifest")
}

# restore_dry_run BACKUP_DIR
# Prints what restore WOULD do, one line per row, plus a summary. Changes nothing.
restore_dry_run() {
  local backup=${1:-}
  local action type rel
  local n_copy=0 n_dir=0 n_skip=0

  while IFS=$'\t' read -r action type rel; do
    case "$action" in
      copy)      n_copy=$(( n_copy + 1 )) ;;
      mkdir)     n_dir=$(( n_dir + 1 )) ;;
      have-dir)  continue ;;
      *)         n_skip=$(( n_skip + 1 )) ;;
    esac
    printf '%-12s %s\n' "$action" "$rel"
  done < <(restore_plan "$backup")

  printf 'dry run: would copy %d file(s), create %d folder(s), skip %d\n' \
    "$n_copy" "$n_dir" "$n_skip"
}