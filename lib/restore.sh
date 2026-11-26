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

# _collapse PATH
# Print absolute PATH with every "." and ".." resolved textually.
# Needed because a symlink target can contain "..", which would fool a
# plain prefix check ("$HOME/../outside" starts with "$HOME/").
_collapse() {
  local path=${1:-}
  local IFS=/
  local -a parts=() out=()
  local part
  case "$path" in /*) ;; *) return 1 ;; esac
  read -r -a parts <<< "$path"
  for part in "${parts[@]}"; do
    case "$part" in
      '' | .) continue ;;
      ..)
        if [ "${#out[@]}" -gt 0 ]; then
          unset "out[$((${#out[@]} - 1))]"
        fi
        ;;
      *) out+=("$part") ;;
    esac
  done
  if [ "${#out[@]}" -eq 0 ]; then
    printf '/\n'
  else
    printf '/%s\n' "${out[*]}"
  fi
}

# _canonical PATH
# Print PATH with every symlink resolved, without requiring the whole path
# to exist (a portable `realpath -m`). Walks down to the nearest existing
# ancestor, chases symlinks with plain readlink, then asks the shell for
# the physical directory with cd -P/pwd -P.
_canonical() {
  local path=${1:-}
  local head tail base dir link
  [ -n "$path" ] || return 1
  case "$path" in
    /*) ;;
    *) path="$PWD/$path" ;;
  esac
  head=$path
  tail=""
  while [ ! -e "$head" ] && [ ! -L "$head" ]; do
    [ "$head" = / ] && return 1
    base=${head##*/}
    tail="/$base$tail"
    head=${head%/*}
    [ -n "$head" ] || head=/
  done
  while [ -L "$head" ]; do
    link=$(readlink "$head") || return 1
    case "$link" in
      /*) head=$link ;;
      *) head=${head%/*}/$link ;;
    esac
    head=$(_collapse "$head") || return 1
  done
  if [ -d "$head" ]; then
    dir=$(cd -P -- "$head" 2>/dev/null && pwd -P) || return 1
    printf '%s\n' "$dir$tail"
  else
    base=${head##*/}
    dir=${head%/*}
    [ -n "$dir" ] || dir=/
    dir=$(cd -P -- "$dir" 2>/dev/null && pwd -P) || return 1
    printf '%s\n' "$dir/$base$tail"
  fi
}

# _inside_home TARGET
# True if TARGET, after following every symlink on its path, is under $HOME.
_inside_home() {
  local target=${1:-} home_real real
  home_real=$(_canonical "$HOME") || return 1
  real=$(_canonical "$target") || return 1
  [[ "$real" == "$home_real"/* ]]
}

# restore_apply BACKUP_DIR
# Carries out restore_plan: creates folders and copies files. Never overwrites.
# Returns EX_PARTIAL if anything was refused or failed.
# Folder modes from the manifest are applied last, deepest first, and only to
# folders this run created.
restore_apply() {
  local backup=${1:-}
  local action type rel target mode i j
  local n_dir=0 n_copy=0 n_skip=0 n_fail=0
  # Parallel indexed arrays (bash 3.2 has no assoc arrays): mode_rels[k]
  # holds the folder path for the mode in mode_vals[k].
  local -a mode_rels=() mode_vals=()
  local -a made=() made_modes=()

  while IFS=$'\t' read -r type rel _ mode; do
    if [ "$type" = d ]; then
      mode_rels+=("$rel")
      mode_vals+=("$mode")
    fi
  done < <(manifest_read "$backup/manifest.tsv")

  while IFS=$'\t' read -r action type rel; do
    case "$action" in
      have-dir)    continue ;;
      skip-exists) n_skip=$(( n_skip + 1 )); continue ;;
      mkdir | copy) ;;
      *)
        warn "skipping ($action): $rel"
        n_skip=$(( n_skip + 1 ))
        continue
        ;;
    esac

    target=$(home_abs "$rel") || { n_fail=$(( n_fail + 1 )); continue; }

    if ! _inside_home "$target"; then
      warn "refusing to write outside your home folder: $rel"
      n_fail=$(( n_fail + 1 ))
      continue
    fi

    if [ "$action" = mkdir ]; then
      if mkdir -p -- "$target"; then
        n_dir=$(( n_dir + 1 ))
        made+=("$rel")
        mode=""
        for (( j = 0; j < ${#mode_rels[@]}; j++ )); do
          if [ "${mode_rels[$j]}" = "$rel" ]; then
            mode=${mode_vals[$j]}
            break
          fi
        done
        made_modes+=("$mode")
      else
        warn "could not create folder: $rel"
        n_fail=$(( n_fail + 1 ))
      fi
    else
      if [ -e "$target" ] || [ -L "$target" ]; then
        n_skip=$(( n_skip + 1 ))
        continue
      fi
      if cp -p -- "$backup/files/$rel" "$target"; then
        n_copy=$(( n_copy + 1 ))
      else
        warn "could not copy: $rel"
        n_fail=$(( n_fail + 1 ))
      fi
    fi
  done < <(restore_plan "$backup")

  # Modes last, deepest first: a read-only folder must not block its own files.
  for (( i = ${#made[@]} - 1; i >= 0; i-- )); do
    rel=${made[$i]}
    mode=${made_modes[$i]}
    [ -n "$mode" ] || continue
    target=$(home_abs "$rel") || continue
    if ! chmod "$mode" "$target"; then
      warn "could not set mode $mode on: $rel"
      n_fail=$(( n_fail + 1 ))
    fi
  done

  if [ "$n_fail" -eq 0 ]; then
    ok "restored $n_copy file(s), created $n_dir folder(s), skipped $n_skip, failed $n_fail"
  else
    warn "restored $n_copy file(s), created $n_dir folder(s), skipped $n_skip, failed $n_fail"
    return "$EX_PARTIAL"
  fi
}