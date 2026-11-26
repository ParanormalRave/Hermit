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

# Everything runs inside main, called on the last line, so a half-downloaded
# script can never execute only part of itself.
main() {
  [ -n "${HOME:-}" ] || fail "HOME is not set"
  local repo=${HERMIT_REPO:-https://github.com/ParanormalRave/Hermit.git}
  local ref=${HERMIT_REF:-}
  local dir=${HERMIT_HOME:-$HOME/.local/share/hermit}
  local bin=${HERMIT_BIN:-$HOME/.local/bin}
  local link=$bin/hermit version

  command -v git >/dev/null 2>&1 || fail "git is required (Debian/Ubuntu: sudo apt install git)"

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
    say "WARNING: rsync is not installed, and Hermit needs it (Debian/Ubuntu: sudo apt install rsync)"
  fi

  case ":$PATH:" in
    *":$bin:"*) ;;
    *)
      say "NOTE: $bin is not in your PATH. Add this line to ~/.bashrc, then open a new terminal:"
      say "  export PATH=\"$bin:\$PATH\""
      ;;
  esac

  version=$("$link" --version) || fail "installed, but 'hermit --version' failed"
  say "installed: $version"
  say "try: hermit --help"
}

main "$@"