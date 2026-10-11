#!/bin/bash
# E15-C installer: sync-domains.sh -> /usr/local/bin + cron (har minute). Pehle wala sync-maps cron chalta rehta hai.
export PAGER=cat
B=https://raw.githubusercontent.com/naumansherwani/ANEXOMAIL-WORKSPACE/wip/e15-rust/wip/e15c
[ -f /etc/anexomail/sync.env ] || { echo "STOP: /etc/anexomail/sync.env nahi mila"; exit 1; }
curl -fsSL $B/sync-domains.sh -o /tmp/sync-domains.sh || { echo DOWNLOAD_FAIL; exit 1; }
H=$(sha256sum /tmp/sync-domains.sh | cut -c1-64); echo "SCRIPT_SHA=$H"
[ "$H" = "b2777cafdeb4c8130c19a50aed347c7e991d83255d588f42a59a0f0f0142c28f" ] || { echo "SHA_MISMATCH - ruk jao"; exit 1; }
bash -n /tmp/sync-domains.sh || { echo SYNTAX_FAIL; exit 1; }
install -m 0755 -o root -g root /tmp/sync-domains.sh /usr/local/bin/anexomail-sync-domains.sh
printf '* * * * * root /usr/local/bin/anexomail-sync-domains.sh >> /var/log/anexomail-sync-domains.log 2>&1\n' > /etc/cron.d/anexomail-sync-domains
chmod 644 /etc/cron.d/anexomail-sync-domains
cp -a /etc/opendkim/KeyTable /etc/opendkim/KeyTable.bak-pre-e15 2>/dev/null; cp -a /etc/opendkim/SigningTable /etc/opendkim/SigningTable.bak-pre-e15 2>/dev/null
/usr/local/bin/anexomail-sync-domains.sh && echo "FIRST_RUN_OK (kuch badla to neeche log mein)"
tail -n 5 /var/log/anexomail-sync-domains.log 2>/dev/null
echo INSTALL_OK
