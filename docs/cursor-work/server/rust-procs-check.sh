#!/usr/bin/env bash
# ANEXOMAIL — READ-ONLY: founder pages ke kitne Rust procs sach mein Rust source mein hain (Rule 22 audit, 17 Oct 2026).
# Kuch badalta nahi, koi proc CALL nahi hota (mutating proc bina auth ke chal sakta hai — isliye sirf source mein naam dhoondhte hain).
# Chalana:  bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-procs-check.sh)
set +e
R=/opt/anexomail-rust
LIST=$(git -C /opt/anexomail-web show origin/main:docs/cursor-work/founder/founder-procs.txt 2>/dev/null)
if [ -z "$LIST" ]; then echo "founder-procs.txt origin/main par nahi mili (pehle git fetch)"; exit 0; fi
if [ ! -d "$R/src" ]; then echo "$R/src nahi mila"; exit 0; fi
echo "== rust source: $(find "$R/src" -name '*.rs' | wc -l) files, $(cat "$R"/src/*.rs "$R"/src/**/*.rs 2>/dev/null | wc -l) lines =="
echo "== routing ka tareeqa (ek namoona) =="
grep -rn --include=*.rs -E '"/rpc|/rpc/\{|rpc/:' "$R/src" 2>/dev/null | head -4 | cut -c1-170
found=0; miss=0; missing=""
while IFS= read -r proc; do
  case "$proc" in ''|\#*) continue;; esac
  if grep -rqF --include=*.rs "\"$proc\"" "$R/src" 2>/dev/null; then found=$((found+1)); else miss=$((miss+1)); missing="$missing$proc"$'\n'; fi
done <<< "$LIST"
echo
echo "== NATIJA: Rust source mein mile = $found · NAHI mile = $miss =="
echo "-- jo Rust source mein NAHI mile (yani founder page ki yeh call abhi Bun fallback par chalti hai):"
printf '%s' "$missing" | sed 's/^/  /' | head -230
echo
echo "== done (read-only) =="
