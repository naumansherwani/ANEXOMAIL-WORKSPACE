#!/bin/bash
# E15-UI: Mail cinema patch (address identity + cinematic inbox). Backup + sha gate + rollback.
export PAGER=cat
W=/opt/anexomail-web
B=https://raw.githubusercontent.com/naumansherwani/ANEXOMAIL-WORKSPACE/wip/e15-ui
T=/tmp/e15ui; rm -rf $T; mkdir -p $T
cat > $T/pre.sha <<'EOF'
fc840505976e56efbbbfe520ac680f3b040e92d14021b463d7bb962f7992d118  src/components/app/mail/MailRail.tsx
678ee994585392e0c7305a611f1300c3f6056f8500afb0ed6a3c6db5b38badb7  src/components/app/mail/ThreadList.tsx
63065e47516d68930a6f813d726a3e5e7bbf4777970d5aba53295f01d796898f  src/routes/app.mail.$folder.tsx
EOF
cat > $T/post.sha <<'EOF'
9776297fdd9f40416ac8ab4f722de02d55a8ebcc021946fddce89020720bfa44  src/components/app/mail/AddressChip.tsx
01ed0216e61fb610eb900de5fdb245555ce4dc4230078165cc80b8f979cfd2d5  src/lib/mail-identity.ts
4acd9803ea339a0c92d9f97b7d7c1008932fa5a2274ab396a59e6a25c513974f  wip/ui/mx-cinema.css
dc40aa0f00157b58c9a6af0e1e579049610fbaef9f54b2a6a3983e7e839f88fa  wip/ui/thread.patch.py
0344a3357064d095ef5e5d6dd68057ad376fdd79689fff2dcea65516811b8e88  src/components/app/mail/MailRail.tsx
a25e6867894cb6bf027ed8d3c9e1b72fcdd8a032bdc2a2aabf5da0f42eab7086  src/components/app/mail/ThreadList.tsx
b82975b86db89db4a5a8ac29543d1bb902a5b37e25da922840c3905580f3abcc  src/routes/app.mail.$folder.tsx
EOF
cd $W || { echo "STOP: $W nahi mila"; exit 1; }
echo "--- 1 naye files download + sha"
while read -r sha f; do
  u="$B/${f//\$/%24}"; mkdir -p "$T/new/$(dirname "$f")"
  curl -fsSL "$u" -o "$T/new/$f" || { echo "DOWNLOAD_FAIL $f"; exit 1; }
  [ "$(sha256sum "$T/new/$f" | cut -c1-64)" = "$sha" ] && echo "OK    $f" || { echo "SHA_MISMATCH $f"; exit 1; }
done < $T/post.sha
echo "--- 2 live files repo se match karti hain?"
BAD=0
while read -r sha f; do
  [ -f "$f" ] || { echo "MISSING $f"; BAD=1; continue; }
  [ "$(sha256sum "$f" | cut -c1-64)" = "$sha" ] && echo "SAME  $f" || { echo "DIFF  $f"; BAD=1; }
done < $T/pre.sha
TF='src/routes/app.mail.$folder.$threadId.tsx'
python3 $T/new/wip/ui/thread.patch.py "$TF" $T/thread.out || BAD=1
[ $BAD -eq 0 ] || { echo "STOP: kuch match nahi hua. Kuch nahi badla. Output bhej do."; exit 1; }
echo "--- 3 backup"
BK=/root/backups/ui-$(date +%s); mkdir -p $BK
while read -r sha f; do cp -a --parents "$f" $BK/; done < $T/pre.sha
cp -a --parents src/styles.css "$TF" $BK/
cat > $BK/restore.sh <<EOF2
#!/bin/bash
cd $W && cp -a $BK/src . && rm -f src/components/app/mail/AddressChip.tsx src/lib/mail-identity.ts && /root/bin/safe-build-web.sh && echo RESTORED
EOF2
chmod +x $BK/restore.sh; echo "BACKUP_OK $BK"
echo "--- 4 lagao"
while read -r sha f; do
  case "$f" in wip/*) continue;; esac
  mkdir -p "$(dirname "$f")"; cp "$T/new/$f" "$f"
done < $T/post.sha
cp $T/thread.out "$TF"
grep -q "Mail cinema (mx-\*)" src/styles.css || { echo >> src/styles.css; cat $T/new/wip/ui/mx-cinema.css >> src/styles.css; }
echo APPLIED
echo "--- 5 build (safe-build)"
/root/bin/safe-build-web.sh 2>&1 | tail -15
sleep 3
curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health
echo "marker css: $(grep -rl 'mx-row' .output/public 2>/dev/null | wc -l) file(s)"
echo "Agar kuch kharab ho: bash $BK/restore.sh"
