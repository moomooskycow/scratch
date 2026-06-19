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

## ci

The host-agnostic repository gate is:

```bash
./scripts/ci.sh
```

It checks `gofmt`, runs `go vet`, executes race-enabled tests with a
`coverage.out` profile, and builds the CLI. GitHub Actions delegates to this
same script. To install local hooks:

```bash
git config core.hooksPath .githooks
```
