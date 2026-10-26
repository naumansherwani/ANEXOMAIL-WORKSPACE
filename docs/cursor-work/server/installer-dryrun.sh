#!/usr/bin/env bash
# Founder ko deploy dene SE PEHLE (Claude chalata hai): installer ka patch-step repo main.rs par dry-run — proc clash pakadta hai.
#   bash docs/cursor-work/server/installer-dryrun.sh "trialx authx contx basx"
set -euo pipefail
cd "$(dirname "$0")/../../.."
MODS="${1:?modules likhein, jaise: \"authx contx basx\"}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
{ echo "import sys"; sed -n '/^patch_main() { python3 - /,/^PY$/p' docs/cursor-work/server/rust-engine-install.sh | sed '1d;$d'; } >"$T/p.py"
cp server/rust/main.rs "$T/main.rs"
python3 "$T/p.py" "$T/main.rs" "$MODS"
for m in $MODS; do for f in server/rust/${m}_core.rs; do grep -o '"[a-zA-Z0-9_-]*\.[a-zA-Z0-9._-]*"' "$f" | sort -u | while read -r p; do grep -lF "$p" server/rust/*.rs | grep -v "/${m}_" | sed "s#^#CLASH $p -> #" || true; done; done; done
echo "dryrun done"
