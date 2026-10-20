#!/usr/bin/env bash
# ANEXOMAIL — SQL ab SERVER se (Supabase editor mein paste ki zaroorat nahi). Founder hukm 20 Oct 2026 21:28.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)
#   (bina naam: kal+aaj ki sab SQL E37..E50 tarteeb se, phir CHECK_E42_E47 + CHECK_E48. Ya naam do, bina .sql ke: ... sql-run.sh) E48_outgoing_attachments CHECK_E48)
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
if [ $# -eq 0 ]; then
  set --
  for f in E37_mail_ingest_no_stray_org E38_thread_message_count_truth E39_security_truth E40_billing_price_truth E41_family_real_buyer \
           E42_device_hash_hmac E43_passkey_recovery_codes E44_account_export E45_integrity_purge E46_integrity_notices_appeal \
           E47_device_revoke_real_sessions E48_outgoing_attachments E49_attach_ceiling_18mb E50_inbound_attachments CHECK_E42_E47 CHECK_E48 CHECK_E50; do set -- "$@" "$f"; done
fi
T="$(mktemp)"; trap 'rm -f "$T"' EXIT
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
      if [ "${FORCE:-0}" != 1 ] && grep -q "^$n	$sha	" "$LEDGER"; then echo "== $n: pehle se chali hui (sha $sha) — skip (FORCE=1 se dobara)"; continue; fi
      echo "== $n chal rahi hai (sha $sha)"
      out="$(psql "$WORKING_URL" -X -v ON_ERROR_STOP=1 -q -f "$T" 2>&1)"; prc=$?
      echo "$out" | grep -v '^NOTICE\|^psql:.*NOTICE' | tail -12
      if [ $prc -ne 0 ]; then echo "!! $n FAIL (exit $prc) — yahin ruk gaya, baqi nahi chali. Upar ka output Claude ko bhejein."; exit 1; fi
      printf '%s\t%s\t%s\n' "$n" "$sha" "$(date -u +%FT%TZ)" >>"$LEDGER"
      echo "   OK — ledger mein likh diya"
      ;;
  esac
done
[ $rc -eq 0 ] && echo "DONE: sab theek." || echo "DONE: lekin upar FAIL hai."
exit $rc
