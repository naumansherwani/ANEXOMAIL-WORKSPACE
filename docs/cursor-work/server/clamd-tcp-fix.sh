#!/usr/bin/env bash
# ANEXOMAIL — clamd chal raha hai par 127.0.0.1:3310 par nahi sun raha (founder ka output 20 Oct 23:50).
#   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/clamd-tcp-fix.sh)
# Sabab: Debian ka clamd systemd SOCKET se chalta hai (clamav-daemon.socket); clamd.conf ki `TCPSocket 3310` tab ignore hoti hai. Hamari Rust
# 127.0.0.1:3310 par baat karti hai. Fix: socket unit ko sirf LOCALHOST TCP bhi dena (drop-in; bahar se kuch nahi khulta). Backup + wapas.
set -uo pipefail
D=/etc/systemd/system/clamav-daemon.socket.d; F="$D/anexomail-tcp.conf"; ADDR="${CLAMD_ADDR:-127.0.0.1:3310}"; H="${ADDR%:*}"; P="${ADDR##*:}"
probe() { python3 -I - "$H" "$P" <<'PY'
import socket, struct, sys
h, p = sys.argv[1], int(sys.argv[2])
e = ("X5O!P%@AP[4\\PZX54(P^)7CC)7}$" + "EICAR-STANDARD-ANTIVIRUS-TEST-FILE!" + "$H+H*").encode()
def ask(b):
    s = socket.create_connection((h, p), timeout=120); s.sendall(b"zINSTREAM\0")
    s.sendall(struct.pack(">I", len(b)) + b + struct.pack(">I", 0)); o = b""
    while True:
        d = s.recv(4096)
        if not d: break
        o += d
    return o.decode(errors="replace").strip("\0\n ")
try: c = ask(b"hello clean file"); x = ask(e)
except Exception as ex: print("DOWN", ex); sys.exit(1)
print("clean:", c, "| eicar:", x); sys.exit(0 if c.endswith("OK") and "FOUND" in x else 2)
PY
}
systemctl list-unit-files clamav-daemon.socket >/dev/null 2>&1 || { echo "FAIL: clamav-daemon.socket unit nahi — Debian ka clamav-daemon nahi? (kuch nahi badla)"; exit 2; }
if probe >/dev/null 2>&1; then echo "Pehle se theek: $(probe)"; exit 0; fi
mkdir -p "$D"; [ -f "$F" ] && cp -p "$F" "$F.bak.$(date +%s)"
printf '[Socket]\nListenStream=%s\n' "$ADDR" >"$F"
systemctl daemon-reload
systemctl stop clamav-daemon.service clamav-daemon.socket
systemctl start clamav-daemon.socket
echo "socket chalu ($ADDR); pehla connection clamd ko jagata hai (signatures load: 20-90s) ..."
if OUT="$(probe 2>&1)"; then echo "GREEN: $OUT"; else
  echo "!! abhi bhi RED: $OUT"; rm -f "$F"; systemctl daemon-reload; systemctl restart clamav-daemon.socket
  echo "   drop-in hata diya, purani halat wapas. Yeh bhejein:"; ss -ltnp 2>/dev/null | grep -E "$P|clam" | head; systemctl status clamav-daemon.socket --no-pager 2>&1 | head -12; journalctl -u clamav-daemon -n 15 --no-pager 2>&1 | tail -15; exit 1
fi
