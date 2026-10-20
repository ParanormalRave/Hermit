# Learning notes

Short notes, appended after each step: what we built, the key concept, one gotcha.

---

## Step 0 — repo skeleton and the `hermit` stub

**Built:** `hermit/` with `lib/`, `tests/`, an executable `hermit` stub
(shebang, `set -euo pipefail`, `HERMIT_VERSION`, `usage()`, TODO stubs for
`cmd_backup`/`cmd_restore`, and a `main()` dispatcher using `case`), plus
`README.md` and this file.

**Key concept:** a dispatcher. `main "$@"` takes whatever the user typed and
routes it to one function via `case`. The program's shape is decided in one
readable place instead of scattered through the file.

**Gotcha:** `"$@"` must stay quoted or arguments with spaces split apart — and
`${1:-}` (not `$1`) is needed because `set -u` makes a bare `$1` an error when
no argument was given at all.

---

## Housekeeping — README restored, rules written down

**Built:** `AGENTS.md` (the working rules, scope, manifest format, safety rules
and definition of done, committed with the repo) and a restored `README.md`.

**Key concept:** the author's original README had been replaced by a shorter
rewrite in Step 0. Separate commits keep both, so the mistake and the fix stay
visible in history instead of being erased.

**Gotcha:** project rules are read from the working directory **upwards**, never
downwards. An `AGENTS.md` sitting in a subfolder you have not entered is a dead
file — which is why the session was moved into `hermit/`.

## Step 1 — `lib/common.sh`

**Built:** `info`, `warn`, `error` — three loggers, all writing to stderr with a
`[hermit]` prefix. `error()` prints `ERROR:` and exits `1`.

**Key concept:** stdout vs stderr. Logs go to stderr, so stdout stays clean for
results — `--dry-run` lines and the summary can be piped or diffed without log
noise mixed in. `printf '%s\n' "$*"` prints the message literally.

**Gotcha:** prefer `printf` over `echo`, and keep `"$*"` quoted. `echo` treats a
leading `-n`/`-e` in the message as a flag and can swallow the newline;
unquoted `$*` collapses repeated spaces and expands globs, so
`info "saved *.txt"` would expand against the current directory. Also:
`error()` is for preconditions only — in `restore`, one unreadable file must
`warn` and increment the `failed` counter, or a single bad file would abort the
whole restore.
