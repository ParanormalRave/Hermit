# 🐚 Hermit

**Same you, new shell.** Hermit backs up your files, software list, and app settings to a drive, then moves everything back into the right places on a brand-new machine with one command.

> ⚠️ **Status: early development.** Hermit is being built in the open. The sections below describe what it is designed to do. Check the roadmap to see what actually works today.

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

## How it works

Hermit is built around a **manifest**, a file that records what was saved and where each thing belongs.

1. **Backup** scans your user folders, installed packages, and app configs, copies them to the drive, and writes a manifest.
2. **Restore** reads the manifest, maps paths to the new machine (even if the username changed), restores files to their original locations, then reinstalls your software from the saved list.

Hermit does **not** copy installed programs. Programs are scattered across the system and can't be moved by copying folders. Instead it saves the *list* of what you had installed and reinstalls it on the new machine.

## Planned features

- Files restored to their proper folders (Documents, Downloads, Videos, Desktop, etc.)
- Package list capture and reinstall (apt first)
- App settings and dotfiles (`~/.config`, `~/.local/share`)
- Username and path remapping (`/home/old` to `/home/new`)
- `--dry-run` mode, with nothing changed until you say so
- Summary report of what was restored, skipped, or failed
- Optional encryption for sensitive files (SSH keys, `.env`, tokens)

## Platform support

| Platform | Status |
|---|---|
| Debian / Ubuntu | 🎯 First target |
| Other Linux (Fedora, Arch) | 🕒 Later, via package-manager adapters |
| macOS | 🕒 Later |
| Windows | ❓ Maybe via WSL |

## Roadmap

- [ ] **v0.1:** Files + manifest (backup and restore, dry-run)
- [ ] **v0.2:** Package list capture and reinstall (apt)
- [ ] **v0.3:** App configs and dotfiles
- [ ] **v0.4:** Username/path remapping
- [ ] **v0.5:** Encryption and safety checks
- [ ] **v1.0:** Stable release with docs and tests

## Planned structure

```
hermit/
├── hermit            # main entry point (CLI)
├── lib/
│   ├── common.sh     # logging, helpers
│   ├── manifest.sh   # read/write the manifest
│   ├── paths.sh      # path mapping and remapping
│   └── pkg/          # one adapter per package manager
├── tests/            # Docker-based backup/restore tests
└── README.md
```

## Things to know

- **Use an ext4 drive** (or archive to a tarball). FAT32 and exFAT drop Linux permissions and ownership.
- **Your backup will contain secrets** (SSH keys, tokens, `.env` files). Treat the drive like a password.
- **Always run `--dry-run` first** on a new machine.

## Testing

Tests run in throwaway Ubuntu containers: back up a fake home, wipe it, restore, and diff the result.

## Contributing

Ideas, bug reports, and pull requests are welcome once the core is in place.

## License

MIT
