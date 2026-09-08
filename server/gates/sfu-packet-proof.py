#!/usr/bin/env python3
"""ANEXOVideoCall SFU — asli packet forwarding ka proof (koi fake 200 nahi).

Do UDP participants ek room mein register hote hain, ek media packet bhejta hai,
doosre ko wahi bytes milne chahiye. Na mile to exit 1 (gate RED).

  python3 server/gates/sfu-packet-proof.py [host] [port]
"""
import os
import socket
import sys
import time

HOST = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
PORT = int(sys.argv[2] if len(sys.argv) > 2 else 3501)
ROOM = f"gate-{os.getpid()}-{int(time.time())}"
PAYLOAD = b"\x80\x60ANEXO-SFU-GATE-MEDIA-PACKET"


def participant(name: str) -> socket.socket:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(4)
    sock.connect((HOST, PORT))
    sock.send(f"ANEXOSFU1 {ROOM} {name}".encode())
    reply = sock.recv(2048)
    if not reply.startswith(b"ANEXOSFU1 OK"):
        print(f"FAIL register {name}: {reply!r}")
        sys.exit(1)
    return sock


def main() -> None:
    a = participant("gate-a")
    b = participant("gate-b")
    try:
        a.send(PAYLOAD)
        got = b.recv(2048)
    except socket.timeout:
        print("FAIL forwarding: doosre participant ko packet nahi mila (timeout)")
        sys.exit(1)
    finally:
        a.close()
        b.close()

    if got != PAYLOAD:
        print(f"FAIL forwarding: bytes badal gaye ({len(got)} vs {len(PAYLOAD)})")
        sys.exit(1)
    print(f"OK forwarding: {len(got)} bytes byte-for-byte forward hue (room {ROOM})")


if __name__ == "__main__":
    main()
