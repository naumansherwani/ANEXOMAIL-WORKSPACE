#!/usr/bin/env python3
"""
selftest — expiry-watch ko NAKLI par ASLI protocol par parakhta hai (internet / server ki zaroorat nahi):
  * local TLS servers (IMAPS-jaisa, SMTP STARTTLS, web SNI) jinke cert hum banate hain (test CA, alag alag din)
  * local DNS server (UDP + TCP fallback jab jawab bada ho) jisme MX/SPF/DMARC/PTR/DKIM
  * local RDAP HTTP server (domain expiry)
  * nakli sendmail jo mail ek file mein rakhta hai
Chalao:  python3 docs/cursor-work/server/expiry-watch/selftest.py
"""
import base64
import json
import os
import shutil
import socket
import socketserver
import ssl
import struct
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "anexomail-expiry-watch.py")
T = tempfile.mkdtemp(prefix="ew-")
FAILS = []


def sh(*a, **k):
    return subprocess.run(a, check=True, capture_output=True, **k)


def check(name, cond, extra=""):
    print(("  ok   " if cond else "  FAIL ") + name + ((" — " + str(extra)) if (extra and not cond) else ""))
    if not cond:
        FAILS.append(name)


# ---------------------------------------------------------------- certs
def make_ca():
    sh("openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", T + "/ca.key", "-out", T + "/ca.crt",
       "-days", "365", "-subj", "/CN=TestCA",
       "-addext", "basicConstraints=critical,CA:TRUE", "-addext", "keyUsage=critical,keyCertSign,cRLSign")


def make_leaf(name, hosts, days):
    sh("openssl", "req", "-newkey", "rsa:2048", "-nodes", "-keyout", f"{T}/{name}.key", "-out", f"{T}/{name}.csr",
       "-subj", f"/CN={hosts[0]}")
    with open(f"{T}/{name}.ext", "w") as fh:
        fh.write("subjectAltName=" + ",".join("DNS:" + h for h in hosts) + "\nbasicConstraints=CA:FALSE\n")
    sh("openssl", "x509", "-req", "-in", f"{T}/{name}.csr", "-CA", T + "/ca.crt", "-CAkey", T + "/ca.key",
       "-CAcreateserial", "-out", f"{T}/{name}.crt", "-days", str(days), "-extfile", f"{T}/{name}.ext")


# ---------------------------------------------------------------- servers
SEL = {"mail993": "mail_ok", "mail587": "mail_ok"}  # kaun sa cert abhi live hai (test badalta hai)
WEBCERT = {}  # host -> cert name


def server_ctx(name):
    c = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    c.load_cert_chain(f"{T}/{name}.crt", f"{T}/{name}.key")
    return c


def serve_tls(port_holder, key, mode):
    srv = socket.socket()
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", 0))
    srv.listen(8)
    port_holder[key] = srv.getsockname()[1]

    def loop():
        while True:
            try:
                conn, _ = srv.accept()
            except OSError:
                return
            try:
                if mode == "tls993":
                    ctx = server_ctx(SEL["mail993"])
                    with ctx.wrap_socket(conn, server_side=True) as s:
                        s.recv(1)
                elif mode == "smtp":
                    conn.sendall(b"220 test ESMTP\r\n")
                    f = conn.makefile("rb")
                    while True:
                        line = f.readline().strip().upper()
                        if line.startswith(b"EHLO") or line.startswith(b"HELO"):
                            conn.sendall(b"250-test\r\n250 STARTTLS\r\n")
                        elif line == b"STARTTLS":
                            conn.sendall(b"220 go\r\n")
                            ctx = server_ctx(SEL["mail587"])
                            with ctx.wrap_socket(conn, server_side=True) as s:
                                s.recv(1)
                            break
                        elif line in (b"QUIT", b""):
                            conn.sendall(b"221 bye\r\n")
                            break
                elif mode == "web":
                    base = server_ctx("web_default")

                    def pick(sslobj, name, _ctx):
                        if name in WEBCERT:
                            sslobj.context = server_ctx(WEBCERT[name])

                    base.sni_callback = pick
                    with base.wrap_socket(conn, server_side=True) as s:
                        s.recv(1)
            except (OSError, ssl.SSLError):
                pass
            finally:
                try:
                    conn.close()
                except OSError:
                    pass

    threading.Thread(target=loop, daemon=True).start()


# ---------------------------------------------------------------- DNS
ZONE = {}  # (name, type) -> [values]


def enc_name(n):
    return b"".join(bytes([len(p)]) + p.encode() for p in n.strip(".").split(".")) + b"\x00"


def dns_answer(q, tcp):
    qid, = struct.unpack("!H", q[:2])
    i = 12
    labels = []
    while q[i]:
        labels.append(q[i + 1 : i + 1 + q[i]].decode())
        i += 1 + q[i]
    name = ".".join(labels).lower()
    qt, = struct.unpack("!H", q[i + 1 : i + 3])
    types = {1: "A", 12: "PTR", 15: "MX", 16: "TXT"}
    vals = ZONE.get((name, types[qt]), [])
    ans = b""
    for v in vals:
        if types[qt] == "TXT":
            data = b"".join(bytes([len(c)]) + c for c in [v[k : k + 255].encode() for k in range(0, len(v), 255)])
        elif types[qt] == "MX":
            data = struct.pack("!H", v[0]) + enc_name(v[1])
        elif types[qt] == "PTR":
            data = enc_name(v)
        else:
            data = socket.inet_aton(v)
        ans += b"\xc0\x0c" + struct.pack("!HHIH", qt, 1, 60, len(data)) + data
    rcode = 0 if vals else 3
    msg = struct.pack("!6H", qid, 0x8180 | rcode, 1, len(vals), 0, 0) + q[12 : i + 5] + ans
    if not tcp and len(msg) > 512:  # UDP par bada jawab = TC, collector TCP par jaye
        msg = struct.pack("!6H", qid, 0x8380, 1, 0, 0, 0) + q[12 : i + 5]
    return msg


def start_dns():
    udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp.bind(("127.0.0.1", 0))
    port = udp.getsockname()[1]

    def uloop():
        while True:
            try:
                q, addr = udp.recvfrom(4096)
            except OSError:
                return
            udp.sendto(dns_answer(q, False), addr)

    class H(socketserver.BaseRequestHandler):
        def handle(self):
            ln, = struct.unpack("!H", self.request.recv(2))
            q = self.request.recv(ln)
            r = dns_answer(q, True)
            self.request.sendall(struct.pack("!H", len(r)) + r)

    class S(socketserver.ThreadingTCPServer):
        allow_reuse_address = True

    tcp = S(("127.0.0.1", port), H)
    threading.Thread(target=uloop, daemon=True).start()
    threading.Thread(target=tcp.serve_forever, daemon=True).start()
    return port


# ---------------------------------------------------------------- RDAP
RDAP = {}  # domain -> expiration iso (ya None => 404)


def start_rdap():
    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def do_GET(self):
            d = self.path.rsplit("/", 1)[-1]
            if d not in RDAP:
                self.send_response(404)
                self.end_headers()
                return
            body = json.dumps({"events": [{"eventAction": "registration", "eventDate": "2015-01-01T00:00:00Z"},
                                          {"eventAction": "expiration", "eventDate": RDAP[d]}],
                               "status": ["client transfer prohibited"]}).encode()
            self.send_response(200)
            self.send_header("content-type", "application/rdap+json")
            self.end_headers()
            self.wfile.write(body)

    s = HTTPServer(("127.0.0.1", 0), H)
    threading.Thread(target=s.serve_forever, daemon=True).start()
    return s.server_address[1]


# ---------------------------------------------------------------- run
def iso_in(days):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + days * 86400))


def run(extra_env=None, args=()):
    env = dict(os.environ)
    env.update(ENV)
    env.update(extra_env or {})
    p = subprocess.run([sys.executable, "-I", SCRIPT, *args], env=env, capture_output=True, text=True, timeout=180)
    return p


def report():
    with open(f"{T}/state/expiry-watch.json") as fh:
        return json.load(fh)


def by_id(rep):
    return {i["id"]: i for i in rep["items"]}


def mails():
    out = []
    d = f"{T}/mails"
    for f in sorted(os.listdir(d)):
        out.append(open(os.path.join(d, f), encoding="utf-8").read())
    return out


ENV = {}


def main():
    make_ca()
    make_leaf("mail_ok", ["mail.anexomail.test"], 60)
    make_leaf("mail_soon", ["mail.anexomail.test"], 5)
    make_leaf("mail_wrongname", ["other.anexomail.test"], 60)
    make_leaf("web_default", ["default.test"], 90)
    make_leaf("web_ok", ["www.anexomail.test", "anexomail.test", "app.anexomail.test"], 80)
    make_leaf("web_warn", ["app.anexomail.test"], 15)
    make_leaf("web_wrong", ["nothere.test"], 80)

    ports = {}
    serve_tls(ports, "imaps", "tls993")
    serve_tls(ports, "smtp", "smtp")
    serve_tls(ports, "web", "web")
    dns_port = start_dns()
    rdap_port = start_rdap()

    # DKIM key + DNS
    sh("openssl", "genrsa", "-out", f"{T}/dkim.private", "2048")
    sh("openssl", "genrsa", "-out", f"{T}/dkim-other.private", "2048")
    spki = sh("openssl", "pkey", "-in", f"{T}/dkim.private", "-pubout", "-outform", "DER").stdout
    good_p = base64.b64encode(spki).decode()
    other = sh("openssl", "pkey", "-in", f"{T}/dkim-other.private", "-pubout", "-outform", "DER").stdout
    bad_p = base64.b64encode(other).decode()
    os.makedirs(f"{T}/mails")
    with open(f"{T}/KeyTable", "w") as fh:
        fh.write(f"# demo\nmail._domainkey.anexomail.test anexomail.test:mail:{T}/dkim.private\n")
    with open(f"{T}/Caddyfile", "w") as fh:
        fh.write("""{
	email admin@anexomail.test
}
(common) {
	encode gzip
}
www.anexomail.test, anexomail.test {
	reverse_proxy 127.0.0.1:3000
}
app.anexomail.test {
	import common
	handle_path /x/* {
		respond "hi"
	}
}
http://plain.anexomail.test {
	respond "no tls"
}
:8080 {
	respond "port only"
}
*.wild.anexomail.test {
	respond "wildcard skipped"
}
nothere.anexomail.test {
	respond "wrong cert on purpose"
}
""")
    sendmail = f"{T}/fake-sendmail"
    with open(sendmail, "w") as fh:
        fh.write(f'#!/bin/sh\ncat > "{T}/mails/$(date +%s%N).eml"\n')
    os.chmod(sendmail, 0o755)
    os.makedirs(f"{T}/state")

    ENV.update({
        "WATCH_STATE_DIR": f"{T}/state", "ALERT_ENV": f"{T}/none.env", "WATCH_ENV": f"{T}/none2.env",
        "MAILHOST": "mail.anexomail.test", "MAIL_DOMAIN": "anexomail.test",
        "FOUNDER_INBOX": "founder@anexomail.test", "WATCH_SENDMAIL": sendmail,
        "WATCH_CADDYFILE": f"{T}/Caddyfile", "WATCH_WEB_ADDR": f"127.0.0.1:{ports['web']}",
        "WATCH_MAIL_IMAPS": f"127.0.0.1:{ports['imaps']}", "WATCH_MAIL_SMTP": f"127.0.0.1:{ports['smtp']}",
        "WATCH_CA_FILE": T + "/ca.crt", "WATCH_RDAP_BASE": f"http://127.0.0.1:{rdap_port}/domain",
        "DKIM_KEYTABLE": f"{T}/KeyTable", "WATCH_DNS_SERVERS": f"127.0.0.1:{dns_port}",
        "WATCH_CERT_STATUS": f"{T}/state/cert-status.json",
    })

    # ------------- Phase A: sab theek
    SEL.update({"mail993": "mail_ok", "mail587": "mail_ok"})
    WEBCERT.update({"www.anexomail.test": "web_ok", "anexomail.test": "web_ok", "app.anexomail.test": "web_ok",
                    "nothere.anexomail.test": "web_ok"})
    RDAP["anexomail.test"] = iso_in(300)
    ZONE.update({
        ("anexomail.test", "MX"): [(10, "mail.anexomail.test")],
        ("anexomail.test", "TXT"): ["v=spf1 ip4:203.0.113.5 -all"],
        ("_dmarc.anexomail.test", "TXT"): ["v=DMARC1; p=quarantine"],
        ("mail.anexomail.test", "A"): ["203.0.113.5"],
        ("5.113.0.203.in-addr.arpa", "PTR"): ["mail.anexomail.test"],
        ("mail._domainkey.anexomail.test", "TXT"): [f"v=DKIM1; k=rsa; p={good_p}"],
    })
    print("A) healthy")
    p = run()
    check("A) exit 1 (only the deliberately wrong web cert is bad)", p.returncode == 1, p.stdout + p.stderr)
    r = report()
    ids = by_id(r)
    bad = sorted(i["id"] for i in r["items"] if i["status"] != "ok")
    check("A) only web:nothere is bad", bad == ["web:nothere.anexomail.test"], bad)
    check("mail-tls ~60d", ids["mail-tls"]["status"] == "ok" and 58 <= ids["mail-tls"]["days_left"] <= 60, ids["mail-tls"])
    check("headline days", r["headline"]["days_left"] == ids["mail-tls"]["days_left"])
    check("web hosts parsed (www, apex, app, nothere)", all(("web:" + h) in ids for h in
          ["www.anexomail.test", "anexomail.test", "app.anexomail.test", "nothere.anexomail.test"]), sorted(ids))
    check("plain/wildcard/port-only skipped", not any("plain" in k or "wild" in k for k in ids) and not any(k == "web:" for k in ids), sorted(ids))
    check("domain rdap ~300d", ids["domain:anexomail.test"]["status"] == "ok" and 298 <= ids["domain:anexomail.test"]["days_left"] <= 300, ids.get("domain:anexomail.test"))
    check("dkim ok (key matches DNS)", ids["dkim:anexomail.test"]["status"] == "ok", ids["dkim:anexomail.test"])
    check("mx/spf/dmarc/ptr ok", all(ids[k]["status"] == "ok" for k in ("mx", "spf", "dmarc", "ptr")), [ids[k] for k in ("mx", "spf", "dmarc", "ptr")])
    check("A) one crit alert (nothere wrong cert on purpose)", len(mails()) == 1 and "Subject: [ANEXOMAIL URGENT]" in mails()[0], len(mails()))
    # nothere.anexomail.test ko web_ok mila hai (hostname mismatch nahi — SAN www) => crit hona chahiye (verify fail)
    check("wrong-name web cert => crit", ids["web:nothere.anexomail.test"]["status"] == "crit", ids["web:nothere.anexomail.test"])
    check("A) overall crit", r["overall"] == "crit")

    return phase_b(ports, good_p, bad_p)


def phase_b(ports, good_p, bad_p):
    # nothere ko bhi theek karo => A sach mein healthy
    make_leaf("web_nothere", ["nothere.anexomail.test"], 80)
    WEBCERT["nothere.anexomail.test"] = "web_nothere"
    p = run()
    r = report()
    check("A2) healthy now exit 0", p.returncode == 0 and r["overall"] == "ok", p.stdout[-400:] + json.dumps([i for i in r["items"] if i["status"] != "ok"]))
    check("A2) all-clear mail after fix (total 2)", len(mails()) == 2 and "sab theek ho gaya" in mails()[-1], len(mails()))
    p = run()
    check("A2) healthy => silent (no new mail)", len(mails()) == 2, len(mails()))

    print("B) trouble: mail cert 5d, 587 stale, web warn, dkim mismatch, domain 25d, PTR wrong")
    SEL.update({"mail993": "mail_soon", "mail587": "mail_ok"})  # 993 naya-par-chhota, 587 purana => do alag cert
    WEBCERT["app.anexomail.test"] = "web_warn"
    RDAP["anexomail.test"] = iso_in(25)
    ZONE[("mail._domainkey.anexomail.test", "TXT")] = [f"v=DKIM1; k=rsa; p={bad_p}"]
    ZONE[("5.113.0.203.in-addr.arpa", "PTR")] = ["wrong.example.net"]
    # purane RDAP cache ko tod do taake naya 25d dikhe
    st = json.load(open(f"{T}/state/expiry-watch-state.json"))
    st.get("rdap", {})["anexomail.test"]["at"] = 0
    json.dump(st, open(f"{T}/state/expiry-watch-state.json", "w"))
    p = run()
    r = report()
    ids = by_id(r)
    check("exit 1", p.returncode == 1, p.stdout[-300:])
    check("overall crit", r["overall"] == "crit")
    check("mail-tls crit + shows stale mismatch", ids["mail-tls"]["status"] == "crit" and "alag alag" in ids["mail-tls"]["detail"] and ids["mail-tls"]["days_left"] <= 5, ids["mail-tls"])
    check("web app warn (15d)", ids["web:app.anexomail.test"]["status"] == "warn", ids["web:app.anexomail.test"])
    check("domain crit (25d < 30)", ids["domain:anexomail.test"]["status"] == "crit", ids["domain:anexomail.test"])
    check("dkim crit (mismatch)", ids["dkim:anexomail.test"]["status"] == "crit", ids["dkim:anexomail.test"])
    check("ptr warn", ids["ptr"]["status"] == "warn", ids["ptr"])
    m = mails()
    check("exactly 1 new alert mail (total 3)", len(m) == 3, len(m))
    if m:
        body = m[-1]
        if os.environ.get("SHOW"):
            print("-----8<----- sample alert mail\n" + body + "\n-----8<-----")
        check("alert goes to founder", "founder@anexomail.test" in body)
        check("alert subject URGENT", "Subject: [ANEXOMAIL URGENT]" in body, body[:400])
        check("alert lists mail TLS + DKIM + domain", all(k in body for k in ("Mail TLS", "DKIM", "Domain renewal")))
    p = run()
    check("same day => no second mail", len(mails()) == 3, len(mails()))

    print("C) fixed => all-clear mail")
    SEL.update({"mail993": "mail_ok", "mail587": "mail_ok"})
    WEBCERT["app.anexomail.test"] = "web_ok"
    RDAP["anexomail.test"] = iso_in(300)
    ZONE[("mail._domainkey.anexomail.test", "TXT")] = [f"v=DKIM1; k=rsa; p={good_p}"]
    ZONE[("5.113.0.203.in-addr.arpa", "PTR")] = ["mail.anexomail.test"]
    st = json.load(open(f"{T}/state/expiry-watch-state.json"))
    st["rdap"]["anexomail.test"]["at"] = 0
    json.dump(st, open(f"{T}/state/expiry-watch-state.json", "w"))
    p = run()
    check("exit 0 again", p.returncode == 0, p.stdout[-300:])
    m = mails()
    check("all-clear mail sent once (total 4)", len(m) == 4 and "sab theek ho gaya" in m[-1], len(m))
    p = run()
    check("no repeat all-clear", len(mails()) == 4)

    print("D) unknown (DNS down) => no alert at first, alert after 3 runs")
    base = len(mails())
    e = {"WATCH_DNS_SERVERS": "127.0.0.1:9"}  # koi sunne wala nahi
    for n in range(1, 4):
        # DKIM unknown bhi key padh sakta hai par DNS nahi => unknown; MX/SPF/.. unknown
        p = run(e)
        r = report()
        check(f"run {n}: overall unknown not crit", r["overall"] == "unknown", r["overall"])
        if n < 3:
            check(f"run {n}: no mail yet", len(mails()) == base, len(mails()) - base)
    check("run 3: stuck-unknown alert sent", len(mails()) == base + 1 and "check nahi ho pa rahin" in mails()[-1], len(mails()) - base)

    print("E) RDAP down => cached date used, not unknown")
    run()  # DNS wapas theek: all clear
    st = json.load(open(f"{T}/state/expiry-watch-state.json"))
    st["rdap"]["anexomail.test"]["at"] = int(time.time()) - 21 * 3600  # purani par 14 din se kam
    json.dump(st, open(f"{T}/state/expiry-watch-state.json", "w"))
    p = run({"WATCH_RDAP_BASE": "http://127.0.0.1:9/domain"})
    ids = by_id(report())
    check("cached domain still ok with note", ids["domain:anexomail.test"]["status"] == "ok" and "last known" in ids["domain:anexomail.test"]["detail"], ids["domain:anexomail.test"])

    print("F) --dry writes nothing / --test-alert sends full report")
    before = os.path.getmtime(f"{T}/state/expiry-watch.json")
    time.sleep(1.1)
    p = run(args=("--dry",))
    check("dry prints json", '"overall"' in p.stdout)
    check("dry did not write", os.path.getmtime(f"{T}/state/expiry-watch.json") == before)
    n0 = len(mails())
    run(args=("--test-alert",))
    check("test-alert mail sent", len(mails()) == n0 + 1 and "pehla poora haal" in mails()[-1])

    print("G) no DKIM key table => unknown (not silently ok)")
    p = run({"DKIM_KEYTABLE": f"{T}/missing", "DKIM_CONF": f"{T}/missing2"})
    ids = by_id(report())
    check("dkim unknown", ids["dkim:anexomail.test"]["status"] == "unknown", ids.get("dkim:anexomail.test"))

    print("H) 4096-bit-style long TXT over TCP fallback")
    long_p = good_p * 2  # > 512 byte UDP => TC => TCP
    ZONE[("mail._domainkey.anexomail.test", "TXT")] = [f"v=DKIM1; k=rsa; p={long_p}"]
    p = run()
    ids = by_id(report())
    check("TCP fallback worked (mismatch seen, not unknown)", ids["dkim:anexomail.test"]["status"] == "crit", ids["dkim:anexomail.test"])

    shutil.rmtree(T, ignore_errors=True)
    if FAILS:
        print("\nFAILED:", FAILS)
        return 1
    print("\nALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
