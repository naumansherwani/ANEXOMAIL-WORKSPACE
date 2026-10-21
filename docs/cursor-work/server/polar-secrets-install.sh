#!/usr/bin/env bash
# ============================================================================
# polar-secrets-install.sh — Polar ke DONO webhook endpoints ke signing secrets engine ko .env se dena (22 Oct 2026).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/polar-secrets-install.sh)
#
# KYUN: engine ka POLAR_ACCESS_TOKEN webhooks:read scope nahi rakhta => auto-sync 403 => sirf ek (env) secret.
# Polar har endpoint ka APNA secret banata hai => doosre endpoint ki asli deliveries "signature_mismatch" 401 =>
# Polar lagataar failures dekh kar endpoint AUTO-DISABLE kar deta hai. Fix: dono secrets .env mein (POLAR_WEBHOOK_SECRETS).
# Secrets chat mein paste NAHI hote: yahan chhupa kar (echo band) poochhe jaate hain, sirf .env mein jaate hain (600).
# Safety: .env backup; build/restart control-plane-install se (backup + rollback + proof); fail => .env wapas.
# ============================================================================
set -uo pipefail
ENG=/opt/polar-rust-payment; ENVF="$ENG/.env"; WEB="${WEB:-/opt/anexomail-web}"
STAMP="$(date +%Y%m%d-%H%M%S)"; BK="/root/anexomail-backups/polar-secrets-$STAMP"
say(){ printf '\n==> %s\n' "$*"; }
[ -f "$ENVF" ] || { echo "!!! $ENVF nahi mila"; exit 1; }
mkdir -p "$BK"; cp -a "$ENVF" "$BK/.env"; chmod 700 "$BK"; chmod 600 "$BK/.env"
restore(){ echo "!!! ROLLBACK: $1"; cp -a "$BK/.env" "$ENVF"; chmod 600 "$ENVF"; pm2 restart polar-rust-payment --update-env >/dev/null 2>&1; echo "    .env wapas. Backup: $BK"; exit 1; }

say "1/4 secrets (Polar dashboard -> Settings -> Webhooks -> har endpoint -> Signing secret / 'whsec_...')"
if grep -qE '^POLAR_WEBHOOK_SECRETS=.+' "$ENVF"; then
  echo "    POLAR_WEBHOOK_SECRETS pehle se .env mein hai — wahi rehne diya (badalna ho to .env se wo line hata kar dobara chalao)"
else
  ask(){ local v; printf '    %s: ' "$1" >&2; IFS= read -rs v </dev/tty; echo >&2; printf '%s' "$v" | tr -d ' "\r\n'"'"; }
  S1="$(ask 'polarpayments.anexomail.com endpoint ka secret')"
  S2="$(ask 'anexomail.com endpoint ka secret')"
  for s in "$S1" "$S2"; do
    case "$s" in whsec_*) ;; *) echo "!!! secret 'whsec_' se shuru nahi hota — Polar se poora secret copy karo"; exit 1;; esac
    [ "${#s}" -ge 20 ] || { echo "!!! secret bahut chhota"; exit 1; }
  done
  [ "$S1" != "$S2" ] || { echo "!!! dono secret ek jaise hain — har endpoint ka alag hota hai"; exit 1; }
  printf '\nPOLAR_WEBHOOK_SECRETS=%s,%s\n' "$S1" "$S2" >> "$ENVF"; chmod 600 "$ENVF"
  echo "    OK  dono secret .env mein (600), screen par nahi chhape"
fi

say "2/4 engine ka naya code + build + restart + proof (control-plane installer, rollback ke saath)"
git -C "$WEB" fetch -q origin main </dev/null 2>/dev/null || true
OUT="$(bash <(git -C "$WEB" show origin/main:docs/cursor-work/server/polar-control-plane-install.sh) 2>&1)"; RC=$?
echo "$OUT" | grep -E '^(==>|    (OK|FAIL)|!!!)' | sed 's/^/   /'
[ "$RC" = "0" ] || restore "engine installer fail (upar dekho)"

say "3/4 secrets ka saboot (/health)"
H="$(curl -fsS -m 10 http://127.0.0.1:3400/health 2>/dev/null || true)"
N="$(echo "$H" | grep -o '"webhook_secrets": *[0-9]*' | grep -o '[0-9]*$')"
echo "$H" | grep -q '"secrets_complete": *true' && echo "    OK   secrets_complete=true (webhook_secrets=$N)" || restore "secrets_complete true nahi (webhook_secrets=${N:-?})"

say "4/4 ab Polar dashboard mein (yeh aap haath se karenge)"
cat <<'TXT'
    a) Webhooks -> jo endpoint 'disabled' hai -> Enable karo.
    b) Har endpoint par 'Send test event' / purani failed delivery 'Redeliver' karo — HTTP 200 aana chahiye.
    c) Server par dekhne ke liye:  curl -s http://127.0.0.1:3400/metrics   (received barhna chahiye, rejects nahi)
TXT
echo; echo "==> TAYYAR. Backup: $BK   (rollback: cp $BK/.env $ENVF; pm2 restart polar-rust-payment --update-env)"
