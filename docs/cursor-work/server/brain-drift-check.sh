#!/usr/bin/env bash
# ANEXOMAIL — READ-ONLY: repo ke server/routes + server/lib/*.ts aur live Brain (Bun :3100, /opt/anexomail/src) mein kaun si file ALAG hai.
# Kuch badalta nahi. Alag file = repo ka Bun code live nahi gaya (Bun sirf brain-*-install.sh se jata hai, pull.sh se nahi).
#   bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-drift-check.sh)
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"; SRC="${BRAIN_SRC:-/opt/anexomail/src}"
git -C "$REPO" fetch -q origin main 2>/dev/null
same=0; diff=0; miss=0
for p in $(git -C "$REPO" ls-tree -r --name-only origin/main server/routes server/lib | grep '\.ts$' | grep -v '\.test\.ts$'); do
  rel="${p#server/}"; live="$SRC/$rel"
  if [ ! -f "$live" ]; then echo "MISSING live: $rel"; miss=$((miss+1)); continue; fi
  a="$(git -C "$REPO" show "origin/main:$p" | sha256sum | cut -c1-12)"; b="$(sha256sum "$live" | cut -c1-12)"
  if [ "$a" = "$b" ]; then same=$((same+1)); else echo "DIFF   $rel (repo $a, live $b)"; diff=$((diff+1)); fi
done
echo "same=$same diff=$diff missing-live=$miss"
