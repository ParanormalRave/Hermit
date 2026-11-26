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

## Step 2 — `lib/paths.sh`

**Built:** `in_home` (is this path under `$HOME`?), `home_rel` (absolute path →
`Documents/notes.txt`) and `home_abs` (relative path → `$HOME/...`), plus the
internal `_valid_rel` that rejects absolute input, trailing slashes, `//`,
`.` and `..` components.

**Key concept:** the manifest stores *relative* paths only. `/home/rave/notes`
would break on a machine whose user is `sam`; `Documents/notes` does not. These
three helpers are the single place where that translation happens, so `backup`
and `restore` never hardcode a username. They return non-zero instead of
printing a message — the caller decides whether a bad path is fatal (`error`)
or a `warn` plus a failed count.

**Gotcha:** prefix matching alone is not containment. `/home/rave/../etc/passwd`
starts with `$HOME/` but points at `/etc`, so `..` must be rejected as a
*component*; splitting on `/` with `local IFS=/` and comparing whole parts is
safer than a `case` glob. Also `HOME=${HOME%/}` so a trailing slash on `$HOME`
cannot turn `$HOME/*` into `//*`; when `HOME=/` the trimmed value is empty and
`printf '%s/%s' "" "etc"` still yields `/etc`.

## Step 3 — `lib/manifest.sh`

**Built:** `manifest_init` (write the header), `manifest_add` (append one
validated row) and `manifest_read` (check the header, then stream valid rows),
plus the internal `_manifest_valid` used by both writer and reader.

**Key concept:** one format authority. Every row is checked twice — on the way
in and on the way out — so a hand-edited or corrupt manifest cannot smuggle an
absolute path or `..` into `restore`. Writer and reader share `_manifest_valid`
so they can never disagree about what "valid" means. Bad data rows are warnings
(the caller counts them); a bad *header* is fatal, because then every row is
suspect.

**Gotcha:** `done < <(manifest_read "$file")` runs the reader in a **subshell**,
so its exit status never reaches `restore` — a wrong header would silently
produce zero rows and look like success. Step 4 must validate the header
separately (or read the file twice) before trusting the stream. Also
`while IFS= read -r line || [ -n "$line" ]`: without the `|| [ -n ... ]` tail, a
final line with no trailing newline is dropped silently.

---

## Design decision — symlinks are skipped in v0.1

**Decision:** `backup` will skip symlinks and print a warning. It will not
follow them and will not write them to the manifest.

**Why:** the manifest has only two types, `f` (file) and `d` (directory), and
`in_home` compares paths as plain strings without resolving symlinks. A link
can point outside `$HOME`, so following it would copy data from outside the
agreed scope, and recording it as `f` or `d` would restore the wrong thing.
Skipping with a warning keeps v0.1 inside its safety rules.

**When:** implement this in `cmd_backup`; not before.

---

## Step 0a — HERMIT_VERSION to 0.1.0-dev

**Built:** one-line change in `hermit`: `HERMIT_VERSION="0.1.0-dev"`.

**Key concept:** single source of truth for the version — `--version` and
`meta.env` will both read this variable, so changing it here changes it
everywhere.

**Gotcha:** keep `"$HERMIT_VERSION"` quoted when printing. Unquoted, a
version with spaces or globs (`*`) would split or expand against the current
directory instead of printing literally.

---

## Step 0b — document `engine/` in AGENTS.md

**Built:** one line under `## Drive layout`: `engine/` holds a copy of
`hermit` and `lib/` so a new machine can restore straight from the drive,
and it is NOT listed in `manifest.tsv`.

**Key concept:** spec before code. Writing the layout down first means
`cmd_backup` step 2d cannot invent a different path or accidentally include
`engine/` in the manifest.

**Gotcha:** the manifest stores `$HOME`-relative files only
(`Documents/...`), so `engine/` — which is program code on the drive, not
user data — must stay out of it, or `restore` would copy `hermit` itself
into `$HOME`.

---

## Step 0c — safe cleanup trap in `tests/test_lib.sh`

**Built:** replaced `trap 'rm -r -- "$FAKE_HOME"' EXIT` with a `cleanup()`
function that only removes `$FAKE_HOME` when it matches `/tmp/*`, and
refuses otherwise. `FAKE_HOME` still comes from `mktemp -d`.

**Key concept:** `trap cleanup EXIT` runs the function when the script ends
for any reason (pass, fail, or `set -e` abort), so temp dirs never pile up.
`case` with the `/tmp/*` glob is the guard — string matching happens before
any `rm` runs.

**Gotcha:** the old one-liner expanded `$FAKE_HOME` at trap time. If
`mktemp` had failed (empty value) the trap would run `rm -r -- ""` and
error, and a typo like `FAKE_HOME=/` would delete outside `/tmp`. The guard
makes both cases print `refusing to remove ...` instead. Also kept `rm -r`,
never `rm -rf` — the repo safety rule forbids `rm -rf` entirely.

---

## Step 0d — ShellCheck sweep (clean, no fixes)

**Built:** nothing — ran `shellcheck hermit lib/*.sh tests/*.sh`
(ShellCheck 0.11.0) and confirmed exit 0 with zero warnings, plus
`bash tests/test_lib.sh` still `0 failure(s)`.

**Key concept:** ShellCheck is a static linter: it reads the code without
running it and flags quoting, subshell, and exit-code bugs. Exit 0 with no
output means clean — the required end-of-step gate.

**Gotcha:** no output IS the pass signal. A new warning after a future edit
means the edit introduced it — fix only that warning, don't reformat
working code around it.

---

## macOS support series (feat/macos-support) — one portable code path for both OSes

**Built:** macOS support across `lib/common.sh` (`stat_mode`/`stat_size`: GNU
`stat -c` then BSD `stat -f`), `lib/drive.sh` (`df -P -k` times 1024, `mount`
table parsing with longest-prefix match when `findmnt` is missing,
`find -print0` sizes), `lib/manifest.sh` (`find -print0` build, parent-first
order kept), `lib/restore.sh` (pure-bash `_canonical`/`_collapse` replacing
`realpath -m`, indexed mode arrays replacing `local -A`), `hermit`
(`readlink`-loop plus `cd -P` script path, per-folder trailing-slash rsync
with probed `--no-links`/`--info`, top-folder `chmod` from source mode),
portable tests (`touch -t`, `-ot`/`-nt` mtime, `TMPDIR`-aware guard),
`install.sh` (`~` via variable, OS-neutral hints), docs and a macOS CI job.

**Key concept:** probe, don't detect. Instead of checking `uname`, each step
tries the GNU spelling and falls back to the BSD one (`stat -c` else
`stat -f`), or greps `rsync --help` for a flag before using it. One code
path runs everywhere, and the fake-HOME round trip (`diff -r` clean) proves
both sides agree on modes, mtimes and layout.

**Gotcha:** three traps. (1) `set -e` plus `[ cond ] && action` as a
statement aborts when the condition is false — use a real `if`. (2)
`"array[@]"` on an empty array under `set -u` fails on bash 3.2 — use the
`${arr[@]+"${arr[@]}"}` idiom the codebase already uses. (3) `/var` is a
symlink to `/private/var` on macOS, so `_canonical` tests must compare
against the `cd -P` physical base, not the `mktemp` path as printed.
