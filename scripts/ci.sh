#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

go_files="$(git ls-files '*.go')"
if [ -n "$go_files" ]; then
  unformatted="$(gofmt -l $go_files)"
  if [ -n "$unformatted" ]; then
    printf 'gofmt required:\n%s\n' "$unformatted" >&2
    exit 1
  fi
fi

go vet ./...
go test -race -covermode=atomic -coverprofile=coverage.out ./...
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
go build -o "$build_dir/scratch" .
