# Using Hermit

## Synopsis

```
hermit backup DRIVE
hermit restore DRIVE [--dry-run]
hermit --help
hermit --version
```

`DRIVE` is the folder where your drive is mounted, for example `/media/you/MyDrive`.

## Requirements

- Linux with bash. Hermit targets Debian and Ubuntu, and is developed on Fedora.
- `rsync`
- The usual GNU tools (`find`, `stat`, `df`, `realpath`), which every mainstream distribution has.
- Optional: `findmnt` (to detect the drive's filesystem) and `numfmt` (to print sizes like `1.2GiB`). Hermit works without them.

## Backing up

```bash
hermit backup /media/you/MyDrive
```

Hermit saves these folders from your home folder, if they exist: **Documents, Downloads, Desktop, Pictures, Videos, Music**.

Before copying anything, it checks:

1. The drive path is a folder, and Hermit can really write to it (it creates and removes a tiny hidden test file).
2. There is enough free space for your files plus 5%.
3. What filesystem the drive uses. FAT, exFAT and NTFS drives get a warning, because they cannot store Linux permissions.

The backup is written to `MyDrive/hermit-backup/`. See [HOW-IT-WORKS](HOW-IT-WORKS.md) for what is inside.

### If a backup already exists

Hermit asks:

```
[hermit] .../hermit-backup already exists. Keep it as a dated copy and make a fresh backup? [y/N]
```

- **y**: the old backup is renamed to `hermit-backup.old-YYYYMMDD-HHMMSS` and a fresh one is made. You need free space for both.
- **anything else (or Enter)**: nothing changes, and Hermit exits with code 1.

### What is not saved

- Symbolic links (shortcuts to other files or folders). Each one is reported when skipped.
- Files whose names contain a tab or a newline character. They are reported when skipped.
- Anything outside the six folders above, including hidden files in your home folder such as `~/.config`.

## Restoring

Always look first:

```bash
hermit restore /media/you/MyDrive --dry-run
```

A dry run changes nothing. It prints one line per item:

| Action | Meaning |
|--------|---------|
| `mkdir` | The folder is missing and would be created. |
| `copy` | The file is missing and would be copied. |
| `skip-exists` | A file is already there. It is never overwritten. |
| `skip-missing` | The manifest lists it, but the backup does not have it. |
| `conflict` | A file or a symlink sits where a folder should be. |
| `blocked` | Inside a `conflict`, so skipped. |
| `skip-unsafe` | The path in the manifest failed validation. |

Folders that already exist are not listed. The last line is a summary: how many files would be copied, how many folders created, how many skipped.

When the plan looks right:

```bash
hermit restore /media/you/MyDrive
```

Restore starts straight away, with no confirmation question, so use `--dry-run` first.

### Restore rules

- It restores into the home folder of the user running it. A different username on the new machine is fine.
- It **never overwrites** an existing file.
- It never writes outside your home folder, even if a folder in your home is a symlink pointing elsewhere.
- File modification times and permissions are kept.
- Folders it creates get the permissions they had on the old machine. Folders that already existed are left alone.
- It never deletes anything, and it never writes to the drive.

Running restore twice is safe: the second run finds everything already there and copies nothing.

## Environment variables

| Variable | Effect |
|----------|--------|
| `NO_COLOR` | Set to any value to turn colors off. |
| `HERMIT_COLOR` | `always` or `never` to force colors on or off. Default is `auto`. |

## Examples

First backup:

```bash
hermit backup /media/you/MyDrive
```

On the new machine, after installing Hermit and plugging the drive in:

```bash
hermit restore /media/you/MyDrive --dry-run
hermit restore /media/you/MyDrive
```

Look at the result from a script:

```bash
hermit restore /media/you/MyDrive
echo $?    # 0 = all good, 6 = some items were skipped or refused
```

For every exit code, see [EXIT-CODES](EXIT-CODES.md). Problems? See the [FAQ](FAQ.md).
