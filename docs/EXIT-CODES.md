# Exit codes

Every Hermit command ends with an exit code. `0` means everything worked. Any other number tells you what kind of problem stopped it, so scripts (and you) can react.

| Code | Name | What it means | What to do |
|-----:|------|---------------|------------|
| 0 | OK | Finished with no problems. | Nothing. |
| 1 | FAIL | A general failure, or you cancelled. For example: none of the standard folders exist in your home, or you answered "no" to the overwrite question. | Read the message. If you cancelled, run the command again. |
| 2 | USAGE | The command line is wrong: missing drive path, unknown command or option. | Run `hermit --help`. |
| 3 | DRIVE | The drive is missing, is not a folder, cannot be written to (read-only, full or no permission), or went away while copying. | Check the drive is plugged in and mounted, and that you can write to it. |
| 4 | SPACE | Not enough free space. Hermit needs the size of your files plus a 5% margin. | Free some space, or use a bigger drive. |
| 5 | BACKUP | There is no valid Hermit backup on that drive: the `hermit-backup` folder, its manifest or its `files` folder is missing, or the manifest is unreadable. | Check you pointed at the right drive. |
| 6 | PARTIAL | Hermit finished, but some items could not be copied or were refused. The rest was done. | Read the warnings above the last line. |
| 7 | DEPENDENCY | A tool Hermit needs is not installed (currently: `rsync`). | Install it, for example `sudo apt install rsync`. |

## Reading the exit code

In a terminal, `$?` holds the code of the last command:

```bash
hermit backup /media/mydrive
echo "exit: $?"
```

In a script:

```bash
hermit backup /media/mydrive
case $? in
  0) echo "backup ok" ;;
  4) echo "drive is full" ;;
  6) echo "backup finished, but some files were skipped" ;;
  *) echo "backup failed" ;;
esac
```

## Colors in messages

Messages go to the error stream (stderr). When it is a terminal, `ERROR` is red, `WARN` is yellow and `OK` is green. Colors are turned off automatically when output is piped or redirected, or when the `NO_COLOR` environment variable is set. `HERMIT_COLOR=always` or `HERMIT_COLOR=never` overrides that.

## Special cases

- rsync reports code 24 when a file disappears while it is being copied (you deleted it mid-backup). Hermit treats that as a warning, not a failure.
- rsync code 23 (some files could not be read) becomes Hermit code 6. The backup is still written, and its manifest lists only what actually reached the drive.
- rsync codes 11 and 12 (disk error, or the connection dropped, as when a drive is unplugged) become code 3.
