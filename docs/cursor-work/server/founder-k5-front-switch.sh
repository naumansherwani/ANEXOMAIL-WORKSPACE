#!/bin/bash
# K5a front switch (founder front routing line only; the awam program itself is server/awam-edge, awam lane).
# MODE=prep  : backup founder.env + write the rollback FILE /root/i9/k5-rollback.sh (changes nothing live).
# MODE=apply : needs the rollback file; sets FOUNDER_FRONT_OTHER=127.0.0.1:18081 (PROXY stays ON), restarts the founder service,
#              proves every awam host on the real :443 (AES-256, AES-128 refused, h2 request) and ROLLS BACK BY ITSELF if anexomail.com is not 200.
set -u
MODE="${MODE:-prep}"; ENVF=/etc/anexomail/founder.env; BAK=/root/i9/founder.env.pre-k5sw; RB=/root/i9/k5-rollback.sh; AWD=/etc/anexomail/tls/awam
if [ "$MODE" = prep ]; then
  mkdir -p /root/i9 && cp -a "$ENVF" "$BAK" || { echo "FAIL: backup"; exit 2; }
  printf '%s\n' '#!/bin/bash' "cp -a $BAK $ENVF && systemctl restart anexomail-founder && echo rolled-back" > "$RB"; chmod 700 "$RB"
  grep -E '^FOUNDER_FRONT_(OTHER|PROXY_TLS)=' "$ENVF"; ls -l "$RB" "$BAK"; echo "OK prep: rollback file ready, nothing live changed."; exit 0
fi
[ -x "$RB" ] && [ -f "$BAK" ] || { echo "FAIL: run MODE=prep first"; exit 2; }
ss -tln | grep -q '127.0.0.1:18081' || { echo "FAIL: awam-edge not listening on 18081"; exit 3; }
grep -q '^FOUNDER_FRONT_PROXY_TLS=on' "$ENVF" || { echo "FAIL: FOUNDER_FRONT_PROXY_TLS is not on"; exit 3; }
if grep -q '^FOUNDER_FRONT_OTHER=' "$ENVF"; then sed -i 's|^FOUNDER_FRONT_OTHER=.*|FOUNDER_FRONT_OTHER=127.0.0.1:18081|' "$ENVF"; else echo 'FOUNDER_FRONT_OTHER=127.0.0.1:18081' >> "$ENVF"; fi
systemctl restart anexomail-founder; sleep 6
FAILS=0; N=0
for crt in "$AWD"/*.crt; do
  h="$(basename "$crt" .crt)"; N=$((N+1))
  c256="$(echo | timeout 8 openssl s_client -connect 127.0.0.1:443 -servername "$h" -tls1_3 -alpn h2 2>/dev/null | grep -m1 'Cipher    :' | awk '{print $3}')"
  c128="$(echo | timeout 8 openssl s_client -connect 127.0.0.1:443 -servername "$h" -tls1_3 -ciphersuites TLS_AES_128_GCM_SHA256 2>&1 | grep -c 'alert handshake failure')"
  code="$(curl -s -o /dev/null -m 10 -w '%{http_code}' --resolve "$h:443:127.0.0.1" "https://$h/" 2>/dev/null)"
  echo "$h  cipher=$c256  aes128_refused=$([ "$c128" -ge 1 ] && echo yes || echo NO)  http=$code"
  [ "$c256" = TLS_AES_256_GCM_SHA384 ] && [ "$c128" -ge 1 ] || FAILS=$((FAILS+1))
done
HC="$(curl -s -o /dev/null -m 10 -w '%{http_code}' --resolve anexomail.com:443:127.0.0.1 https://anexomail.com/ 2>/dev/null)"
FC="$(curl -s -o /dev/null -m 10 -w '%{http_code}' --resolve founderworkspace.anexomail.com:443:127.0.0.1 https://founderworkspace.anexomail.com/ 2>/dev/null)"
echo "hosts=$N fails=$FAILS  anexomail.com=$HC  founder host=$FC"
journalctl -u anexomail-awam-edge -n 3 --no-pager 2>/dev/null | cut -c1-200
if [ "$FAILS" -ne 0 ] || [ "$HC" != 200 ] || [ "$FC" != 200 ]; then echo "PROOF FAILED -> rolling back"; bash "$RB"; exit 4; fi
echo "OK GREEN-CANDIDATE: awam names now go through the AES-256 awam-edge on the real :443. Rollback: bash $RB"
