#!/usr/bin/env bash
# ANEXOMAIL — READ-ONLY facts (v2, 17 Oct 2026). Kuch badalta nahi, koi secret print nahi.
# Kis liye: (1) TECH-MAP.md ke "LIVE" dawe asli server se saabit karna (Rule 5/20),
#           (2) 8i/8j ke liye Dovecot/Postfix ka sach (passdb/userdb/mail store/anexopipe/submission),
#           (3) R0 ke liye Rust toolchain + asli resolved versions (Cargo.lock),
#           (4) "Node ka kya kaam hai" ka saboot: har pm2 process ka interpreter + script.
# v2 mein theek kiya: master.cf (postconf -M ka format), Dovecot 2.4 ki settings, pm2 interpreter,
#           mail queue/24h counts, mail store ki gintee, Rust panic count (sirf ginti, content nahi).
# Chalana:  bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/facts-tech-map.sh)
set +e
hr() { printf '\n== %s ==\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
# secret chhapne se bachao: in lafzon wali lines kabhi nahi
nosecret() { grep -viE 'pass(word)?([^a-z]|$)|secret|token|api[_-]?key|private|salt|credential'; }

hr "versions"
have caddy && echo "caddy $(caddy version 2>&1 | head -1 | cut -d' ' -f1)" || echo "caddy: not found"
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

hr "server (disk / memory / load)"
df -h / 2>/dev/null | tail -1 | awk '{print "disk /: used " $3 " of " $2 " (" $5 ")"}'
free -h 2>/dev/null | awk '/^Mem:/{print "memory: used " $3 " of " $2}'
uptime 2>/dev/null | sed 's/^ *//'

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

hr "pm2 (naam, status, restarts, INTERPRETER, script) — Node kahan chalta hai uska saboot"
if have pm2; then
  pm2 jlist 2>/dev/null | python3 -c '
import json,sys,os
try:
    for p in json.load(sys.stdin):
        e=p.get("pm2_env",{})
        interp=e.get("exec_interpreter") or "-"
        path=e.get("pm_exec_path") or "-"
        cwd=e.get("pm_cwd") or "-"
        print("%-22s %-8s restarts=%-4s interp=%-6s %s  (cwd %s)" % (p.get("name"), e.get("status"), e.get("restart_time"), interp, path, cwd))
except Exception as ex:
    print("pm2 parse fail:", ex)
'
  echo "-- Rust engine ke panic (sirf ginti; log ka matn nahi):"
  for f in /root/.pm2/logs/anexomail-rust-error.log /root/.pm2/logs/anexomail-rust-out.log; do
    [ -f "$f" ] && echo "  $(basename "$f"): panicked=$(tail -n 5000 "$f" | grep -c 'panicked') lines(last 5000)=$(tail -n 5000 "$f" | wc -l)"
  done
else
  echo "pm2: not found"
fi

hr "dovecot (2.4 ki settings; secret lines chhupi hui)"
if have doveconf; then
  doveconf -n 2>/dev/null | nosecret | head -90
else
  echo "doveconf: not found"
fi

hr "postfix (non-default settings; secret lines chhupi hui)"
if have postconf; then
  postconf -n 2>/dev/null | nosecret | grep -E '^(smtpd_sasl|virtual_|mydestination|smtpd_tls|smtp_tls|tls_|smtpd_milters|non_smtpd_milters|milter_|inet_interfaces|message_size_limit|mailbox_size_limit|smtpd_(recipient|relay|client|helo|sender)_restrictions|smtpd_data_restrictions|recipient_delimiter|home_mailbox|mailbox_command|transport_maps|relay|always_bcc|bounce_|maximal_queue_lifetime|smtpd_forbid)' | cut -c1-170
  echo "-- master.cf (service type private unpriv chroot wakeup maxproc command):"
  postconf -M 2>/dev/null | grep -E '^(smtp|submission|smtps|submissions|anexopipe|lmtp|pickup)[[:space:]]' | cut -c1-160
  echo "-- master.cf overrides (-o) jo submission/smtps par lagi hain:"
  postconf -P 2>/dev/null | grep -E '^(submission|smtps|submissions|smtp)/' | nosecret | cut -c1-160
  echo "-- anexopipe ka command (sirf raasta/argv):"
  grep -A3 -E '^anexopipe' /etc/postfix/master.cf 2>/dev/null | cut -c1-200
else
  echo "postconf: not found"
fi

hr "mail queue + pichle 24 ghante (UTC aaj ki taareekh)"
if have postqueue; then
  postqueue -p 2>/dev/null | tail -1
fi
ML=/var/log/mail.log
if [ -r "$ML" ]; then
  today="$(date -u +%F)"
  echo "mail.log (aaj $today): sent=$(grep "^$today" "$ML" | grep -c 'status=sent') deferred=$(grep "^$today" "$ML" | grep -c 'status=deferred') bounced=$(grep "^$today" "$ML" | grep -c 'status=bounced') tls_fail=$(grep "^$today" "$ML" | grep -ciE 'TLS (handshake|library problem)|SSL_accept error|certificate verification failed')"
else
  echo "mail.log: padh nahi sakte ($ML)"
fi

hr "listening ports (mail)"
ss -ltnp 2>/dev/null | grep -E ':(25|143|465|587|993|995|110)\b' | awk '{print $4, $6}' | sed 's/users:((//; s/))//' | head -12

hr "mail DNS (security standards)"
if have dig; then
  for n in _mta-sts _smtp._tls _dmarc; do
    printf '%s: ' "$n"; dig +short TXT "$n.anexomail.com" 2>/dev/null | head -1; echo
  done
  printf 'TLSA 25: '; dig +short TLSA _25._tcp.mail.anexomail.com 2>/dev/null | head -1; echo
  printf 'mta-sts host A: '; dig +short A mta-sts.anexomail.com 2>/dev/null | head -1; echo
  printf 'CAA: '; dig +short CAA anexomail.com 2>/dev/null | head -3 | tr '\n' ' '; echo
else
  echo "dig: not found"
fi

hr "mail store (IMAP ka asli maal kahan hai)"
for d in /var/mail/vhosts /var/vmail /home/vmail; do
  [ -d "$d" ] && {
    echo "$d: size=$(du -sh "$d" 2>/dev/null | cut -f1) files=$(find "$d" -type f 2>/dev/null | wc -l) dirs=$(find "$d" -type d 2>/dev/null | wc -l)"
    find "$d" -maxdepth 2 -mindepth 1 -type d 2>/dev/null | head -6
  }
done
have doveadm && echo "doveadm users (ginti): $(doveadm user '*' 2>/dev/null | wc -l)"

echo
echo "== done (read-only) =="
