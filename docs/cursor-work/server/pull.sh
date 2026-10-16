#!/usr/bin/env bash
# ANEXOMAIL server sync — founder ki EK command (AGENTS.md Rule 1 + Rule 18, 17 Oct 2026).
#
#   bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh)
#
# Kyun: server ki git tree installers se "dirty" hai, isliye `git pull --rebase` refuse karta hai.
# Yeh script tree ko chhere bina:
#   1. dirty files ki list dikhata hai (server ka sach, Rule 15),
#   2. memory/qaide taza karta hai: AGENTS.md, docs/, .cursor/rules/ (jo file badli uska backup),
#   3. DEPLOY-MANIFEST.txt ki code files sha-guard se lagata hai (badli ho to build; fail ho to purani wapas),
#   4. HAMESHA `pm2 restart anexomail-web --update-env && pm2 save`, phir health check.
# Sirf web (/opt/anexomail-web). Rust (anexomail-rust) aur Brain (anexomail-leo) ke deploy alag block hote hain.
# polar-rust-payment ko yeh script kabhi nahi chhuta.
set -u -o pipefail

W="${W:-/opt/anexomail-web}"
APP="${APP:-anexomail-web}"
BK="${BK:-/root/i9/sync-$(date +%Y%m%d-%H%M%S)}"
MANIFEST="docs/cursor-work/server/DEPLOY-MANIFEST.txt"
MEMORY="docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md"

cd "$W" || { echo "FAIL: $W nahi mila"; exit 1; }
git fetch -q origin main </dev/null || { echo "FAIL: git fetch nahi chala (network?)"; exit 1; }
echo "origin/main = $(git rev-parse --short origin/main) · $(git log -1 --format=%s origin/main | cut -c1-80)"

echo "--- server tree: badli hui files (git status --short, pehli 40)"
git status --short </dev/null | head -40
echo "---"

mkdir -p "$BK"

# 1) memory + qaide (docs only; build ki zaroorat nahi)
docs_changed=0
while IFS= read -r -d '' f; do
  tmp="$(mktemp)"
  git show "origin/main:$f" > "$tmp" 2>/dev/null </dev/null || { rm -f "$tmp"; continue; }
  if [ ! -f "$f" ] || ! cmp -s "$tmp" "$f"; then
    if [ -f "$f" ]; then mkdir -p "$BK/$(dirname "$f")"; cp -p "$f" "$BK/$f"; fi
    mkdir -p "$(dirname "$f")"
    cp "$tmp" "$f"
    docs_changed=$((docs_changed + 1))
  fi
  rm -f "$tmp"
done < <(git ls-tree -r -z --name-only origin/main -- AGENTS.md docs .cursor/rules </dev/null)
echo "memory/docs: $docs_changed file(s) taza kiye"

# 2) code (manifest): sha-guarded, build, restore-on-fail
changed=()
had_backup=()
fail=0
while read -r p want _; do
  case "${p:-}" in ''|'#'*) continue ;; esac
  tmp="$(mktemp)"
  if ! git show "origin/main:$p" > "$tmp" 2>/dev/null </dev/null; then
    echo "MISSING repo mein: $p"; fail=1; rm -f "$tmp"; continue
  fi
  got="$(sha256sum "$tmp" | cut -c1-16)"
  if [ "$got" != "${want:-}" ]; then
    echo "SHA MISMATCH $p (manifest $want, repo $got) - chhoda"; fail=1; rm -f "$tmp"; continue
  fi
  if [ -f "$p" ] && cmp -s "$tmp" "$p"; then
    echo "same   $p"; rm -f "$tmp"; continue
  fi
  if [ -f "$p" ]; then mkdir -p "$BK/$(dirname "$p")"; cp -p "$p" "$BK/$p"; had_backup+=("$p"); fi
  mkdir -p "$(dirname "$p")"
  cp "$tmp" "$p"; rm -f "$tmp"
  changed+=("$p"); echo "wrote  $p"
done < <(git show "origin/main:$MANIFEST" 2>/dev/null </dev/null)

build="skipped (code nahi badla)"
if [ "${#changed[@]}" -gt 0 ]; then
  if bun run build:bun > "$BK/build.log" 2>&1 </dev/null; then
    build="OK"
  else
    echo "--- build log (aakhri 15 lines)"; tail -15 "$BK/build.log"
    for p in "${changed[@]}"; do
      if [ -f "$BK/$p" ]; then cp -p "$BK/$p" "$p"; else rm -f "$p"; fi
    done
    bun run build:bun > "$BK/build-restore.log" 2>&1 </dev/null || true
    build="FAIL - purani files wapas rakh di"; fail=1
  fi
fi

# 3) pm2 restart HAMESHA (founder ka qaida)
pm2 restart "$APP" --update-env >/dev/null 2>&1 </dev/null
pm2 save >/dev/null 2>&1 </dev/null
sleep "${SETTLE:-4}"
h="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:3000/health" 2>/dev/null)"
d="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:3000/app/domains" 2>/dev/null)"

echo "================ RESULT"
echo "memory file : $W/$MEMORY"
echo "build       : $build"
echo "web /health : ${h:-?}   /app/domains : ${d:-?}"
echo "backup      : $BK"
if [ "$fail" -eq 0 ] && [ "${h:-}" = "200" ]; then
  echo "OK - memory taza, server taza. Browser mein Ctrl+Shift+R."
else
  echo "KUCH GALAT (upar dekho) - yeh poora output claude ko paste karo."
  exit 1
fi
