# How Hermit works

## What a backup looks like

Everything lives in one folder on the drive:

```
MyDrive/
└── hermit-backup/
    ├── files/          plain copies of your folders
    │   ├── Documents/
    │   ├── Pictures/
    │   └── ...
    ├── manifest.tsv    the list of everything that was saved
    └── meta.env        facts about the backup
```

`files/` is an ordinary folder tree. You can open it in a file manager and copy things out by hand, with or without Hermit.

Older backups that you chose to keep sit next to it as `hermit-backup.old-YYYYMMDD-HHMMSS`.

## The manifest

`manifest.tsv` is a tab-separated text file. The first lines are:

```
# hermit manifest v1
type	path	size	mode
```

Then one line per item:

```
d	Documents	0	755
f	Documents/my notes.txt	3	644
```

- **type**: `d` for a folder, `f` for a regular file.
- **path**: relative to your home folder, never starting with `/`.
- **size**: bytes. Always `0` for folders.
- **mode**: Linux permissions in octal, for example `644`.

Restore reads this list to decide what to do. Names containing a tab or newline cannot be written in this format, so those files are skipped with a warning.

## meta.env

`meta.env` is a few `KEY=value` lines:

```
HERMIT_VERSION=0.1.0
BACKUP_DATE=2026-11-26T15:04:05Z
SOURCE_USER=rave
SOURCE_HOME=/home/rave
```

The date is UTC in ISO 8601. Hermit reads this file as plain text. It never runs it as a script.

## What `backup` does, in order

1. Check the drive: it exists, is writable (a real write test), has enough free space, and what filesystem it is.
2. Look for the six standard folders in your home. Missing ones, and folders that are symlinks, are skipped.
3. If a backup is already there, ask what to do.
4. Copy the folders with `rsync` (no symlinks, keeping times and permissions).
5. Build the manifest from what is now on the drive, so it describes the backup exactly.
6. Write `meta.env`, then print a summary.

## What `restore` does, in order

1. Check the drive has a valid backup: the folder, a readable manifest with a correct header, and the `files` folder.
2. **Plan**: go through the manifest and decide what to do with each item. This step only reads. It changes nothing.
3. If you used `--dry-run`: print the plan and stop.
4. **Apply**: carry out the plan. Create missing folders, copy missing files.
5. Set the permissions of the folders it created, last, deepest first, so a read-only folder cannot block its own files.
6. Print a summary.

The dry run and the real restore use the same plan code, so the dry run cannot promise something the real run does differently.

## Safety rules

- Backup only reads your home folder and writes only to the drive.
- Restore only writes inside your home folder, and never to the drive.
- Restore never overwrites and never deletes.
- Before writing, restore resolves every symlink on the path and refuses if the real location is outside your home folder.
- Every path from the manifest is validated: no absolute paths, no `..`, no empty parts, no tabs or newlines.
- Hermit uses no `sudo`.

## Testing

- `tests/test_lib.sh` tests the building blocks one by one.
- `tests/test_v01.sh` runs a whole backup and restore in a temporary fake home and checks the result.
- Both run in a temporary folder and never touch your real files.
- GitHub Actions runs ShellCheck and both test files on Ubuntu for every push.

```bash
bash tests/test_lib.sh
bash tests/test_v01.sh
```

## Known limits in v0.1

- Only the six standard folders. Software lists and app settings are planned, not built.
- No symlinks, and no names with tabs or newlines.
- No compression, no encryption, and not incremental: each backup is a fresh full copy.
- Drives formatted FAT, exFAT or NTFS lose Linux permissions. Hermit warns about it but does not yet work around it.
- Hermit must be installed on the new machine before it can restore.
