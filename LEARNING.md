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
