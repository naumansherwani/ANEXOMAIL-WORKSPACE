#!/usr/bin/env bash
# ANEXOMAIL — file safety (self-hosted ClamAV) ka SACH: chal raha hai ya nahi, aur EICAR test file asli mein pakadta hai ya nahi.
#   bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/file-safety-check.sh)            # sirf check (kuch nahi badalta)
#   INSTALL=1 bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/file-safety-check.sh) # ClamAV na ho to lagata hai
# Kyun: Rust ka scanner (main.rs clamd_scan) clamd 127.0.0.1:3310 par chalta hai; clamd na ho to woh "chup" rehta hai (jhooti clean claim nahi
# karta) lekin tab sirf type/entropy/archive checks chalte hain — "malware scanning" ka wada tab poora nahi. Yeh script wahi sach dikhati hai.
# polar-rust-payment, Caddy, mail, Rust, web ko haath nahi lagata. EICAR test string repo mein poori nahi likhi (AV false-positive se bachne ke liye).
set -uo pipefail
ADDR="${CLAMD_ADDR:-127.0.0.1:3310}"; HOST="${ADDR%:*}"; PORT="${ADDR##*:}"

probe() { python3 -I - "$HOST" "$PORT" <<'PY'
import socket, struct, sys
host, port = sys.argv[1], int(sys.argv[2])
# EICAR: standard antivirus test string, tukdon mein jodi
eicar = ("X5O!P%@AP[4\\PZX54(P^)7CC)7}$" + "EICAR-STANDARD-ANTIVIRUS-TEST-FILE!" + "$H+H*").encode()
def ask(payload):
    s = socket.create_connection((host, port), timeout=5)
    s.sendall(b"zINSTREAM\0")
    for i in range(0, len(payload), 65536):
        c = payload[i:i+65536]; s.sendall(struct.pack(">I", len(c)) + c)
    s.sendall(struct.pack(">I", 0))
    out = b""
    while True:
        d = s.recv(4096)
        if not d: break
        out += d
    s.close(); return out.decode(errors="replace").strip("\0\n ")
try:
    clean = ask(b"hello clean file")
    bad = ask(eicar)
except Exception as e:
    print("DOWN", e); sys.exit(1)
print("clean:", clean, "| eicar:", bad)
sys.exit(0 if clean.endswith("OK") and "FOUND" in bad else 2)
PY
}

echo "== 1) clamd $ADDR par EICAR test"
OUT="$(probe 2>&1)"; rc=$?
echo "   $OUT"
if [ $rc -eq 0 ]; then echo "GREEN: file safety zinda — clamd saaf file ko OK, EICAR ko FOUND deta hai."; exit 0; fi
echo "RED: clamd nahi chal raha ya EICAR nahi pakda (rc=$rc)."
[ "${INSTALL:-}" = "1" ] || { echo "   Lagane ke liye: INSTALL=1 ke saath yehi command dobara chalayen."; exit 1; }

echo "== 2) ClamAV install (apni infrastructure par, koi bahari service nahi)"
if command -v apt-get >/dev/null 2>&1; then DEBIAN_FRONTEND=noninteractive apt-get install -y clamav clamav-daemon >/dev/null 2>&1 || { echo "FAIL: apt install"; exit 2; }; SVC=clamav-daemon; CONF=/etc/clamav/clamd.conf
elif command -v pacman >/dev/null 2>&1; then pacman -S --noconfirm --needed clamav >/dev/null 2>&1 || { echo "FAIL: pacman install"; exit 2; }; SVC=clamav-daemon; CONF=/etc/clamav/clamd.conf
elif command -v dnf >/dev/null 2>&1; then dnf install -y clamav clamd clamav-update >/dev/null 2>&1 || { echo "FAIL: dnf install"; exit 2; }; SVC=clamd@scan; CONF=/etc/clamd.d/scan.conf
else echo "FAIL: koi package manager nahi mila (apt/pacman/dnf)"; exit 2; fi
[ -f "$CONF" ] || { echo "FAIL: $CONF nahi mila"; exit 2; }
cp -p "$CONF" "$CONF.bak.$(date +%s)"
grep -q '^TCPSocket' "$CONF" || printf '\nTCPSocket %s\n' "$PORT" >>"$CONF"
grep -q '^TCPAddr' "$CONF"   || printf 'TCPAddr %s\n' "$HOST" >>"$CONF"
sed -i 's/^Example/#Example/' "$CONF" 2>/dev/null || true
echo "   signatures (freshclam) ..."; (systemctl stop clamav-freshclam >/dev/null 2>&1; freshclam >/dev/null 2>&1) || echo "   WARN: freshclam fail (network allowlist?) — baad mein dobara"
systemctl enable --now clamav-freshclam >/dev/null 2>&1 || true
systemctl enable --now "$SVC" >/dev/null 2>&1 || { echo "FAIL: $SVC start nahi hua (journalctl -u $SVC)"; exit 2; }
echo "== 3) intezar (clamd signatures load karta hai, 90s tak)"
for i in $(seq 1 18); do sleep 5; OUT="$(probe 2>&1)" && { echo "   $OUT"; echo "GREEN: ClamAV laga aur EICAR pakad raha hai."; exit 0; }; done
echo "   $OUT"; echo "RED: install hua par EICAR abhi nahi pakda — 'journalctl -u $SVC -n 30' ka output Claude ko bhejein."; exit 1
