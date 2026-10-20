U=http://127.0.0.1:3200
PSQL="psql -h /var/run/postgresql -U postgres -d e48 -At -c"
pass=0; fail=0
t() { # name cond
  if [ "$2" = "1" ]; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1  :: $3"; fail=$((fail+1)); fi
}
up() { # token name file [type]
  curl -s -m 20 -w '\n%{http_code}' -X POST -H "authorization: Bearer $1" -H "x-file-name: $2" -H "x-file-type: ${4:-application/octet-stream}" --data-binary @"$3" $U/file/attach
}
head -c 300000 /dev/urandom > f1.bin
cp f1.bin f1-copy.bin
printf 'hello world\n' > hi.txt
printf '%s' 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > eicar.com.txt
head -c 8000000 /dev/zero | tr '\0' 'a' > big.bin
: > empty.bin

r=$(up tokA "report%20(final).pdf" f1.bin application/pdf); code=${r##*$'\n'}; body=${r%$'\n'*}
t "upload ok 200" $([ "$code" = 200 ] && echo 1 || echo 0) "$r"
ID1=$(echo "$body" | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"]["data"]["id"])' 2>/dev/null)
t "upload says scanned:true (mock clamd up)" $(echo "$body" | grep -q '"scanned":true' && echo 1 || echo 0) "$body"
t "not deduped first time" $(echo "$body" | grep -q '"deduped":false' && echo 1 || echo 0) "$body"
SHA=$(sha256sum f1.bin | cut -d' ' -f1)
n=$(find attach-root -type f -name "$SHA-*" | wc -l)
t "exactly one file on disk, named by sha256" $([ "$n" = 1 ] && echo 1 || echo 0) "$n"
f=$(find attach-root -type f -name "$SHA-*")
t "stored bytes identical" $(cmp -s "$f" f1.bin && echo 1 || echo 0)
t "file lives under <org>/<sha2>/" $(echo "$f" | grep -q "attach-root/11111111-1111-1111-1111-111111111111/${SHA:0:2}/" && echo 1 || echo 0) "$f"
t "no temp leftovers" $([ "$(find attach-root -path '*/.tmp/*' -type f | wc -l)" = 0 ] && echo 1 || echo 0)
t "DB filename decoded+kept" $([ "$($PSQL "select filename from mail_outbound_attachments where id='$ID1'")" = "report (final).pdf" ] && echo 1 || echo 0) "$($PSQL "select filename from mail_outbound_attachments where id='$ID1'")"
t "DB scan recorded clean" $($PSQL "select scan->>'clamd' from org_attachment_blobs limit 1" | grep -q clean && echo 1 || echo 0)

# dedup within org, other user (C is in same org)
r=$(up tokC "same.pdf" f1-copy.bin application/pdf); code=${r##*$'\n'}; body=${r%$'\n'*}
t "same org other user: deduped true" $(echo "$body" | grep -q '"deduped":true' && echo 1 || echo 0) "$r"
t "still ONE file on disk" $([ "$(find attach-root -type f -name "$SHA-*" | wc -l)" = 1 ] && echo 1 || echo 0)
t "two staged rows, one blob" $([ "$($PSQL "select count(*) from mail_outbound_attachments")|$($PSQL "select count(*) from org_attachment_blobs")" = "2|1" ] && echo 1 || echo 0)

# other org same content: NOT deduped
r=$(up tokB "x.pdf" f1.bin application/pdf); body=${r%$'\n'*}
t "OTHER org same bytes: deduped false (walled garden)" $(echo "$body" | grep -q '"deduped":false' && echo 1 || echo 0) "$r"
t "two files on disk for the two orgs" $([ "$(find attach-root -type f -name "$SHA-*" | wc -l)" = 2 ] && echo 1 || echo 0)

# rejects
r=$(up tokA "big.bin" big.bin); code=${r##*$'\n'}
t "over cap => 413" $([ "$code" = 413 ] && echo 1 || echo 0) "$r"
t "over cap leaves no temp/file" $([ "$(find attach-root -path '*/.tmp/*' -type f | wc -l)" = 0 ] && echo 1 || echo 0)
r=$(up tokA "x.exe" hi.txt); code=${r##*$'\n'}
t ".exe => 422 file_type_blocked" $([ "$code" = 422 ] && echo "$r" | grep -q file_type_blocked && echo 1 || echo 0) "$r"
r=$(up tokA "holiday.jpg" fake.jpg); code=${r##*$'\n'}
t "exe disguised as jpg => 422" $([ "$code" = 422 ] && echo 1 || echo 0) "$r"
r=$(up tokA "eicar.txt" eicar.com.txt); code=${r##*$'\n'}
t "EICAR => 422 malware_detected" $([ "$code" = 422 ] && echo "$r" | grep -q malware_detected && echo 1 || echo 0) "$r"
t "EICAR not stored anywhere" $([ "$(grep -rl EICAR-STANDARD attach-root | wc -l)" = 0 ] && echo 1 || echo 0)
r=$(up tokA "empty.bin" empty.bin); code=${r##*$'\n'}
t "empty => 422" $([ "$code" = 422 ] && echo 1 || echo 0) "$r"
r=$(up badtoken "x.txt" hi.txt); code=${r##*$'\n'}
t "bad token => 401" $([ "$code" = 401 ] && echo 1 || echo 0) "$r"
r=$(curl -s -m 5 -w '\n%{http_code}' -X POST --data-binary @hi.txt $U/file/attach); code=${r##*$'\n'}
t "no token => 401" $([ "$code" = 401 ] && echo 1 || echo 0) "$r"
r=$(up tokA "../../../../tmp/evil.txt" hi.txt); code=${r##*$'\n'}; body=${r%$'\n'*}
ID2=$(echo "$body" | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"]["data"]["id"])' 2>/dev/null)
t "path-traversal name accepted only as plain 'evil.txt'" $([ "$($PSQL "select filename from mail_outbound_attachments where id='$ID2'")" = "evil.txt" ] && [ ! -e /tmp/evil.txt ] && echo 1 || echo 0)

# download
dl() { curl -s -m 20 -D dl.h -o dl.out -w '%{http_code}' -H "authorization: Bearer $1" "$U/file/attach/get?id=$2"; }
c=$(dl tokA $ID1)
t "uploader downloads own staged file" $([ "$c" = 200 ] && cmp -s dl.out f1.bin && echo 1 || echo 0) "$c"
t "download headers: attachment + nosniff + octet-stream" $(grep -qi 'content-disposition: attachment' dl.h && grep -qi 'x-content-type-options: nosniff' dl.h && grep -qi 'content-type: application/octet-stream' dl.h && echo 1 || echo 0) "$(cat dl.h)"
c=$(dl tokB $ID1); t "other org cannot download (404)" $([ "$c" = 404 ] && echo 1 || echo 0) "$c"
c=$(dl tokC $ID1); t "same-org colleague cannot download someone's STAGED file (404)" $([ "$c" = 404 ] && echo 1 || echo 0) "$c"
c=$(dl tokA not-a-uuid); t "bad id => 400" $([ "$c" = 400 ] && echo 1 || echo 0) "$c"
c=$(curl -s -o /dev/null -w '%{http_code}' "$U/file/attach/get?id=$ID1"); t "download without token => 401" $([ "$c" = 401 ] && echo 1 || echo 0) "$c"
# tamper: wrong size on disk => refuse
f=$(find attach-root/11111111-1111-1111-1111-111111111111 -type f -name "$SHA-*"); cp "$f" "$f.keep"; echo more >> "$f"
c=$(dl tokA $ID1); t "size mismatch on disk => 500 file_changed (never serves tampered bytes)" $([ "$c" = 500 ] && echo 1 || echo 0) "$c"
mv "$f.keep" "$f"
# sent-mail rows: commit, then org colleague can download
MSG=$($PSQL "insert into mail_messages(org_id) values ('11111111-1111-1111-1111-111111111111') returning id" | head -1)
$PSQL "select public.mail_attach_commit('00000000-0000-0000-0000-0000000000a1','11111111-1111-1111-1111-111111111111', array['$ID1'::uuid], '$MSG')" >/dev/null
AID=$($PSQL "select id from mail_attachments where message_id='$MSG'")
c=$(dl tokC $AID); t "after send: colleague in same org downloads (200)" $([ "$c" = 200 ] && cmp -s dl.out f1.bin && echo 1 || echo 0) "$c"
c=$(dl tokB $AID); t "after send: other org still 404" $([ "$c" = 404 ] && echo 1 || echo 0) "$c"

# procs
r=$(curl -s -m 8 -X POST -H "authorization: Bearer tokA" -H 'content-type: application/json' -d '{"input":{}}' $U/rpc/mail.attach.limits)
t "mail.attach.limits: cap 7MB, storage_ready, scanning true" $(echo "$r" | grep -q '"message_cap_bytes":7000000' && echo "$r" | grep -q '"storage_ready":true' && echo "$r" | grep -q '"scanning":true' && echo 1 || echo 0) "$r"
r=$(curl -s -m 8 -X POST -H "authorization: Bearer tokA" -H 'content-type: application/json' -d "{\"input\":{\"id\":\"$ID2\"}}" $U/rpc/mail.attach.remove)
t "mail.attach.remove ok" $(echo "$r" | grep -q '"removed":1' && echo 1 || echo 0) "$r"
r=$(curl -s -m 8 -X POST -H "authorization: Bearer tokB" -H 'content-type: application/json' -d "{\"input\":{\"id\":\"$ID1\"}}" $U/rpc/mail.attach.remove)
t "cannot remove someone else's file" $(echo "$r" | grep -q '"removed":0' && echo 1 || echo 0) "$r"
r=$(curl -s -m 8 -X POST -H "authorization: Bearer nope" -H 'content-type: application/json' -d '{"input":{}}' $U/rpc/mail.attach.limits)
t "limits without valid token => 401" $(echo "$r" | grep -q unauthorized && echo 1 || echo 0) "$r"
echo "-- $pass passed, $fail failed"
