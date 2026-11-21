#!/usr/bin/env bash
# ANEXOMAIL: create a REAL Business account on the awam side (Supabase), password TYPED ON THE SERVER. His 21 Nov 2026 10:41: "yeh real hai", method = the repo's real-signup path (E28 seed = server/routes/auth.ts /signup + /identity/claim + POST /organisations + entitlement), saved in admin-desk/codes/REAL-ACCOUNT-METHOD.md.
# Runs docs/cursor-work/sql/E28_seed_buyer_test_account.sql unchanged. This is AWAM data, made through awam's own seed; the Desk never reads it directly. Asks: handle (becomes handle@anexomail.com), name, company, domain, plan, then the password twice (no echo).
set -uo pipefail
G=/opt/anexomail-web; [ -r /etc/anexomail/sync.env ] || { echo "FAIL: /etc/anexomail/sync.env missing"; exit 2; }; . /etc/anexomail/sync.env
[ -t 0 ] || { echo "FAIL: run in your terminal"; exit 2; }
read -rp "handle (mail name before @anexomail.com): " H; read -rp "person name: " NM; read -rp "company name: " ORG; read -rp "company domain (e.g. example.com): " DOM
read -rp "plan [business|business_pro]: " PL
case "$PL" in business|business_pro) ;; *) echo "FAIL: plan name"; exit 3;; esac
[[ "$H" =~ ^[a-z0-9._-]{3,40}$ ]] || { echo "FAIL: handle must be a-z 0-9 . _ - (3 to 40)"; exit 3; }
read -rs -p "password (12+ chars): " P1; echo; read -rs -p "again: " P2; echo
[ "$P1" = "$P2" ] && [ "${#P1}" -ge 12 ] || { echo "FAIL: passwords differ or shorter than 12"; exit 3; }
git -C "$G" fetch -q origin main; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git -C "$G" show origin/main:docs/cursor-work/sql/E28_seed_buyer_test_account.sql >"$T/E28.sql" || { echo "FAIL: E28 not found"; exit 2; }
PGPASSWORD_UNUSED=1 psql "$WORKING_URL" -X -v ON_ERROR_STOP=1 -q -v handle="$H" -v nm="$NM" -v org="$ORG" -v domain="$DOM" -v plan="$PL" -v pw="$P1" -f "$T/E28.sql" 2>&1 | tail -12; RC=${PIPESTATUS[0]}; unset P1 P2
[ "$RC" = 0 ] && echo "done: $H@anexomail.com ($PL). Password was typed here only; it is not stored anywhere in plain text." || echo "FAILED: nothing was created (one transaction)"
