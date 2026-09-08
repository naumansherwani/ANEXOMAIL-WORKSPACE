#!/usr/bin/env bash
# ============================================================================
# ANEXOMAIL — Hetzner Storage Box mount (reboot-safe, idempotent)
#   bash server/storage/mount-box.sh u123456
# Koi nano, koi manual edit. Password kahin save nahi hota.
# ============================================================================
set -uo pipefail
BOX="${1:-${BOX:-}}"
[ -n "$BOX" ] || { echo "FAIL: username do -> bash server/storage/mount-box.sh u123456"; exit 2; }
HOST="$BOX.your-storagebox.de"
MNT=/mnt/anexomail-box
KEY=/root/.ssh/storagebox
UNIT='mnt-anexomail\x2dbox.mount'

echo "==> packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -y -qq sshfs >/dev/null

echo "==> ssh key"
[ -f "$KEY" ] || ssh-keygen -t ed25519 -f "$KEY" -N '' -q
if ! ssh -p23 -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$BOX@$HOST" true 2>/dev/null; then
  echo ">>> Box ka password ek dafa daalo (kahin save nahi hota):"
  cat "$KEY.pub" | ssh -p23 -o StrictHostKeyChecking=accept-new "$BOX@$HOST" install-ssh-key
fi

echo "==> folders on Box"
ssh -p23 -i "$KEY" -o StrictHostKeyChecking=accept-new "$BOX@$HOST" \
  'mkdir -p /home/anexomail/attachments' || true

echo "==> systemd mount unit"
mkdir -p "$MNT"
cat > "/etc/systemd/system/$UNIT" <<EOF
[Unit]
Description=ANEXOMAIL Hetzner Storage Box
After=network-online.target
Wants=network-online.target

[Mount]
What=$BOX@$HOST:/home/anexomail
Where=$MNT
Type=fuse.sshfs
Options=_netdev,allow_other,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,IdentityFile=$KEY,StrictHostKeyChecking=accept-new,port=23,uid=5000,gid=5000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$UNIT" >/dev/null 2>&1 || true
systemctl restart "$UNIT"
sleep 2

echo
if mountpoint -q "$MNT"; then
  mkdir -p "$MNT/attachments"
  echo "GREEN  mounted: $MNT"
  df -h "$MNT" | tail -n 2
  echo "  next: bash server/storage/register-box.sh $BOX"
else
  echo "FAIL   mount nahi hua — reading:"
  systemctl status "$UNIT" --no-pager | tail -n 15
  exit 1
fi
