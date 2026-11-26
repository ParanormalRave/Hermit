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

info() { printf '[hermit] %s\n' "$*" >&2; }
warn() { printf '[hermit] WARN: %s\n' "$*" >&2; }

# die CODE MESSAGE...  print an error and exit with CODE.
die() {
  local code=${1:-1}
  shift
  printf '[hermit] ERROR: %s\n' "$*" >&2
  exit "$code"
}

error() { die "$EX_FAIL" "$@"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$EX_DEPENDENCY" "required command not found: $1"
}