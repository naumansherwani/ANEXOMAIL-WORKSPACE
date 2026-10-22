#!/usr/bin/env bash
# ANEXOMAIL — R1a: aane wali mail ka pipe Bun -> Rust (founder "haan" mail path, 20 Oct 2026). SAFE: har qadam par wapas aane ka raasta.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-deliver-install.sh)
#
# Kya badalta hai: sirf Postfix `anexopipe` ki `argv` — Bun `deliver-to-supabase.ts` ki jagah Rust `/usr/local/bin/anexomail-deliver-rs`.
#   Postfix/Dovecot/OpenDKIM ki baqi config, Caddy, polar :3400, Rust engine :3200 (binary/restart) — kuch nahi chhuta.
#   Bun wali file disk par rehti hai (wapas jane ke liye ek line).
# Sandbox saboot: 18 unit tests; Bun vs Rust 6 asli-jaisi mails par: purane contract ki har key same, farq sirf jahan Bun GALAT tha —
#   attachment wali mail (multipart/mixed > alternative) ka text Bun mein KHALI aata tha, "=?UTF-8?…?=" subject/naam kachcha,
#   ISO-8859-1 mail ka text aur raw_sha256/raw_size kharab. Supabase 500 / band / env na ho => exit 75 (Postfix queue, mail nahi khoti).
# Qadam:
#   0. haal: anexopipe ki abhi ki argv, mail.env, vmail user, Rust crate.
#   1. src/bin/anexomail-deliver.rs (repo se) -> unit tests -> `cargo build --release --bin anexomail-deliver` (engine binary/restart ko haath nahi).
#   2. /usr/local/bin/anexomail-deliver-rs install -> vmail user ban kar 2 asli test (Postfix switch se PEHLE):
#        anjaan pata -> quarantine (E37), basic.test -> Basic ke inbox mein (subject "R1a Rust ✓" decode ho kar).
#   3. master.cf backup -> argv badlo -> `postfix check` -> reload -> sendmail se asli raasta (Postfix -> anexopipe -> Rust -> DB) 60s mein.
#      Kuch bhi fail => master.cf wapas + reload (Bun pipe phir se), saaf wajah.
set -uo pipefail
TARGET="${TARGET:-/opt/anexomail-rust}"; REPO="${REPO:-/opt/anexomail-web}"; MCF="${MCF:-/etc/postfix/master.cf}"
BIN_DST="${BIN_DST:-/usr/local/bin/anexomail-deliver-rs}"; MAILENV="${MAILENV:-/etc/anexomail/mail.env}"
STAMP="$(date +%s)"; LOG="/tmp/anexomail-deliver-build-$STAMP.log"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
command -v cargo >/dev/null || { [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"; }
q() { ( . /etc/anexomail/sync.env 2>/dev/null; psql "$WORKING_URL" -tAX -c "$1" 2>&1 ) | tr -d '\r' | head -5; }

echo "== 0) abhi"
CUR="$(grep -A1 -E '^anexopipe[[:space:]]' "$MCF" | tail -1 | sed 's/^[[:space:]]*//')"
echo "   anexopipe: $CUR"
[ -n "$CUR" ] || { echo "FAIL: master.cf mein anexopipe nahi mila — kuch nahi badla"; exit 2; }
[ -r "$MAILENV" ] || { echo "FAIL: $MAILENV nahi — kuch nahi badla"; exit 2; }
id vmail >/dev/null 2>&1 || { echo "FAIL: vmail user nahi — kuch nahi badla"; exit 2; }
[ -f "$TARGET/Cargo.toml" ] || { echo "FAIL: $TARGET nahi"; exit 2; }
[ -r /etc/anexomail/sync.env ] || { echo "FAIL: /etc/anexomail/sync.env nahi (DB check ke liye)"; exit 2; }
case "$CUR" in *"$BIN_DST"*) ALREADY=1; echo "   (anexopipe pehle se Rust par — sirf binary taaza + test)";; *) ALREADY=0;; esac

echo "== 1) Rust binary: repo -> src/bin -> tests -> build (engine ko haath nahi)"
git -C "$REPO" show origin/main:server/rust/deliver_bin.rs >"$T/deliver.rs" 2>/dev/null; [ -s "$T/deliver.rs" ] || { echo "FAIL: repo mein server/rust/deliver_bin.rs nahi — git fetch?"; exit 2; }
mkdir -p "$TARGET/src/bin"; [ -f "$TARGET/src/bin/anexomail-deliver.rs" ] && cp -p "$TARGET/src/bin/anexomail-deliver.rs" "$TARGET/src/bin/anexomail-deliver.rs.bak.$STAMP"
cp "$T/deliver.rs" "$TARGET/src/bin/anexomail-deliver.rs"
# #3 iMIP: calendar-reply reader (std-only) src/ mein; mig_mime/attach_core/inbound_attach pehle se wahin hain
for f in imip_core.rs; do git -C "$REPO" show "origin/main:server/rust/$f" >"$T/$f" 2>/dev/null; [ -s "$T/$f" ] || { echo "FAIL: repo mein server/rust/$f nahi"; exit 2; }; [ -f "$TARGET/src/$f" ] && cp -p "$TARGET/src/$f" "$TARGET/src/$f.bak.$STAMP"; cp "$T/$f" "$TARGET/src/$f"; done
undo_src() { if [ -f "$TARGET/src/bin/anexomail-deliver.rs.bak.$STAMP" ]; then cp -p "$TARGET/src/bin/anexomail-deliver.rs.bak.$STAMP" "$TARGET/src/bin/anexomail-deliver.rs"; else rm -f "$TARGET/src/bin/anexomail-deliver.rs"; fi; }
( cd "$TARGET" && nice -n 10 cargo test --bin anexomail-deliver >"$LOG" 2>&1 ) || { echo "!! unit tests FAIL — wapas, kuch nahi badla:"; grep -E "^error|panicked|FAILED|test result" "$LOG" | head -15; undo_src; exit 1; }
echo "   $(grep -E '^test result' "$LOG" | tail -1)"
( cd "$TARGET" && nice -n 10 cargo build --release --bin anexomail-deliver >>"$LOG" 2>&1 ) || { echo "!! build FAIL — wapas:"; grep -E "^error" -A6 "$LOG" | head -20; undo_src; exit 1; }
echo "   build OK ($(grep -E 'Finished' "$LOG" | tail -1 | sed 's/^ *//'))"

echo "== 2) install + vmail ban kar 2 asli test (Postfix abhi Bun par hi hai)"
[ -f "$BIN_DST" ] && cp -p "$BIN_DST" "$BIN_DST.bak.$STAMP"
install -m 0755 -o root -g root "$TARGET/target/release/anexomail-deliver" "$BIN_DST.new.$STAMP" && mv -f "$BIN_DST.new.$STAMP" "$BIN_DST"
U="zz-r1a-$STAMP@anexomail.com"; MIDQ="r1a-q-$STAMP@anexomail.com"; MIDB="r1a-b-$STAMP@anexomail.com"
printf 'From: R1a Test <r1a-test@anexomail.com>\r\nTo: %s\r\nSubject: R1a quarantine test\r\nMessage-ID: <%s>\r\n\r\nquarantine test\r\n' "$U" "$MIDQ" \
  | runuser -u vmail -- env ANEXOMAIL_MAIL_ENV="$MAILENV" "$BIN_DST" r1a-test@anexomail.com "$U" 2>"$T/q.err"; rq=$?
echo "   anjaan pata ($U): exit $rq — $(cut -c1-160 "$T/q.err")"
printf 'From: ANEXOMAIL R1a <r1a-test@anexomail.com>\r\nTo: basic.test@anexomail.com\r\nSubject: =?UTF-8?Q?R1a_Rust_delivery_=E2=9C=93?= %s\r\nMessage-ID: <%s>\r\nContent-Type: multipart/mixed; boundary="M"\r\n\r\n--M\r\nContent-Type: multipart/alternative; boundary=A\r\n\r\n--A\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nAgar ye text dikh raha hai to Rust pipe ne attachment wali mail ka body sahi padha.\r\n--A--\r\n\r\n--M\r\nContent-Type: text/plain; name="r1a.txt"\r\nContent-Disposition: attachment; filename="r1a.txt"\r\n\r\nok\r\n--M--\r\n' "$STAMP" "$MIDB" \
  | runuser -u vmail -- env ANEXOMAIL_MAIL_ENV="$MAILENV" "$BIN_DST" r1a-test@anexomail.com basic.test@anexomail.com 2>"$T/b.err"; rb=$?
echo "   basic.test: exit $rb — $(cut -c1-160 "$T/b.err")"
QOK="$(q "select count(*) from public.mail_quarantine where message_id = '$MIDQ'")"
BOK="$(q "select coalesce((select t.subject || ' | text=' || (length(coalesce(m.body_text,''))>20)::text from public.mail_messages m join public.mail_threads t on t.id = m.thread_id where m.message_id = '$MIDB' limit 1), 'NAHI')")"
echo "   DB: quarantine=$QOK   basic.test inbox: $BOK"
if [ "$rq" != 0 ] || [ "$rb" != 0 ] || [ "$QOK" != "1" ] || [ "${BOK#R1a Rust delivery ✓}" = "$BOK" ] || [ "${BOK%text=true}" = "$BOK" ]; then
  echo "!! Rust binary ka test fail — Postfix ko HAATH NAHI lagaya (mail Bun par hi chal rahi hai). Upar wali lines Claude ko bhejein."; exit 1
fi

if [ "$ALREADY" = 0 ]; then
  echo "== 3) Postfix anexopipe -> Rust (backup, postfix check, reload)"
  cp -p "$MCF" "$MCF.bak.$STAMP"
  python3 - "$MCF" "$BIN_DST" <<'PY' || { echo "!! master.cf badal nahi saka — kuch nahi badla"; exit 1; }
import re, sys
p, dst = sys.argv[1], sys.argv[2]
s = open(p).read()
m = re.search(r'(?m)^(anexopipe[ \t].*\n[ \t]+flags=\S+[ \t]+user=\S+[ \t]+argv=)(\S+(?:[ \t]+\S+\.ts)?)([ \t]+\$\{sender\}[ \t]+\$\{recipient\}.*)$', s)
if not m: print("   anexopipe argv ki shakal anjaan — ruk gaya"); sys.exit(1)
s = s[:m.start(2)] + dst + s[m.end(2):]
open(p, "w").write(s); print("   argv: " + m.group(2) + "  ->  " + dst)
PY
  restore_mcf() { cp -p "$MCF.bak.$STAMP" "$MCF"; postfix reload >/dev/null 2>&1; echo "   master.cf wapas (Bun pipe), postfix reload."; }
  if ! postfix check 2>"$T/pc.err"; then echo "!! postfix check FAIL:"; cat "$T/pc.err"; restore_mcf; exit 1; fi
  postfix reload >/dev/null 2>&1 || { echo "!! postfix reload FAIL"; restore_mcf; exit 1; }
  echo "   postconf: $(postconf -M anexopipe/unix 2>/dev/null | grep -o 'argv=[^ ]*')"
else
  restore_mcf() { echo "   (pehle se Rust par tha — master.cf nahi badla tha)"; }
fi

echo "== 4) asli raasta: sendmail -> Postfix -> anexopipe -> Rust -> DB (60s tak)"
MIDE="r1a-e2e-$STAMP@anexomail.com"
printf 'From: ANEXOMAIL R1a <r1a-test@anexomail.com>\nTo: basic.test@anexomail.com\nSubject: R1a end-to-end %s\nMessage-ID: <%s>\n\nPostfix -> Rust pipe -> database.\n' "$STAMP" "$MIDE" | /usr/sbin/sendmail -f r1a-test@anexomail.com basic.test@anexomail.com
E="0"; for i in $(seq 1 30); do sleep 2; E="$(q "select count(*) from public.mail_messages where message_id = '$MIDE'")"; [ "$E" = "1" ] && break; done
ML="$(grep -h "basic.test@anexomail.com" /var/log/mail.log 2>/dev/null | grep -E 'relay=anexopipe' | tail -1 | grep -oE 'status=[a-z]+.*' | cut -c1-140)"
echo "   DB mein: $E   mail.log: ${ML:-(line nahi mili)}"
if [ "$E" != "1" ]; then
  echo "!! end-to-end fail — wapas Bun par:"; restore_mcf
  echo "   queue: $(mailq 2>/dev/null | tail -1)"; exit 1
fi
echo "OK — aane wali mail ab Rust pipe se (anexopipe -> $BIN_DST). Basic inbox mein 2 test mail: 'R1a Rust delivery ✓ …' (attachment wali, text ke saath) aur 'R1a end-to-end …'."
echo "   wapas Bun par jane ke liye: cp $MCF.bak.$STAMP $MCF && postfix reload"
