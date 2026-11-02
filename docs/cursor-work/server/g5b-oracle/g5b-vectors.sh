#!/usr/bin/env bash
# Regenerate g5b-vectors.json with Go's own `note` package as the independent oracle. Needs Go (GOROOT src). Not run on the server.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; T="$(mktemp -d)"
GOROOT_DIR="${GOROOT:-/usr/local/go}"
mkdir -p "$T/note"; cp "$GOROOT_DIR/src/cmd/vendor/golang.org/x/mod/sumdb/note/note.go" "$T/note/"
cp "$HERE/main.go" "$T/"; printf 'module g5b\n\ngo 1.24\n' >"$T/go.mod"
(cd "$T" && "$GOROOT_DIR/bin/go" run . ) >"$HERE/g5b-vectors.json"
rm -rf "$T"; echo "wrote $HERE/g5b-vectors.json"
