#!/usr/bin/env bash
# ANEXOMAIL — attachment limit naapna (READ-ONLY). Kuch nahi badalta.
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/attach-limit-measure.sh)
# Dikhata hai: Postfix message_size_limit, clamd StreamMaxLength/MaxFileSize, DB ka server_ceiling, aur har plan ke liye safe/unsafe.
# Formula: raw bytes * 4/3 (base64) + 200000 header < Postfix limit; clamd StreamMaxLength >= raw bytes.
set -uo pipefail
want() { echo "$1 MiB = $(( $1 * 1048576 )) bytes (mail size ~ $(( $1 * 1048576 * 4 / 3 + 200000 )))"; }
PF="$(postconf -h message_size_limit 2>/dev/null | head -1)"
echo "Postfix message_size_limit : ${PF:-NAHI MILA}"
CF=""; for f in /etc/clamav/clamd.conf /etc/clamd.d/scan.conf /etc/clamd.conf; do [ -r "$f" ] && CF="$f" && break; done
SM=""; MF=""
if [ -n "$CF" ]; then
  SM="$(awk '/^StreamMaxLength/{print $2}' "$CF" | tail -1)"; MF="$(awk '/^MaxFileSize/{print $2}' "$CF" | tail -1)"
  echo "clamd config ($CF) : StreamMaxLength=${SM:-default(25M)} MaxFileSize=${MF:-default(25M)}"
else echo "clamd config : NAHI MILI (clamd chalta hi na ho to scan 'scanned:false' aata hai)"; fi
CE=""
if [ -r /etc/anexomail/sync.env ] && command -v psql >/dev/null 2>&1; then
  CE="$( . /etc/anexomail/sync.env 2>/dev/null; psql "${WORKING_URL:-}" -X -At -c "select value from public.mail_attach_limits where key='server_ceiling_bytes'" 2>/dev/null | head -1 )"
fi
echo "DB server_ceiling_bytes    : ${CE:-NAHI MILA}"
to_b() { case "$1" in *[Mm]) echo $(( ${1%[Mm]} * 1048576 ));; *[Kk]) echo $(( ${1%[Kk]} * 1024 ));; ''|*[!0-9]*) echo 26214400;; *) echo "$1";; esac; }
SMB="$(to_b "${SM:-25M}")"
for pair in "Basic:25" "Pro:35" "Business:45" "BusinessPro:60"; do
  n="${pair%%:*}"; mb="${pair##*:}"; raw=$(( mb * 1048576 )); mail=$(( raw * 4 / 3 + 200000 ))
  pf_ok="NO"; [[ "$PF" =~ ^[0-9]+$ ]] && [ "$mail" -lt "$PF" ] && pf_ok="OK"
  cl_ok="NO"; [ "$raw" -le "$SMB" ] && cl_ok="OK"
  printf '%-12s %2s MiB  postfix:%s  clamd:%s  ' "$n" "$mb" "$pf_ok" "$cl_ok"; [ "$pf_ok$cl_ok" = "OKOK" ] && echo "-> SAFE" || echo "-> pehle server config badlo"
done
echo
echo "Agla qadam: sirf jin plans par SAFE aaye wahi ceiling E93 se barhao. clamd StreamMaxLength badalna ho to /etc/clamav/clamd.conf mein"
echo "  StreamMaxLength 64M ; MaxFileSize 64M  phir: systemctl restart clamav-daemon   (aur pehle founder ki 'haan')."
