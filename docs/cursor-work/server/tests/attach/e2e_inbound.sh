#!/usr/bin/env bash
# G38b e2e: asli `anexomail-deliver` binary (deliver + --spool-run) + asli Postgres (E48+E50) + mock Supabase (:4010) + mock clamd (:3311).
# Pehle chalayen: reset.sh (db e48), E50 SQL, stub_ingest.sql; mockpg.py + mockclamd.py chalu; BIN=<deliver binary>.
set -u
BIN="${BIN:?BIN=path/to/anexomail-deliver}"; D="$(cd "$(dirname "$0")" && pwd)"; W="${W:-$(mktemp -d)}"
export SUPABASE_URL=http://127.0.0.1:4010 SUPABASE_SERVICE_ROLE_KEY=svc CLAMD_ADDR=127.0.0.1:3311 ATTACH_DIR="$W/root" ATTACH_MOUNT=none ANEXOMAIL_INBOUND_SPOOL="$W/spool" ANEXOMAIL_MAIL_ENV=/nonexistent
mkdir -p "$W/root" "$W/spool"
PSQL="psql -h /var/run/postgresql -U postgres -d e48 -At -c"
pass=0; fail=0
t() { if [ "$2" = "1" ]; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1  :: ${3:-}"; fail=$((fail+1)); fi; }
python3 - "$W" <<'PY'
import sys, base64, os
w = sys.argv[1]
eicar = b"X5O!P%@AP[4\\PZX54(P^)7CC)7}$" + b"EICAR-STANDARD-ANTIVIRUS-TEST-FILE!" + b"$H+H*"
pdf = b"%PDF-1.4\n" + os.urandom(3000)
def part(name, mime, data):
    b = base64.encodebytes(data).decode().replace("\n", "\r\n")
    return f'--M\r\nContent-Type: {mime}; name="{name}"\r\nContent-Disposition: attachment; filename="{name}"\r\nContent-Transfer-Encoding: base64\r\n\r\n{b}\r\n'
def mail(parts, subj):
    return (f"From: Sara <sara@example.com>\r\nTo: basic.test@anexomail.com\r\nSubject: {subj}\r\nMessage-ID: <{subj.replace(' ','-')}@example.com>\r\nContent-Type: multipart/mixed; boundary=\"M\"\r\n\r\n"
            "--M\r\nContent-Type: text/plain\r\n\r\nhello\r\n" + "".join(parts) + "--M--\r\n").encode()
open(f"{w}/pdf.bin", "wb").write(pdf)
open(f"{w}/m1.eml", "wb").write(mail([part("quote.pdf", "application/pdf", pdf), part("same.txt", "text/plain", b"one"), part("same.txt", "text/plain", b"two"), part("eicar.txt", "text/plain", eicar)], "m1 attachments"))
open(f"{w}/m2.eml", "wb").write(mail([part("copy-of-quote.pdf", "application/pdf", pdf)], "m2 same pdf"))
open(f"{w}/m3.eml", "wb").write(b"From: a@example.com\r\nTo: basic.test@anexomail.com\r\nSubject: plain\r\n\r\nno attachments\r\n")
PY
PDFSHA=$(sha256sum "$W/pdf.bin" | cut -d' ' -f1)

# 1) deliver: mail DB mein, attachments wali mail ki copy spool mein; bina attachments wali ki nahi
"$BIN" sara@example.com basic.test@anexomail.com <"$W/m1.eml" 2>"$W/d1.err"; rc1=$?
t "deliver m1 exit 0" $([ $rc1 = 0 ] && echo 1 || echo 0) "$(cat $W/d1.err)"
"$BIN" sara@example.com basic.test@anexomail.com <"$W/m3.eml" 2>"$W/d3.err"; rc3=$?
t "deliver plain mail exit 0, nothing spooled" $([ $rc3 = 0 ] && [ "$(ls $W/spool | grep -c eml)" = 1 ] && echo 1 || echo 0) "$(ls $W/spool)"
"$BIN" sara@example.com nobody@anexomail.com <"$W/m1.eml" 2>"$W/dq.err"; rcq=$?
t "quarantined mail spools nothing" $([ $rcq = 0 ] && [ "$(ls $W/spool | grep -c eml)" = 1 ] && echo 1 || echo 0) "$(ls $W/spool)"
t "spool file private 0640" $([ "$(stat -c %a $W/spool/*.eml)" = 640 ] && echo 1 || echo 0)

# 2) Storage Box mount nahi => kuch nahi chhoota, exit 2, spool wahin
ATTACH_MOUNT=/tmp "$BIN" --spool-run >"$W/s0.out" 2>"$W/s0.err"; rcs=$?
t "no mount => exit 2, spool kept, nothing written" $([ $rcs = 2 ] && [ "$(ls $W/spool | grep -c eml)" = 1 ] && [ "$(find $W/root -type f | wc -l)" = 0 ] && echo 1 || echo 0) "rc=$rcs $(cat $W/s0.err)"

# 3) DB tak pahunch nahi => RETRY, exit 1, spool wahin, disk par koi yateem file nahi
SUPABASE_URL=http://127.0.0.1:1 "$BIN" --spool-run >"$W/s1.out" 2>"$W/s1.err"; rcr=$?
t "db unreachable => exit 1, spool kept, no orphan files" $([ $rcr = 1 ] && [ "$(ls $W/spool | grep -c eml)" = 1 ] && [ "$(find $W/root -type f | wc -l)" = 0 ] && echo 1 || echo 0) "rc=$rcr files=$(find $W/root -type f | wc -l) $(cat $W/s1.err | head -2)"

# 4) asli run
"$BIN" --spool-run >"$W/s2.out" 2>"$W/s2.err"; rc2=$?
t "spool-run exit 0, processed=1" $([ $rc2 = 0 ] && grep -q "processed=1 failed=0 left=0" "$W/s2.out" && echo 1 || echo 0) "$(cat $W/s2.out $W/s2.err)"
t "spool empty after success" $([ "$(ls $W/spool | grep -c eml)" = 0 ] && echo 1 || echo 0)
M1=$($PSQL "select id from mail_messages order by ctid limit 1")
t "4 metadata rows still 4 (linked, not duplicated)" $([ "$($PSQL "select count(*) from mail_attachments where message_id='$M1'")" = 4 ] && echo 1 || echo 0)
t "quote.pdf stored: sha256 matches file bytes" $([ "$($PSQL "select sha256 from mail_attachments where filename='quote.pdf'")" = "$PDFSHA" ] && echo 1 || echo 0)
REL=$($PSQL "select disk_path from mail_attachments where filename='quote.pdf'")
t "file on disk at <org>/<sha2>/<sha>-<nonce>, identical bytes" $([ -f "$W/root/$REL" ] && cmp -s "$W/root/$REL" "$W/pdf.bin" && echo "$REL" | grep -q "^11111111-1111-1111-1111-111111111111/${PDFSHA:0:2}/$PDFSHA-" && echo 1 || echo 0) "$REL"
t "scan says clean for quote.pdf" $([ "$($PSQL "select scan->>'clamd' from mail_attachments where filename='quote.pdf'")" = clean ] && echo 1 || echo 0)
t "same.txt twice => two rows, two different sha" $([ "$($PSQL "select count(distinct sha256) from mail_attachments where filename='same.txt'")" = 2 ] && echo 1 || echo 0)
t "EICAR: no bytes kept, row says found" $([ "$($PSQL "select (sha256 is null and disk_path is null and scan->>'clamd'='found' and scan->>'signature' <> '') from mail_attachments where filename='eicar.txt'")" = t ] && [ "$(grep -rl EICAR "$W/root" 2>/dev/null | wc -l)" = 0 ] && echo 1 || echo 0)
t "no temp leftovers" $([ "$(find $W/root -path '*/.tmp/*' -type f | wc -l)" = 0 ] && echo 1 || echo 0)

# 5) wahi pdf doosri mail mein => dedup (org ke andar), disk par EK hi file
"$BIN" sara@example.com basic.test@anexomail.com <"$W/m2.eml" 2>/dev/null; "$BIN" --spool-run >"$W/s3.out" 2>&1
t "same pdf in 2nd mail: one file on disk (dedup inside org)" $([ "$(find $W/root -type f -name "$PDFSHA-*" | wc -l)" = 1 ] && echo 1 || echo 0) "$(find $W/root -type f -name "$PDFSHA-*")"
t "both rows point to the same path" $([ "$($PSQL "select count(distinct disk_path) from mail_attachments where sha256='$PDFSHA'")" = 1 ] && [ "$($PSQL "select count(*) from mail_attachments where sha256='$PDFSHA'")" = 2 ] && echo 1 || echo 0)

# 6) ingest ne rows banayi hi nahi (jaisa live par dikha) => nayi rows banti hain
$PSQL "update stub_cfg set v='false' where k='make_rows'" >/dev/null
"$BIN" sara@example.com basic.test@anexomail.com <"$W/m1.eml" 2>/dev/null; "$BIN" --spool-run >"$W/s4.out" 2>&1
M3=$($PSQL "select id from mail_messages order by ctid desc limit 1")
t "no pre-rows => 4 rows created from the mail" $([ "$($PSQL "select count(*) from mail_attachments where message_id='$M3'")" = 4 ] && echo 1 || echo 0)
t "download path resolves (E48 resolve sees inbound rows)" $([ "$($PSQL "select (public.mail_attach_resolve('00000000-0000-0000-0000-0000000000a1', (select id from mail_attachments where message_id='$M3' and filename='quote.pdf'))->>'ok')")" = true ] && echo 1 || echo 0)
t "other org's user cannot resolve it" $([ "$($PSQL "select (public.mail_attach_resolve('00000000-0000-0000-0000-0000000000b2', (select id from mail_attachments where message_id='$M3' and filename='quote.pdf'))->>'ok')")" = false ] && echo 1 || echo 0)
echo "== $pass pass, $fail fail"; [ $fail = 0 ]
