# FAQ

## Does Hermit back up my installed programs and settings?

Not yet. Version 0.1 saves files only: Documents, Downloads, Desktop, Pictures, Videos and Music. A software list and app settings are planned for later versions.

## Do I need Hermit on the new machine?

Yes, for now. Install it there (see the README), plug in the drive, and run `hermit restore`. Your files are plain copies, so you can also copy them out of `hermit-backup/files/` by hand if you ever need to.

## Does restore overwrite my files?

Never. If a file already exists, it is skipped. Use `--dry-run` to see exactly which files would be copied and which skipped.

## My username is different on the new machine. Is that a problem?

No. Backups store paths relative to your home folder, and restore puts them into the home folder of whoever runs it.

## Which drive format should I use?

A Linux filesystem such as ext4 keeps everything: permissions, dates and names. FAT32, exFAT and NTFS cannot store Linux permissions, so folders and files may come back with default permissions. Hermit warns you when it detects one of those. FAT32 also cannot hold files bigger than 4 GiB.

## Is the backup encrypted?

No. If your drive could be lost or stolen, put the backup on an encrypted drive (for example one set up with LUKS).

## Can I look inside a backup without Hermit?

Yes. Open `hermit-backup/files/` in any file manager.

## What happens to symbolic links?

They are not copied. Hermit prints a warning for each one it skips.

## Why was a file not saved or restored?

The usual reasons:

- its name contains a tab or a newline (a warning is printed);
- it is a symbolic link;
- it is outside the six standard folders;
- you could not read it (rsync reports "Permission denied", and Hermit finishes with exit code 6);
- on restore, a file with that name already exists.

## I ran backup twice. What happened?

The second time Hermit asked whether to keep the old backup as a dated copy. Answer `y` to keep it and make a fresh backup, or anything else to cancel. Backups are not incremental, so keeping both needs space for both.

## What do the colors mean?

Red `ERROR`: it stopped. Yellow `WARN`: something was skipped or is worth knowing, and it carried on. Green `OK`: it finished cleanly. Colors turn off when output is piped, or when `NO_COLOR` is set.

## How do I know a backup worked?

The last line is a green `OK: backup complete`, and the exit code is 0 (`echo $?`). To double-check, run `hermit restore DRIVE --dry-run` and look at the plan.

## It stopped with an exit code. What does that mean?

See [EXIT-CODES](EXIT-CODES.md).

## Where do I ask questions or report bugs?

Open an issue on the GitHub repository. Please include the Hermit version (`hermit --version`), your distribution, the command you ran, and the full output.
