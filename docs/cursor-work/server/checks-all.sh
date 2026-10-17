#!/usr/bin/env bash
# ANEXOMAIL — SAB READ-ONLY CHECKS EK COMMAND MEIN (17 Oct 2026, founder ke liye ek paste).
# Kuch badalta nahi, koi secret/password/hash print nahi. Natija /tmp/anexomail-checks-<waqt>.txt mein bhi jaata hai.
# Chalana:  git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/checks-all.sh)
# Aakhir mein "PASTE FROM HERE" ke neeche ka hissa (ya poori file: cat <file>) Claude ko paste karein.
set +e
OUT=/tmp/anexomail-checks-$(date +%Y%m%d-%H%M%S).txt
W=${W:-/opt/anexomail-web}   # (sirf test ke liye badla ja sakta hai)
show() { git -C "$W" show "origin/main:$1" 2>/dev/null; }
run() { # run <script> <max lines>
  local f="$1" n="${2:-90}"
  printf '\n\n########## %s ##########\n' "$f"
  local body; body=$(show "docs/cursor-work/server/$f")
  if [ -z "$body" ]; then echo "(script origin/main par nahi mila — pehle git fetch)"; return; fi
  bash <(printf '%s\n' "$body") 2>&1 | cut -c1-230 | head -"$n"
}
# live Brain ka SRC (jahan routes/ + index.ts hain) — KABHI backups/dist/node_modules nahi. Pehle /opt/anexomail/src (founder ka system map), phir pm2 se, phir filtered find.
find_brain_src() {
  local c cands=() base="${BRAIN:-/opt/anexomail}"
  [ -n "${BRAIN_SRC:-}" ] && cands+=("$BRAIN_SRC")
  cands+=("$base/src" "$base/server" "$base")
  while IFS= read -r c; do [ -n "$c" ] && cands+=("$c"); done < <(pm2 jlist 2>/dev/null | python3 -c 'import json,sys,os
try:
    for p in json.load(sys.stdin):
        if p.get("name")=="anexomail-leo":
            e=p["pm2_env"]; x=e.get("pm_exec_path") or ""; w=e.get("pm_cwd") or ""
            for d in (os.path.dirname(x), w, w+"/src", w+"/server"): print(d)
except Exception: pass' 2>/dev/null)
  while IFS= read -r c; do cands+=("$(dirname "$c")"); done < <(find "$base" -maxdepth 4 -type d -name routes -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*backup*' -not -path '*/dist/*' -not -path '*/build/*' 2>/dev/null)
  for c in "${cands[@]}"; do
    case "$c" in *backup*|*/node_modules/*|*/.git/*|*/dist|*/dist/*|*/build|*/build/*) continue ;; esac
    if [ -d "$c/routes" ] && [ -f "$c/index.ts" ]; then echo "$c"; return 0; fi
  done
  return 1
}
{
echo "ANEXOMAIL checks — $(date '+%Y-%m-%d %H:%M:%S %Z') — host $(hostname) — web HEAD $(git -C "$W" rev-parse --short HEAD 2>/dev/null) / origin $(git -C "$W" rev-parse --short origin/main 2>/dev/null)"

printf '\n\n########## 0. repo == server (backend) ##########\n'
RS=${RS:-/opt/anexomail-rust/src}
echo "-- Rust: live source files"; ls -l $RS 2>/dev/null | awk '{print $5, $9}' | head -20
LIVE=$(sha256sum $RS/main.rs 2>/dev/null | cut -c1-16); REPO=$(show server/rust/main.rs | sha256sum | cut -c1-16)
echo "Rust main.rs  live=${LIVE:-nahi-mila}  repo=$REPO  $( [ -z "$LIVE" ] && echo LIVE-NAHI-MILA || { [ "$LIVE" = "$REPO" ] && echo SAME || echo DIFFER; } )   live lines=$(wc -l < $RS/main.rs 2>/dev/null || echo 0) repo lines=$(show server/rust/main.rs | wc -l)"
echo "-- Brain routes (live vs repo): same / differ / live-only / repo-only"
BR=$(find_brain_src)/routes; [ -d "$BR" ] || BR=""; echo "brain routes dir: ${BR:-nahi mila}"
if [ -n "$BR" ]; then
  tmp=$(mktemp)
  git -C "$W" ls-tree --name-only origin/main server/routes/ 2>/dev/null | sed 's#server/routes/##' | sort > $tmp.repo
  ls "$BR" 2>/dev/null | grep -E '\.ts$' | sort > $tmp.live
  same=0; differ=0
  for f in $(comm -12 $tmp.live $tmp.repo); do
    a=$(sha256sum "$BR/$f" | cut -c1-16); b=$(show "server/routes/$f" | sha256sum | cut -c1-16)
    if [ "$a" = "$b" ]; then same=$((same+1)); else differ=$((differ+1)); echo "  DIFFER $f live=$a repo=$b"; fi
  done
  echo "same=$same differ=$differ"
  echo "live-only (repo mein nahi): $(comm -23 $tmp.live $tmp.repo | tr '\n' ' ')"
  echo "repo-only (live mein nahi): $(comm -13 $tmp.live $tmp.repo | tr '\n' ' ')"
  rm -f $tmp $tmp.repo $tmp.live
fi
echo "-- pm2"; pm2 jlist 2>/dev/null | python3 -c 'import sys,json
try:
  for p in json.load(sys.stdin): print(p["name"], p["pm2_env"]["status"], "restarts="+str(p["pm2_env"].get("restart_time")), "interp="+str(p["pm2_env"].get("exec_interpreter")))
except Exception as e: print("pm2 jlist parse nahi hua", e)' 2>/dev/null | head -12

run rust-procs-check.sh 70
run test-accounts-check.sh 60
run workspace-api-check.sh 60
run switch-journey-check.sh 50
run crm-tenant-check.sh 50
run org-authz-check.sh 60
run calendar-invite-check.sh 60
} > "$OUT" 2>&1
echo
echo "================= PASTE FROM HERE ================="
cat "$OUT"
echo "================= PASTE UP TO HERE ================="
echo "(file: $OUT — $(wc -l < "$OUT") lines, $(wc -c < "$OUT") bytes)"
