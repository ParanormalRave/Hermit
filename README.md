# Hermit

Save a user's stuff to a drive with a record of where everything belongs, then
put it all back on a new machine with one command.

## The problem

Setting up a new computer is painful. Users copy Videos to Videos, Downloads to
Downloads, Desktop to Desktop by hand, then spend days remembering what software
they had and how it was configured.

## The solution

Hermit is a bash CLI:

- `hermit backup <drive>` copies the user's folders to the drive and writes a
  MANIFEST (a record of what was saved and where it belongs).
- `hermit restore <drive>` reads the manifest and puts everything back in the
  right places on a new machine.
- It never overwrites silently, and it has a `--dry-run` mode.

Hermit does **not** copy installed programs (that can't work). Later versions
will save a package LIST and reinstall it. That is **not** part of v0.1.

## Requirements

Debian/Ubuntu Linux, bash 5, rsync.

## Usage

```sh
hermit backup <drive-path>
hermit restore <drive-path> [--dry-run]
```

## What gets backed up (v0.1)

Only these folders under `$HOME`, and only if they exist: `Documents`,
`Downloads`, `Desktop`, `Pictures`, `Videos`, `Music`.

## License

Not specified yet.
