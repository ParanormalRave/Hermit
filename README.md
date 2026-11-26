# 🐚 Hermit

![CI](https://github.com/ParanormalRave/Hermit/actions/workflows/ci.yml/badge.svg)

<!-- When assets/hermit-crab-blue.svg is in the repo, remove these comment markers to show the logo:
<p align="center">
  <img src="assets/hermit-crab-blue.svg" alt="Hermit, a hermit crab in its shell" width="160">
</p>
-->

**Same you, new shell.** Hermit backs up your files, software list, and app settings to a drive, then moves everything back into the right places on a brand-new machine with one command.

> **Status: v0.1, files only.** Hermit backs up and restores your Documents, Downloads, Desktop, Pictures, Videos and Music, with a manifest and a dry-run. Software lists and app settings are planned, not built yet. See the [roadmap](#roadmap).

---

## The problem

Setting up a new computer is a mess. You copy Videos to Videos, Downloads to Downloads, Desktop to Desktop, then spend a weekend remembering which software you had installed and how you had it configured.

## The idea

Plug in your drive, run one command, and Hermit puts everything back where it belongs.

```bash
hermit backup /media/mydrive
hermit restore /media/mydrive --dry-run   # see what would happen first
hermit restore /media/mydrive
```

## Install

You need `bash` and `rsync` (Debian/Ubuntu: `sudo apt install rsync`).

```bash
git clone https://github.com/ParanormalRave/Hermit.git ~/.local/share/hermit
mkdir -p ~/.local/bin
ln -s ~/.local/share/hermit/hermit ~/.local/bin/hermit
```

Make sure `~/.local/bin` is in your `PATH`, then check it works:

```bash
hermit --version
```

## How it works

Hermit is built around a **manifest**, a file that records what was saved and where each thing belongs.

1. **Backup** checks the drive (it can really be written to, and has enough free space), copies your standard folders to it, and writes a manifest. In later versions it will also capture installed packages and app configs.
2. **Restore** reads the manifest, plans what to do, and puts the files back into the home folder of whoever runs it, so a new username is fine. It never overwrites a file that already exists. In later versions it will also reinstall your software from the saved list.

Hermit does **not** copy installed programs (planned for a later version). Programs are scattered across the system and can't be moved by copying folders. Instead it will save the *list* of what you had installed and reinstall it on the new machine.

More detail: [How it works](docs/HOW-IT-WORKS.md).

## Features

- [x] Files restored to their proper folders (Documents, Downloads, Videos, Desktop, etc.)
- [x] `--dry-run` mode, with nothing changed until you say so
- [x] Summary of what was restored, skipped, or failed, with clear exit codes
- [x] Safety checks: real write test, free-space check, warning for drives that lose permissions
- [x] Restore never overwrites and never writes outside your home folder
- [ ] Package list capture and reinstall (apt first)
- [ ] App settings and dotfiles (`~/.config`, `~/.local/share`)
- [ ] Username and path remapping inside config files (plain files already work, since paths are saved relative to your home)
- [ ] Optional encryption for sensitive files (SSH keys, `.env`, tokens)

## Platform support

| Platform | Status |
|---|---|
| Debian / Ubuntu | 🎯 First target (tests run on Ubuntu in CI) |
| Other Linux (Fedora, Arch) | 🕒 Developed on Fedora; package-manager adapters come later |
| macOS | 🕒 Later |
| Windows | ❓ Maybe via WSL |

## Roadmap

- [ ] **v0.1:** Files + manifest (backup and restore, dry-run)
- [ ] **v0.2:** Package list capture and reinstall (apt)
- [ ] **v0.3:** App configs and dotfiles
- [ ] **v0.4:** Username/path remapping
- [ ] **v0.5:** Encryption and safety checks
- [ ] **v1.0:** Stable release with docs and tests

## Project structure

```
hermit/
├── hermit              # main entry point (CLI)
├── lib/
│   ├── common.sh       # logging, colors, exit codes
│   ├── paths.sh        # path validation and mapping
│   ├── manifest.sh     # build and read the manifest, write meta.env
│   ├── restore.sh      # restore plan, dry run, apply
│   └── drive.sh        # drive checks: write test, free space, filesystem
├── tests/
│   ├── test_lib.sh     # unit tests
│   └── test_v01.sh     # end-to-end backup and restore test
├── docs/               # usage, how it works, exit codes, FAQ
├── assets/             # logo and art
└── .github/workflows/  # CI
```

## Things to know

- **Use a Linux drive (ext4).** FAT32, exFAT and NTFS drop Linux permissions and ownership. Hermit warns you when it detects one.
- **Your backup is an unencrypted copy of your files** and may contain secrets. Treat the drive like a password.
- **Always run `--dry-run` first** on a new machine.
- **Symlinks, and file names containing a tab or newline, are skipped** (with a warning).
- **Hermit must be installed on the new machine** to restore. Your files are plain copies, so you can also copy them out of `hermit-backup/files/` by hand.

## Documentation

- [Using Hermit](docs/USAGE.md)
- [How it works](docs/HOW-IT-WORKS.md)
- [Exit codes](docs/EXIT-CODES.md)
- [FAQ](docs/FAQ.md)

## Testing

The tests are plain bash and run in a temporary fake home, never touching your real files.

```bash
bash tests/test_lib.sh     # the building blocks
bash tests/test_v01.sh     # a full backup and restore, checked end to end
```

GitHub Actions runs ShellCheck and both test files on Ubuntu for every push.

## Getting help

Open an [issue](https://github.com/ParanormalRave/Hermit/issues) and include `hermit --version`, your distribution, the command you ran, and the full output.

## Contributing

Ideas, bug reports, and pull requests are welcome. For anything bigger than a small fix, please open an issue first so we can talk about it.

## License

[MIT](LICENSE)
