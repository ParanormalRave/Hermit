#!/usr/bin/env bash
# lib/common.sh — logging, exit codes and small shared helpers.
# shellcheck shell=bash

# Exit codes (documented in the README); used by hermit and the other libs.
# shellcheck disable=SC2034  # used by other files
EX_FAIL=1
EX_USAGE=2
EX_DRIVE=3
EX_SPACE=4
EX_BACKUP=5
EX_PARTIAL=6
EX_DEPENDENCY=7

# _c CODE  print a color escape, but only when it makes sense.
# HERMIT_COLOR=always forces color on, =never forces it off; by default color is
# used only when stderr is a terminal and NO_COLOR is not set.
_c() {
  case "${HERMIT_COLOR:-auto}" in
    always) ;;
    never) return 0 ;;
    *) { [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; } || return 0 ;;
  esac
  printf '\033[%sm' "$1"
}

info() { printf '[hermit] %s\n' "$*" >&2; }
warn() { printf '%s[hermit] WARN:%s %s\n' "$(_c 33)" "$(_c 0)" "$*" >&2; }
ok() { printf '%s[hermit] OK:%s %s\n' "$(_c 32)" "$(_c 0)" "$*" >&2; }

# die CODE MESSAGE...  print an error and exit with CODE.
die() {
  local code=${1:-1}
  shift
  printf '%s[hermit] ERROR:%s %s\n' "$(_c 31)" "$(_c 0)" "$*" >&2
  exit "$code"
}

error() { die "$EX_FAIL" "$@"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$EX_DEPENDENCY" "required command not found: $1"
}