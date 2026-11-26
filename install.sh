#!/usr/bin/env bash
# install.sh — install Hermit for the current user. No sudo, nothing outside your home folder.
#
#   curl -fsSL https://raw.githubusercontent.com/ParanormalRave/Hermit/master/install.sh | bash
#
# Optional environment variables:
#   HERMIT_REF=v0.1.0   install a specific tag or branch instead of the default branch
#   HERMIT_HOME=DIR     where to keep the code   (default: ~/.local/share/hermit)
#   HERMIT_BIN=DIR      where to put the command (default: ~/.local/bin)
set -euo pipefail

say() { printf '[hermit-install] %s\n' "$*" >&2; }
fail() {
  printf '[hermit-install] ERROR: %s\n' "$*" >&2
  exit 1
}

# Show the crab panel? HERMIT_CRAB=always|never|auto (auto = only on a real terminal).
crab_wanted() {
  case ${HERMIT_CRAB:-auto} in
    never) return 1 ;;
    always) return 0 ;;
    *) [ -t 2 ] ;;
  esac
}

# How many columns wide is the terminal? (HERMIT_COLS overrides it, for tests.)
terminal_cols() {
  local cols=${HERMIT_COLS:-}
  if [ -z "$cols" ]; then
    cols=$(stty size <&2 2>/dev/null) || cols=''
    cols=${cols##* }
  fi
  case $cols in
    '' | *[!0-9]*) cols=80 ;;
  esac
  printf '%s\n' "$cols"
}

# The crab with the facts beside it when the terminal is wide, under it when it is
# not, and nothing at all when even the crab does not fit. Returns 1 if nothing was
# printed, so the caller can fall back to plain text.
show_panel() {
  local version=$1 link=$2 dir=$3 file=$4
  # A variable, not a literal \~: bash 3.2 keeps the backslash, so the
  # path would print with a stray backslash on macOS.
  local tilde='~'
  local -a art=() text=()
  local line width=0 tw=0 cols on='' off='' i j top
  [ -f "$file" ] || return 1

  while IFS= read -r line || [ -n "$line" ]; do
    art+=("$line")
    if [ "${#line}" -gt "$width" ]; then width=${#line}; fi
  done <"$file"

  text=(
    "installed: $version"
    "command:   ${link/#"$HOME"/$tilde}"
    "code:      ${dir/#"$HOME"/$tilde}"
    "next:      hermit --help"
    "docs:      github.com/ParanormalRave/Hermit"
  )
  for line in "${text[@]}"; do
    if [ "${#line}" -gt "$tw" ]; then tw=${#line}; fi
  done

  cols=$(terminal_cols)
  [ "$cols" -ge "$width" ] || return 1

  if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
    on=$'\033[34m'
    off=$'\033[0m'
  fi

  printf '\n' >&2
  if [ "$cols" -ge $((width + 2 + tw)) ] && [ "${#art[@]}" -ge "${#text[@]}" ]; then
    top=7
    for i in "${!art[@]}"; do
      line=''
      j=$((i - top))
      if [ "$j" -ge 0 ] && [ "$j" -lt "${#text[@]}" ]; then line=${text[$j]}; fi
      printf '%s%-*s%s  %s\n' "$on" "$width" "${art[$i]}" "$off" "$line" >&2
    done
  else
    for line in "${art[@]}"; do
      printf '%s%s%s\n' "$on" "$line" "$off" >&2
    done
    printf '\n' >&2
    printf '%s\n' "${text[@]}" >&2
  fi
  printf '\n' >&2
}

# Everything runs inside main, called on the last line, so a half-downloaded
# script can never execute only part of itself.
main() {
  [ -n "${HOME:-}" ] || fail "HOME is not set"
  local repo=${HERMIT_REPO:-https://github.com/ParanormalRave/Hermit.git}
  local ref=${HERMIT_REF:-}
  local dir=${HERMIT_HOME:-$HOME/.local/share/hermit}
  local bin=${HERMIT_BIN:-$HOME/.local/bin}
  local link=$bin/hermit
  local version

  command -v git >/dev/null 2>&1 || fail "git is required (Debian/Ubuntu: sudo apt install git; macOS: xcode-select --install)"

  if [ -d "$dir/.git" ]; then
    say "updating $dir"
    git -C "$dir" fetch --tags --quiet || fail "could not reach $repo"
    if [ -n "$ref" ]; then
      git -C "$dir" checkout --quiet "$ref" || fail "unknown version: $ref"
    else
      git -C "$dir" pull --ff-only --quiet ||
        fail "could not update $dir (local changes, or pinned to a version). Fix it, or remove that folder and run again."
    fi
  elif [ -e "$dir" ]; then
    fail "$dir exists but is not a Hermit checkout. Move it away, or set HERMIT_HOME."
  else
    say "downloading Hermit into $dir"
    mkdir -p "$(dirname "$dir")"
    if [ -n "$ref" ]; then
      git clone --quiet --branch "$ref" "$repo" "$dir" || fail "could not download $repo ($ref)"
    else
      git clone --quiet "$repo" "$dir" || fail "could not download $repo"
    fi
  fi

  [ -f "$dir/hermit" ] || fail "the download looks incomplete: $dir/hermit is missing"

  mkdir -p "$bin"
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    fail "$link already exists and is not a link. Remove it, or set HERMIT_BIN."
  fi
  ln -sfn "$dir/hermit" "$link"

  if ! command -v rsync >/dev/null 2>&1; then
    say "WARNING: rsync is not installed, and Hermit needs it (Debian/Ubuntu: sudo apt install rsync; macOS ships it with the developer tools)"
  fi

  case ":$PATH:" in
    *":$bin:"*) ;;
    *)
      say "NOTE: $bin is not in your PATH. Add this line to ~/.bashrc, then open a new terminal:"
      say "  export PATH=\"$bin:\$PATH\""
      ;;
  esac

  version=$("$link" --version) || fail "installed, but 'hermit --version' failed"
  if crab_wanted && show_panel "$version" "$link" "$dir" "$dir/assets/crab.txt"; then
    :
  else
    say "installed: $version"
    say "try: hermit --help"
  fi
}

main "$@"
