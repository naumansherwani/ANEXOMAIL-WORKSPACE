#!/usr/bin/env bash
# ANEXOMAIL — READ-ONLY facts (17 Oct 2026). Kuch badalta nahi, koi secret print nahi.
# Kis liye: (1) TECH-MAP.md ke "LIVE" dawe asli server se saabit karna (Rule 5/20),
#           (2) 8i/8j ke liye Dovecot/Postfix ka sach (passdb/userdb/mail store/submission),
#           (3) R0 ke liye Rust toolchain + asli resolved versions (Cargo.lock).
# Chalana:  bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/facts-tech-map.sh)
set +e
hr() { printf '\n== %s ==\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

hr "versions"
have caddy && caddy version 2>&1 | head -1 || echo "caddy: not found"
have bun && echo "bun $(bun --version 2>&1 | head -1)" || echo "bun: not found"
have node && echo "node $(node --version 2>&1 | head -1)" || echo "node: not found"
have rustc && rustc --version 2>&1 | head -1 || echo "rustc: not found"
have cargo && cargo --version 2>&1 | head -1 || echo "cargo: not found"
have postconf && echo "postfix $(postconf -h mail_version 2>&1 | head -1)" || echo "postfix: not found"
have dovecot && echo "dovecot $(dovecot --version 2>&1 | head -1)" || echo "dovecot: not found"
have opendkim && opendkim -V 2>&1 | head -1 || echo "opendkim: not found"
if [ -r /etc/anexomail/sync.env ]; then
  ( . /etc/anexomail/sync.env 2>/dev/null; have psql && psql "$WORKING_URL" -Atc "select version()" 2>&1 | cut -c1-90 | head -1 )
else
  echo "postgres: /etc/anexomail/sync.env nahi mila"
fi

hr "rust engine (/opt/anexomail-rust)"
R=/opt/anexomail-rust
if [ -f "$R/Cargo.toml" ]; then
  grep -E '^(edition|opt-level|version) *=' "$R/Cargo.toml" | head -4
  grep -E '^(axum|tokio|wtransport|tower-http|reqwest) *=' "$R/Cargo.toml"
  if [ -f "$R/Cargo.lock" ]; then
    echo "-- Cargo.lock (asli resolved):"
    for c in axum tokio wtransport quinn hyper reqwest rustls; do
      v=$(grep -A1 -E "^name = \"$c\"$" "$R/Cargo.lock" | grep -E '^version' | head -2 | sed 's/version = //' | tr '\n' ' ')
      [ -n "$v" ] && echo "  $c $v"
    done
  else
    echo "Cargo.lock nahi mili"
  fi
  [ -f "$R/src/main.rs" ] && echo "src/main.rs lines: $(wc -l < "$R/src/main.rs")"
else
  echo "$R/Cargo.toml nahi mila"
fi

hr "rust health + WebTransport (UDP 3443)"
curl -s --max-time 5 http://127.0.0.1:3200/rpc/health | cut -c1-400; echo
(ss -lunp 2>/dev/null | grep -E ':3443\b') || echo "udp 3443: koi nahi sun raha (WebTransport OFF ya cert nahi)"

hr "pm2 (naam, status, restarts)"
if have pm2; then
  pm2 jlist 2>/dev/null | python3 -c '
import json,sys
try:
    for p in json.load(sys.stdin):
        e=p.get("pm2_env",{})
        print("%-22s %-8s restarts=%s" % (p.get("name"), e.get("status"), e.get("restart_time")))
except Exception as ex:
    print("pm2 parse fail:", ex)
'
else
  echo "pm2: not found"
fi

hr "dovecot (passdb/userdb/mail store)"
if have doveconf; then
  doveconf -n 2>/dev/null | grep -E '^(protocols|mail_location|mail_home|auth_mechanisms|disable_plaintext_auth|ssl|ssl_min_protocol|first_valid_uid)\b|^passdb|^userdb|^  (driver|args|default_fields|override_fields)\b|^service (imap-login|auth|lmtp)' | grep -viE 'pass(word)? *=|secret' | head -40
else
  echo "doveconf: not found"
fi

hr "postfix (submission, sasl, virtual, tls)"
if have postconf; then
  postconf -n 2>/dev/null | grep -E '^(smtpd_sasl_type|smtpd_sasl_path|smtpd_sasl_auth_enable|virtual_(mailbox_domains|mailbox_base|mailbox_maps|alias_maps|transport)|mydestination|smtpd_tls_security_level|smtp_tls_security_level|smtpd_tls_protocols|smtp_tls_protocols|smtpd_tls_cert_file|smtpd_milters|milter_default_action|inet_interfaces|message_size_limit|mailbox_size_limit)\b' | cut -c1-160
  echo "-- master.cf services:"
  postconf -M 2>/dev/null | grep -E '^(smtp|submission|smtps|submissions)/' | cut -c1-120
else
  echo "postconf: not found"
fi

hr "listening ports (mail)"
ss -ltnp 2>/dev/null | grep -E ':(25|143|465|587|993|995|110)\b' | awk '{print $4, $6}' | sed 's/users:((//; s/))//' | head -12

hr "mail DNS (security standards)"
if have dig; then
  for n in _mta-sts _smtp._tls _dmarc; do
    printf '%s: ' "$n"; dig +short TXT "$n.anexomail.com" 2>/dev/null | head -1; echo
  done
  printf 'TLSA 25: '; dig +short TLSA _25._tcp.mail.anexomail.com 2>/dev/null | head -1; echo
else
  echo "dig: not found"
fi

hr "mail store"
for d in /var/mail/vhosts /var/vmail /home/vmail; do
  [ -d "$d" ] && { echo "$d:"; ls "$d" 2>/dev/null | head -8; du -sh "$d" 2>/dev/null | cut -f1; }
done

echo
echo "== done (read-only) =="
