# AGENTS.md — Hermit

Standing instructions for any agent working in this repo. Adopted 2026-10-20
with the author's explicit permission. If a later instruction from the author
conflicts with anything here, ASK — do not guess.

Run agents from this directory (the repo root). Project rules load only when
the working directory is this repo or below it.

## Project
Hermit is a bash CLI. `hermit backup <drive>` copies the user's folders to the
drive and writes a manifest recording where everything belongs.
`hermit restore <drive>` puts it back on a new machine. It never overwrites
silently and supports `--dry-run`. Target: Debian/Ubuntu, bash 5, rsync.

## How the author wants to work (mandatory)
1. Small steps. One function or feature at a time. Never dump whole files or
   many files at once.
2. Before writing code, state in 2-3 sentences what you will do and why.
3. After each piece, explain every non-obvious line in plain English. For bash
   specifics (`set -euo pipefail`, `${var:-}`, `shift`, `trap`, quoting,
   `local`, `case`) explain what it does AND what breaks without it.
4. STOP after each step and wait for the author to say "next".
5. After each step, give the exact command to run and the exact expected output.
6. Every few steps, ask one short comprehension question and wait for the answer.
7. After each step, append a note to LEARNING.md: what we built, the key
   concept, one gotcha.
8. NEVER guess. If a path, flag, or behavior is not specified, ASK. Do not
   invent file names, folders, or features.

## Scope — v0.1 ONLY
IN: backup of user folders, manifest, restore, --dry-run.
OUT: packages, dotfiles/configs, encryption, username remapping, other OSes.
Do not add these or "prepare for" them.

## Files (create only these, one at a time, as needed)
hermit, lib/common.sh, lib/manifest.sh, lib/paths.sh, tests/test_v01.sh,
LEARNING.md, README.md, AGENTS.md (this file).

## README.md — NEVER EDIT
README.md is the author's original text. Do not rewrite, reformat, or
"improve" it for any reason.

## What gets backed up
Only these folders under $HOME, and only if they exist: Documents, Downloads,
Desktop, Pictures, Videos, Music. Always use $HOME, never /home/<name>.

## Drive layout
<drive>/hermit-backup/
  manifest.tsv
  meta.env
  files/        mirror of the saved folders, e.g. files/Documents/notes.txt

## manifest.tsv
Tab-separated UTF-8, one entry per line. Lines starting with # are comments.
First non-comment line is the header: type<TAB>path<TAB>size<TAB>mode
- type: f = file, d = directory
- path: RELATIVE to $HOME, never absolute (this is what makes restore work
  when the username changes)
- size: bytes, 0 for directories
- mode: octal permissions, e.g. 644
Rejected: JSON (needs jq), key=value per line (awkward for lists).
v0.1 limitation: filenames containing tabs or newlines are unsupported —
detect them and skip with a warning.

## meta.env
Simple KEY=value lines: HERMIT_VERSION, BACKUP_DATE (ISO 8601), SOURCE_USER,
SOURCE_HOME.

## Commands
hermit backup <drive-path>
- Fail clearly if <drive-path> does not exist or is not writable.
- Create <drive-path>/hermit-backup/ if missing. If it already exists, ask
  before overwriting.
- rsync each existing folder into files/, then write manifest.tsv and meta.env.
- Print a summary: folders saved, file count, total size.

hermit restore <drive-path> [--dry-run]
- Fail if <drive-path>/hermit-backup/manifest.tsv is missing.
- Restore each entry to "$HOME/<path>".
- NEVER overwrite an existing file; skip it and count it as skipped.
- With --dry-run, print what WOULD happen and change NOTHING on disk.
- Print a summary: restored, skipped, failed.

## Safety rules (never break)
- Never write outside $HOME or <drive-path>/hermit-backup/.
- Quote every variable. No `rm -rf` anywhere, ever.
- Never run sudo.
- All testing uses a fake home: HOME=/tmp/fakehome ./hermit backup /tmp/fakedrive.
  Never test against the real home folder.

## Definition of done for v0.1
1. Backup then restore into a fresh empty fake HOME gives an identical tree
   (`diff -r` shows no differences).
2. --dry-run changes nothing on disk, proved by a test.
3. Restoring twice skips everything the second time.
4. ShellCheck passes with no warnings.
5. tests/test_v01.sh passes.

## Current status
- Step 0 done: repo skeleton + `hermit` stub (commit 2ec1dbe).
- Step 1 done: `lib/common.sh` — `info`/`warn`/`error`, all to stderr,
  `error()` exits 1.
- Step 2 done: `lib/paths.sh` — `in_home`/`home_rel`/`home_abs`, home-relative
  paths only, `..` and absolute input refused.
- Step 3 done: `lib/manifest.sh` — `manifest_init`/`manifest_add`/
  `manifest_read`; header checked, bad rows warned and skipped.
- Step 4 next: `hermit` CLI dispatch — source the libs, parse `<drive>` and
  `--dry-run`.
