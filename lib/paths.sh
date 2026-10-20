#!/usr/bin/env bash
# lib/paths.sh — home-relative path helpers.
# shellcheck shell=bash

# _valid_rel REL
# Internal: true when REL is a plain relative path that stays under $HOME.
# Rejects empty, absolute, trailing-slash, "." and ".." components.
_valid_rel() {
  local rel=${1:-}
  local IFS=/
  local -a parts
  local part

  [ -n "$rel" ] || return 1
  case "$rel" in
    /* | */) return 1 ;;
  esac

  read -r -a parts <<< "$rel"
  for part in "${parts[@]}"; do
    case "$part" in
      '' | . | ..) return 1 ;;
    esac
  done
  return 0
}

# in_home PATH
# True when PATH is $HOME itself or a valid path inside it.
in_home() {
  local path=${1:-}
  local home=${HOME%/}
  local rel

  case "$path" in
    "$home" | "$home"/) return 0 ;;
    "$home"/*) rel=${path#"$home"/} ;;
    *) return 1 ;;
  esac

  _valid_rel "$rel"
}

# home_rel PATH
# Print PATH relative to $HOME ("Documents/notes.txt"). Fails for anything
# that is not a valid path strictly inside $HOME.
home_rel() {
  local path=${1:-}
  local home=${HOME%/}
  local rel

  case "$path" in
    "$home"/*) rel=${path#"$home"/} ;;
    *) return 1 ;;
  esac

  _valid_rel "$rel" || return 1
  printf '%s\n' "$rel"
}

# home_abs REL
# Print "$HOME/REL". Fails for REL that is absolute or climbs out with "..".
home_abs() {
  local rel=${1:-}
  local home=${HOME%/}

  _valid_rel "$rel" || return 1
  printf '%s/%s\n' "$home" "$rel"
}
