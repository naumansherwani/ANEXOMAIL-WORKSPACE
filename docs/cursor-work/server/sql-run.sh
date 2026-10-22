#!/usr/bin/env bash
# ANEXOMAIL — SQL ab SERVER se (Supabase editor mein paste ki zaroorat nahi). Founder hukm 20 Oct 2026 21:28.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)
#   (bina naam = AUTO: repo ki saari nayi E-series (E37+) jo ledger mein naam se nahi, tarteeb se, phir unke CHECK_E<n>. Ya naam do, bina .sql ke: ... sql-run.sh) E48_outgoing_attachments CHECK_E48)
#   E28/E36 is mein nahi: unhein password chahiye (`bizpro-login-fix.sh` alag). E2..E34 purani, pehle chal chuki hain — naam de kar hi chalengi.
# Kya karta hai:
#   - /etc/anexomail/sync.env ka WORKING_URL (wahi jo baqi check scripts use karte hain), psql ON_ERROR_STOP
#   - file origin/main se aati hai; sha256 ledger `/var/lib/anexomail/sql-applied.tsv` mein likhta hai — wahi file wahi sha dobara NAHI chalti (FORCE=1 se chalegi)
#   - CHECK_*.sql sirf padhti hain: har baar chalti hain, ledger mein nahi likhi jatin; ok=false aaye to exit 1
#   - fail => wahin ruk jata hai, baqi files nahi chalti. Password/URL kabhi print nahi hota.
set -uo pipefail
REPO="${REPO:-/opt/anexomail-web}"
ENV_FILE="${ENV_FILE:-/etc/anexomail/sync.env}"
LEDGER="${LEDGER:-/var/lib/anexomail/sql-applied.tsv}"
SRC_DIR="${SRC_DIR:-}"   # sirf test ke liye: git ki jagah folder se padho
[ -r "$ENV_FILE" ] || { echo "FAIL: $ENV_FILE nahi mila"; exit 2; }
. "$ENV_FILE" 2>/dev/null
[ -n "${WORKING_URL:-}" ] || { echo "FAIL: WORKING_URL khali hai ($ENV_FILE)"; exit 2; }
command -v psql >/dev/null || { echo "FAIL: psql nahi mila"; exit 2; }
mkdir -p "$(dirname "$LEDGER")" 2>/dev/null; touch "$LEDGER" 2>/dev/null || { echo "FAIL: $LEDGER likh nahi sakta"; exit 2; }
[ -n "$SRC_DIR" ] || git -C "$REPO" fetch -q origin main 2>/dev/null
APPLIED=""
T="$(mktemp)"; trap 'rm -f "$T"' EXIT
AUTO=0
if [ $# -eq 0 ]; then
  # AUTO (founder 22 Oct 2026): bina naam = repo ki SAB E-series (E37 se aage; E28/E36 seeds nahi) jo ledger mein nahi (ya fix hui), number ki tarteeb se.
  # Pehle chali hui (wahi sha, ya sirf khali pehli line ka farq) dobara nahi; file ka matlab badla (fix) to dobara chalti hai.
  # Phir jo is baar nayi chali unke CHECK_E<n> (agar hai).
  AUTO=1
  if [ -n "$SRC_DIR" ]; then LIST="$(ls "$SRC_DIR" 2>/dev/null)"; else LIST="$(git -C "$REPO" ls-tree --name-only origin/main docs/cursor-work/sql/ 2>/dev/null | sed 's#.*/##')"; fi
  set --
  for f in $(echo "$LIST" | sed -n 's/^\(E\([0-9][0-9]*\)_[A-Za-z0-9_]*\)\.sql$/\2 \1/p' | sort -n | awk '$1>=37 && $1!=28 && $1!=36 {print $2}'); do
    # pending = naam ledger mein nahi, YA file ka matlab badla (sha alag; sirf khali pehli line ka farq pending nahi) — fix ki hui SQL (Rule 8) bhi isi se chalti hai
    if [ -n "$SRC_DIR" ]; then cat "$SRC_DIR/$f.sql" >"$T" 2>/dev/null; else git -C "$REPO" show "origin/main:docs/cursor-work/sql/$f.sql" >"$T" 2>/dev/null; fi
    [ -s "$T" ] || continue
    h1="$(sha256sum "$T" | cut -c1-16)"; h2=""; [ -z "$(head -n1 "$T")" ] && h2="$(tail -n +2 "$T" | sha256sum | cut -c1-16)"
    grep -q "^$f	$h1	" "$LEDGER" && continue
    [ -n "$h2" ] && grep -q "^$f	$h2	" "$LEDGER" && continue
    set -- "$@" "$f"
  done
  [ $# -gt 0 ] || { echo "AUTO: koi nayi SQL nahi — sab kuch ledger mein pehle se chali hui hai."; exit 0; }
  echo "AUTO: nayi SQL tarteeb se: $*"
  NEWSQL="$*"
fi
rc=0
for n in "$@"; do
  n="${n%.sql}"
  case "$n" in *[!A-Za-z0-9_]*|"") echo "FAIL: ghalat naam '$n'"; exit 2 ;; esac
  if [ -n "$SRC_DIR" ]; then cat "$SRC_DIR/$n.sql" >"$T" 2>/dev/null; else git -C "$REPO" show "origin/main:docs/cursor-work/sql/$n.sql" >"$T" 2>/dev/null; fi
  [ -s "$T" ] || { echo "FAIL: $n.sql repo mein nahi mili"; exit 2; }
  sha="$(sha256sum "$T" | cut -c1-16)"
  case "$n" in
    CHECK_*)
      echo "== $n (sirf padhta hai)"
      out="$(psql "$WORKING_URL" -X -v ON_ERROR_STOP=1 -At -F ' | ' -f "$T" 2>&1)"; prc=$?
      echo "$out" | grep -v '^NOTICE' | sed 's/ | t$/ | OK/; s/ | f$/ | **FAIL**/'
      [ $prc -eq 0 ] || { echo "!! $n chal nahi saki"; rc=1; }
      echo "$out" | grep -q ' | f$' && { echo "!! $n mein FAIL row hai"; rc=1; }
      ;;
    *)
      alt=""; [ -z "$(head -n1 "$T")" ] && alt="$(tail -n +2 "$T" | sha256sum | cut -c1-16)"   # pehli khali line Rule 42 ne jodi — purani sha bhi pehchano
      if [ "${FORCE:-0}" != 1 ] && { grep -q "^$n	$sha	" "$LEDGER" || { [ -n "$alt" ] && grep -q "^$n	$alt	" "$LEDGER"; }; }; then echo "== $n: pehle se chali hui (sha $sha) — skip (FORCE=1 se dobara)"; continue; fi
      echo "== $n chal rahi hai (sha $sha)"
      out="$(psql "$WORKING_URL" -X -v ON_ERROR_STOP=1 -q -f "$T" 2>&1)"; prc=$?
      echo "$out" | grep -v '^NOTICE\|^psql:.*NOTICE' | tail -12
      if [ $prc -ne 0 ]; then echo "!! $n FAIL (exit $prc) — yahin ruk gaya, baqi nahi chali. Upar ka output Claude ko bhejein."; exit 1; fi
      printf '%s\t%s\t%s\n' "$n" "$sha" "$(date -u +%FT%TZ)" >>"$LEDGER"
      APPLIED="$APPLIED $n"
      echo "   OK — ledger mein likh diya"
      ;;
  esac
done
# RULE 43 safety-net (founder 22 Oct 2026): jab bhi koi SQL is baar chali, E65 sweep (RLS ON, search_path pin, definer grants) dobara chalti hai — purani SQL
# functions bina pin ke bana deti hain (22 Oct: E37..E52 dobara chali to CHECK_E65 functions par FAIL aaya). Ledger se nahi, hamesha; idempotent.
if [ $rc -eq 0 ] && [ -n "$APPLIED" ]; then
  case " $APPLIED " in *" E65_rls_and_advisor_sweep "*) ;; *)
    if [ -n "$SRC_DIR" ]; then cat "$SRC_DIR/E65_rls_and_advisor_sweep.sql" >"$T" 2>/dev/null; else git -C "$REPO" show "origin/main:docs/cursor-work/sql/E65_rls_and_advisor_sweep.sql" >"$T" 2>/dev/null; fi
    if [ -s "$T" ]; then
      echo "== E65 sweep (RLS + advisor) — is baar ki SQL ke baad dobara"
      out="$(psql "$WORKING_URL" -X -v ON_ERROR_STOP=1 -q -f "$T" 2>&1)"; prc=$?
      echo "$out" | grep -v '^NOTICE\|^psql:.*NOTICE' | tail -6
      [ $prc -eq 0 ] || { echo "!! E65 sweep FAIL"; rc=1; }
      if [ -n "$SRC_DIR" ]; then cat "$SRC_DIR/CHECK_E65.sql" >"$T"; else git -C "$REPO" show "origin/main:docs/cursor-work/sql/CHECK_E65.sql" >"$T"; fi
      echo "== CHECK_E65 (sirf padhta hai)"
      out="$(psql "$WORKING_URL" -X -v ON_ERROR_STOP=1 -At -F ' | ' -f "$T" 2>&1)"
      echo "$out" | grep -v '^NOTICE' | sed 's/ | t$/ | OK/; s/ | f$/ | **FAIL**/'
      echo "$out" | grep -q ' | f$' && { echo "!! CHECK_E65 mein FAIL row hai"; rc=1; }
    fi ;;
  esac
fi
if [ "$AUTO" = 1 ] && [ $rc -eq 0 ]; then
  for n in $NEWSQL; do
    num="${n%%_*}"
    if [ -n "$SRC_DIR" ]; then [ -s "$SRC_DIR/CHECK_$num.sql" ] && exec_check=1 || exec_check=0; else git -C "$REPO" cat-file -e "origin/main:docs/cursor-work/sql/CHECK_$num.sql" 2>/dev/null && exec_check=1 || exec_check=0; fi
    [ "$exec_check" = 1 ] || continue
    if [ -n "$SRC_DIR" ]; then cat "$SRC_DIR/CHECK_$num.sql" >"$T"; else git -C "$REPO" show "origin/main:docs/cursor-work/sql/CHECK_$num.sql" >"$T"; fi
    echo "== CHECK_$num (sirf padhta hai)"
    out="$(psql "$WORKING_URL" -X -v ON_ERROR_STOP=1 -At -F ' | ' -f "$T" 2>&1)"; prc=$?
    echo "$out" | grep -v '^NOTICE' | sed 's/ | t$/ | OK/; s/ | f$/ | **FAIL**/'
    [ $prc -eq 0 ] || { echo "!! CHECK_$num chal nahi saki"; rc=1; }
    echo "$out" | grep -q ' | f$' && { echo "!! CHECK_$num mein FAIL row hai"; rc=1; }
  done
fi
[ $rc -eq 0 ] && echo "DONE: sab theek." || echo "DONE: lekin upar FAIL hai."
exit $rc
