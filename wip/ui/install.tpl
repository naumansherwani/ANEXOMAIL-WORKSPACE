#!/bin/bash
# E15-UI: Mail cinema patch (address identity + cinematic inbox). Backup + sha gate + rollback.
export PAGER=cat
W=/opt/anexomail-web
B=https://raw.githubusercontent.com/naumansherwani/ANEXOMAIL-WORKSPACE/wip/e15-ui
T=/tmp/e15ui; rm -rf $T; mkdir -p $T
cat > $T/pre.sha <<'EOF'
@@PRE@@
EOF
cat > $T/post.sha <<'EOF'
@@POST@@
EOF
cd $W || { echo "STOP: $W nahi mila"; exit 1; }
echo "--- 1 live files repo se match karti hain?"
BAD=0
while read -r sha f; do
  [ -f "$f" ] || { echo "MISSING $f"; BAD=1; continue; }
  [ "$(sha256sum "$f" | cut -c1-64)" = "$sha" ] && echo "SAME  $f" || { echo "DIFF  $f"; BAD=1; }
done < $T/pre.sha
[ $BAD -eq 0 ] || { echo "STOP: live files repo se alag hain. Kuch nahi badla. Output bhej do."; exit 1; }
echo "--- 2 naye files download + sha"
while read -r sha f; do
  u="$B/${f//\$/%24}"; mkdir -p "$T/new/$(dirname "$f")"
  curl -fsSL "$u" -o "$T/new/$f" || { echo "DOWNLOAD_FAIL $f"; exit 1; }
  [ "$(sha256sum "$T/new/$f" | cut -c1-64)" = "$sha" ] && echo "OK    $f" || { echo "SHA_MISMATCH $f"; exit 1; }
done < $T/post.sha
echo "--- 3 backup"
BK=/root/backups/ui-$(date +%s); mkdir -p $BK
while read -r sha f; do cp -a --parents "$f" $BK/; done < $T/pre.sha
cp -a --parents src/styles.css $BK/
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
grep -q "Mail cinema (mx-\*)" src/styles.css || { echo >> src/styles.css; cat $T/new/wip/ui/mx-cinema.css >> src/styles.css; }
echo APPLIED
echo "--- 5 build (safe-build)"
/root/bin/safe-build-web.sh 2>&1 | tail -15
sleep 3
curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health
echo "marker css: $(grep -rl 'mx-row' .output/public 2>/dev/null | wc -l) file(s)"
echo "Agar kuch kharab ho: bash $BK/restore.sh"
