#!/usr/bin/env bash
# ANEXOMAIL — G38b: AANE WALI mail ke attachments ke bytes Storage Box par (restore-on-fail).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-inbound-attach-install.sh)
#
# PEHLE (is tarteeb se): SQL E48 + E50 (`sql-run.sh` dono chala deta hai) -> Rust `MODULES="attach"` -> R1a pipe (`rust-deliver-install.sh`, pehle se laga hai).
#
# Kya karta hai (sirf yeh):
#   1. repo se `deliver_bin.rs` + `inbound_attach.rs` + `mig_mime.rs` + `attach_core.rs` -> Rust crate ki src/ (purani files ki backup)
#   2. unit tests -> `cargo build --release --bin anexomail-deliver` (engine :3200 ka binary/restart NAHI chhuta)
#   3. /usr/local/bin/anexomail-deliver-rs naya binary (purana backup), spool folder /var/spool/anexomail-inbound (vmail likh sake)
#   4. systemd timer `anexomail-inbound-attach.timer` (har minute, root): spool -> clamd -> Storage Box -> DB
#   5. asli saboot: pipe ke raaste ek test mail (hello.txt attachment ke saath) basic.test ko -> 1-2 minute mein DB mein sha256 + file disk par
# Postfix config, Caddy, polar :3400, Brain, web ko haath nahi lagata. Fail => purani files/binary wapas, timer band.
set -uo pipefail
TARGET="${TARGET:-/opt/anexomail-rust}"; REPO="${REPO:-/opt/anexomail-web}"; MCF="${MCF:-/etc/postfix/master.cf}"
BIN_DST="${BIN_DST:-/usr/local/bin/anexomail-deliver-rs}"; MAILENV="${MAILENV:-/etc/anexomail/mail.env}"
SYNCENV="${SYNCENV:-/etc/anexomail/sync.env}"; UNITDIR="${UNITDIR:-/etc/systemd/system}"
SPOOL="${SPOOL:-/var/spool/anexomail-inbound}"; ROOT="${ATTACH_DIR:-/mnt/anexomail-box/attachments}"
STAMP="$(date +%s)"; LOG="/tmp/anexomail-inbound-build-$STAMP.log"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
command -v cargo >/dev/null || { [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"; }
q() { ( . "$SYNCENV" 2>/dev/null; psql "$WORKING_URL" -tAX -c "$1" 2>&1 ) | tr -d '\r' | head -5; }

echo "== 0) tayyari"
[ -f "$TARGET/Cargo.toml" ] || { echo "FAIL: $TARGET nahi"; exit 2; }
[ -f "$TARGET/src/attach_glue.rs" ] || { echo "FAIL: Rust 'attach' module abhi nahi laga — pehle: MODULES=\"attach\" bash <(…rust-engine-install.sh)"; exit 2; }
[ -r "$MAILENV" ] || { echo "FAIL: $MAILENV nahi"; exit 2; }
id vmail >/dev/null 2>&1 || { echo "FAIL: vmail user nahi"; exit 2; }
CUR="$(grep -A1 -E '^anexopipe[[:space:]]' "$MCF" | tail -1 | sed 's/^[[:space:]]*//')"
case "$CUR" in *"$BIN_DST"*) echo "   anexopipe pehle se Rust par: OK";; *) echo "FAIL: anexopipe abhi Rust par nahi ($CUR) — pehle rust-deliver-install.sh"; exit 2;; esac
[ -r "$SYNCENV" ] || { echo "FAIL: $SYNCENV nahi"; exit 2; }
[ "$(q "select to_regprocedure('public.mail_attach_inbound_register(uuid,uuid,int,text,text,bigint,text,text,jsonb)') is not null")" = "t" ] || { echo "FAIL: SQL E50 abhi nahi chali — bash <(…sql-run.sh)"; exit 2; }
if command -v findmnt >/dev/null && findmnt -n /mnt/anexomail-box >/dev/null 2>&1 && [ -d "$ROOT" ]; then echo "   Storage Box: OK ($ROOT)"; else echo "FAIL: Storage Box mount / $ROOT nahi — bash attach-check.sh"; exit 2; fi
git -C "$REPO" fetch -q origin main 2>/dev/null
for f in server/rust/deliver_bin.rs server/rust/inbound_attach.rs server/rust/mig_mime.rs server/rust/attach_core.rs \
         docs/cursor-work/server/inbound-attach/anexomail-inbound-attach.service docs/cursor-work/server/inbound-attach/anexomail-inbound-attach.timer; do
  git -C "$REPO" show "origin/main:$f" >"$T/$(basename "$f")" 2>/dev/null; [ -s "$T/$(basename "$f")" ] || { echo "FAIL: repo se $f nahi mila — git fetch?"; exit 2; }
done

echo "== 1) sources (backup) + tests"
mkdir -p "$TARGET/src/bin"
for pair in "deliver_bin.rs:bin/anexomail-deliver.rs" "inbound_attach.rs:inbound_attach.rs" "mig_mime.rs:mig_mime.rs" "attach_core.rs:attach_core.rs"; do
  src="${pair%%:*}"; dst="$TARGET/src/${pair##*:}"
  [ -f "$dst" ] && cp -p "$dst" "$dst.bak.$STAMP"
  cp "$T/$src" "$dst"
done
undo_src() {
  for pair in "bin/anexomail-deliver.rs" "inbound_attach.rs" "mig_mime.rs" "attach_core.rs"; do
    d="$TARGET/src/$pair"; if [ -f "$d.bak.$STAMP" ]; then cp -p "$d.bak.$STAMP" "$d"; else rm -f "$d"; fi
  done
}
( cd "$TARGET" && nice -n 10 cargo test --bin anexomail-deliver >"$LOG" 2>&1 ) || { echo "!! unit tests FAIL — sources wapas, kuch nahi badla:"; grep -E "^error|panicked|FAILED|test result" "$LOG" | head -15; undo_src; exit 1; }
echo "   $(grep -E '^test result' "$LOG" | tail -1)"
( cd "$TARGET" && nice -n 10 cargo build --release --bin anexomail-deliver >>"$LOG" 2>&1 ) || { echo "!! build FAIL — sources wapas:"; grep -E "^error" -A6 "$LOG" | head -20; undo_src; exit 1; }
echo "   build OK ($(grep -E 'Finished' "$LOG" | tail -1 | sed 's/^ *//'))"

echo "== 2) binary + spool + timer"
[ -f "$BIN_DST" ] && cp -p "$BIN_DST" "$BIN_DST.bak.$STAMP"
install -m 0755 -o root -g root "$TARGET/target/release/anexomail-deliver" "$BIN_DST.new.$STAMP" && mv -f "$BIN_DST.new.$STAMP" "$BIN_DST"
install -d -m 0750 -o vmail -g vmail "$SPOOL"
cp "$T/anexomail-inbound-attach.service" "$UNITDIR/anexomail-inbound-attach.service"
cp "$T/anexomail-inbound-attach.timer" "$UNITDIR/anexomail-inbound-attach.timer"
systemctl daemon-reload
undo_all() {
  systemctl disable --now anexomail-inbound-attach.timer >/dev/null 2>&1
  [ -f "$BIN_DST.bak.$STAMP" ] && cp -p "$BIN_DST.bak.$STAMP" "$BIN_DST"
  undo_src
  echo "   purana binary + sources wapas, timer band. Postfix pipe purane (R1a) binary par chalta rahega."
}
echo "   binary: $BIN_DST   spool: $SPOOL"

echo "== 3) asli saboot: pipe -> spool -> worker -> DB -> Storage Box"
MID="g38b-$STAMP@anexomail.com"; NOW="$(date -u +%FT%TZ)"
printf 'From: ANEXOMAIL G38b <g38b-test@anexomail.com>\r\nTo: basic.test@anexomail.com\r\nSubject: G38b inbound attachment test %s\r\nMessage-ID: <%s>\r\nContent-Type: multipart/mixed; boundary="M"\r\n\r\n--M\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nYeh test mail hai: neeche hello.txt attachment download hona chahiye (virus-checked).\r\n--M\r\nContent-Type: text/plain; name="hello.txt"\r\nContent-Disposition: attachment; filename="hello.txt"\r\nContent-Transfer-Encoding: base64\r\n\r\nSGVsbG8gZnJvbSBBTkVYT01BSUwgRzM4YiAoJU5PVyUpCg==\r\n--M--\r\n' "$STAMP" "$MID" \
  | runuser -u vmail -- env ANEXOMAIL_MAIL_ENV="$MAILENV" "$BIN_DST" g38b-test@anexomail.com basic.test@anexomail.com 2>"$T/p.err"; rp=$?
echo "   pipe: exit $rp — $(tr '\n' ' ' <"$T/p.err" | cut -c1-260)"
NS="$(ls "$SPOOL" 2>/dev/null | grep -c '\.eml$')"
echo "   spool mein mails: $NS"
if [ "$rp" != 0 ] || [ "$NS" -lt 1 ]; then echo "!! pipe/spool saboot fail — wapas."; undo_all; exit 1; fi
WOUT="$(env ANEXOMAIL_MAIL_ENV="$MAILENV" "$BIN_DST" --spool-run 2>&1)"; wr=$?
echo "   worker: exit $wr — $(echo "$WOUT" | tr '\n' ' ' | cut -c1-300)"
ROW="$(q "select coalesce(a.sha256,'-') || ' | ' || coalesce(a.disk_path,'-') || ' | ' || coalesce(a.scan->>'clamd','-') from public.mail_attachments a join public.mail_messages m on m.id = a.message_id where m.message_id = '$MID' and a.filename = 'hello.txt' limit 1")"
echo "   DB: $ROW"
REL="$(echo "$ROW" | awk -F' [|] ' '{print $2}')"
if [ "$wr" != 0 ] || [ "$REL" = "-" ] || [ -z "$REL" ] || [ ! -f "$ROOT/$REL" ]; then
  echo "!! saboot fail (worker exit $wr, file: ${REL:-?}) — upar ki lines Claude ko bhejein. Wapas:"; undo_all; exit 1
fi
SHA="$(sha256sum "$ROOT/$REL" | cut -c1-64)"
[ "$SHA" = "$(echo "$ROW" | awk -F' [|] ' '{print $1}')" ] || { echo "!! disk file ka sha256 DB se alag — wapas"; undo_all; exit 1; }
systemctl enable --now anexomail-inbound-attach.timer >/dev/null 2>&1
echo "   timer: $(systemctl is-active anexomail-inbound-attach.timer) · agla chalna: $(systemctl list-timers anexomail-inbound-attach.timer --no-legend 2>/dev/null | awk '{print $1" "$2" "$3}')"
echo "OK — aane wali mail ke attachments ab Storage Box par (spool -> clamd -> org-dedup). Basic inbox mein 'G38b inbound attachment test …': hello.txt download hota hai."
echo "   scan: $(echo "$ROW" | awk -F' [|] ' '{print $3}')  (clean = clamd ne dekha; unavailable = clamd band, bytes phir bhi rakhe, 'scanned:false' sach likha)"
echo "   wapas lene ke liye: cp $BIN_DST.bak.$STAMP $BIN_DST && systemctl disable --now anexomail-inbound-attach.timer"
