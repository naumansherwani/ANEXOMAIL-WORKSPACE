#!/usr/bin/env bash
# ANEXOMAIL — server ka git "143 commits behind" + sau files "modified/untracked" saaf karna, BINA kuch tode (20 Oct 2026).
#   DEKHNA (default, kuch nahi badalta):
#     git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/server-git-sync.sh)
#   LAGANA (sirf jab DEKHNA ne "SAB SAME" kaha ho):
#     git -C /opt/anexomail-web fetch -q origin main && APPLY=1 bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/server-git-sync.sh)
#
# Kyun: pull.sh files ko manifest se seedha lagata hai (sha-guard), git HEAD ko nahi badhata — is liye git ko lagta hai sab "badla"
# aur 143 commit peeche. Code server par repo jaisa hi hai (pull.sh: same=459). Lekin is ganday status mein (1) asli farq chhup jata
# hai, (2) `.env` (secrets) untracked pada tha — koi `git add -A` karta to secrets GitHub par chale jate.
# Kya karta hai: har badli/untracked file ko origin/main se milata hai. Jo farq ho sakte hain wo sirf do: `src/routeTree.gen.ts`
# (build khud likhta hai) aur `bun.lock` (server ka apna install). Koi aur file alag => RUKTA hai, list dikhata hai, kuch nahi badalta.
# APPLY=1: poora backup (tar) -> do allowed files ki copy -> `git reset --hard origin/main` -> wo do files wapas.
# Untracked jo repo mein nahi (.env, __pycache__, purane notes) — reset unhein CHHOTA bhi nahi. Koi build/restart nahi (code wahi hai).
set -uo pipefail
R="${R:-/opt/anexomail-web}"; STAMP="$(date +%s)"; BK="${BK:-/root/i9/gitsync-$STAMP.tgz}"
cd "$R" || { echo "FAIL: $R nahi"; exit 2; }
git fetch -q origin main || { echo "FAIL: git fetch"; exit 2; }
ALLOW='^(src/routeTree\.gen\.ts|bun\.lock)$'
echo "== 1) haal: HEAD $(git rev-parse --short HEAD) | origin/main $(git rev-parse --short origin/main) | peeche: $(git rev-list --count HEAD..origin/main) commit"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git status --porcelain --untracked-files=all | sed -E 's/^(..) //' >"$T/all"
echo "   badli/untracked files: $(wc -l <"$T/all")"
: >"$T/differ"; : >"$T/keep"; same=0; local_only=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  f="${f#\"}"; f="${f%\"}"
  if git cat-file -e "origin/main:$f" 2>/dev/null; then
    if git show "origin/main:$f" | cmp -s - "$f"; then same=$((same+1))
    elif [[ "$f" =~ $ALLOW ]]; then echo "$f" >>"$T/keep"
    else echo "$f" >>"$T/differ"; fi
  else
    local_only=$((local_only+1))
  fi
done <"$T/all"
echo "   repo jaisi (same): $same | allowed farq: $(wc -l <"$T/keep") ($(tr '\n' ' ' <"$T/keep")) | sirf server par (reset chhoota nahi): $local_only"
if [ -s "$T/differ" ]; then
  echo "!! YE files repo se ALAG hain — kuch nahi badla. Claude ko yeh list bhejein:"; sed 's/^/     /' "$T/differ" | head -40; exit 1
fi
echo "   SAB SAME (sirf allowed farq)."
if [ "${APPLY:-0}" != "1" ]; then echo "== DEKHNA mukammal. Lagane ke liye APPLY=1 wali command chalayen."; exit 0; fi

echo "== 2) backup: $BK"
mkdir -p "$(dirname "$BK")"
tar czf "$BK" --exclude=node_modules --exclude=.output --exclude=dist -C "$R" . 2>/dev/null || { echo "FAIL: backup nahi bana — kuch nahi badla"; exit 2; }
echo "   $(du -h "$BK" | cut -f1)"
while IFS= read -r f; do [ -n "$f" ] && mkdir -p "$T/keepf/$(dirname "$f")" && cp -p "$f" "$T/keepf/$f"; done <"$T/keep"
echo "== 3) git reset --hard origin/main (untracked .env wagaira ko haath nahi)"
git reset -q --hard origin/main || { echo "FAIL: reset — backup se wapas: tar xzf $BK -C $R"; exit 1; }
while IFS= read -r f; do [ -n "$f" ] && cp -p "$T/keepf/$f" "$f"; done <"$T/keep"
echo "== 4) natija"
echo "   HEAD $(git rev-parse --short HEAD) | peeche: $(git rev-list --count HEAD..origin/main) | badli: $(git status --porcelain | grep -vc '^??') | .env ignored: $(git check-ignore -q .env && echo haan || echo NAHI)"
git status --short | head -10 | sed 's/^/   /'
curl -s -o /dev/null -w "   web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health
echo "OK — server ka git ab repo ke barabar. Code nahi badla (restart ki zaroorat nahi). Wapas: tar xzf $BK -C $R"
