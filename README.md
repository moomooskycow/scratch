# scratch

a daily scratch-file management cli tool that auto-generates or reuses your notes for each day. elegantly maintains a consistent scratch log system.

## features

- always opens or creates a scratch file for the current date in `~/documents/rubberducks`.
- if today's file doesn't exist, clones the last known scratch file, updates the heading, then opens it for you to brain-dump.
- opens in your `$NEOVIM` (or `$EDITOR`) by default.

## installation

1. ensure `go` is installed and `$GOPATH/bin` is on your path.
2. clone this repo.
3. run `go install`.

(optional) you can symlink it to `/usr/local/bin/scratch`:

```bash
sudo ln -s $HOME/go/bin/scratch /usr/local/bin/scratch
```

## usage

- simply type `scratch` in your terminal
- your scratchpads are in `~/documents/rubberducks/YYYYMMDD-scratch.md`

## development

Run the repo-owned gate before merging:

```bash
make check
```

CI uses the same command in the `go check` job. The separate Leyline workflow
only vendors shared docs; it does not replace the Go gate.
