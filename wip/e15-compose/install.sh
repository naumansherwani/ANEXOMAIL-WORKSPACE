#!/bin/bash
# E15 #3: /schedule identity org-check (security fix). Sirf 1 file, backup + restore.
export PAGER=cat
W=/opt/anexomail-web
B=https://raw.githubusercontent.com/naumansherwani/ANEXOMAIL-WORKSPACE/wip/e15-ui/wip/e15-compose
T=/tmp/e15compose; rm -rf $T; mkdir -p $T
cd $W || { echo "STOP: $W nahi mila"; exit 1; }
curl -fsSL "$B/mail-compose.ts" -o $T/mail-compose.ts || { echo DOWNLOAD_FAIL; exit 1; }
H=$(sha256sum $T/mail-compose.ts | cut -c1-64); echo "NEW_SHA=$H"
[ "$H" = "8563c3e9e2a4fa8e8276fe35abdb185259060817743ef53c51b63e24c25f69d1" ] || { echo "SHA_MISMATCH - ruk jao"; exit 1; }
bash -n /dev/null # noop, ts syntax checked offline already
echo "--- live file (pehle) ke pehle 5 line, taake pata chale kya replace ho raha hai"
head -5 server/routes/mail-compose.ts
BK=/root/backups/compose-$(date +%s); mkdir -p $BK
cp -a server/routes/mail-compose.ts $BK/mail-compose.ts.bak
cat > $BK/restore.sh <<EOF2
#!/bin/bash
cd $W && cp -a $BK/mail-compose.ts.bak server/routes/mail-compose.ts && /root/bin/safe-build-web.sh && pm2 restart anexomail-web --update-env && pm2 save && echo RESTORED
EOF2
chmod +x $BK/restore.sh
echo "BACKUP_OK $BK"
cp $T/mail-compose.ts server/routes/mail-compose.ts
echo APPLIED
/root/bin/safe-build-web.sh 2>&1 | tail -15
pm2 restart anexomail-web --update-env && pm2 save
sleep 3
curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health
echo "Agar kuch kharab ho: bash $BK/restore.sh"
