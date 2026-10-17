#!/usr/bin/env python3
"""
anexomail-expiry-watch — koi cheez chupke se expire na ho (blueprint 8o).

Asli sabaq (17 Oct 2026): mail TLS cert 2 Nov ko expire hone wala tha aur kisi ko pata nahi tha. Is liye ab ek hi
monitor SAB kuch dekhta hai, din mein 2 baar (systemd timer), aur founder ko email + dashboard tile se batata hai:

  mail-tls     IMAPS 993 + SMTP 587 (STARTTLS) par JO cert abhi live mil raha hai (chain + hostname bhi verify)
  web:<host>   Caddyfile ke har HTTPS host ka live cert (127.0.0.1:443, SNI ke saath)
  domain:<d>   Domain registration ki expiry (RDAP — registry ka apna jawab; cache 20 ghante)
  dkim:<d>     OpenDKIM ki private key se bani public key == DNS TXT (mismatch / missing = crit)
  spf / dmarc / mx / ptr   mail domain ka DNS haal (kisi ne record chupke se hata diya?)

Output: /var/lib/anexomail/expiry-watch.json  (Rust `founder.expiry.watch` yahi file parhta hai).
Alert: sirf email (founder inbox + /etc/anexomail/alert.env ka ALERT_TO), har level din mein ek hi baar; theek hone
par ek "all clear". Jo cheez baar baar "check nahi ho pa rahi" (unknown) wo 3 run baad khud alert banti hai —
yaani monitor ka apna andha-pan bhi chup nahi rehta.

Sirf Python3 stdlib + `openssl` CLI. Koi package install nahi. Root chahiye nahi sirf DKIM key parhne ke liye.

  anexomail-expiry-watch.py              normal run (file likhta hai, zaroorat par alert bhejta hai)
  anexomail-expiry-watch.py --dry        sirf print, kuch likhta/bhejta nahi
  anexomail-expiry-watch.py --test-alert poora haal founder ko email karta hai (install ke waqt, ek baar)

Exit: 0 = sab theek (ya sirf unknown); 1 = warn/crit (systemd `--failed` mein dikhega).
Env overrides: README mein (zyada tar sirf test ke liye).
"""
import base64
import datetime
import json
import math
import os
import random
import re
import smtplib
import socket
import ssl
import struct
import subprocess
import sys
import time
import urllib.error
import urllib.request
from email.message import EmailMessage

NOW = int(time.time())
TODAY = datetime.datetime.fromtimestamp(NOW, datetime.timezone.utc).strftime("%Y-%m-%d")

# --------------------------------------------------------------------------- config
CONF = {}


def _load_env_file(path):
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                m = re.match(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$", line.rstrip("\n"))
                if not m:
                    continue
                v = m.group(2).strip()
                if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
                    v = v[1:-1]
                CONF[m.group(1)] = v
    except OSError:
        pass


def cfg(name, default=""):
    v = os.environ.get(name)
    if v is not None and v != "":
        return v
    return CONF.get(name, default)


_load_env_file(os.environ.get("ALERT_ENV", "/etc/anexomail/alert.env"))
_load_env_file(os.environ.get("WATCH_ENV", "/etc/anexomail/expiry-watch.env"))

STATE_DIR = cfg("WATCH_STATE_DIR", "/var/lib/anexomail")
OUT_FILE = os.path.join(STATE_DIR, "expiry-watch.json")
STATE_FILE = os.path.join(STATE_DIR, "expiry-watch-state.json")
MAILHOST = cfg("MAILHOST", "mail.anexomail.com")
MAIL_DOMAIN = cfg("MAIL_DOMAIN", "anexomail.com")
FOUNDER_INBOX = cfg("FOUNDER_INBOX", "naumansherwani.founder@anexomail.com")
ALERT_TO = cfg("ALERT_TO", "")
SENDMAIL = cfg("WATCH_SENDMAIL", "/usr/sbin/sendmail")
CADDYFILE = cfg("WATCH_CADDYFILE", "/etc/caddy/Caddyfile")
WEB_ADDR = cfg("WATCH_WEB_ADDR", "127.0.0.1:443")
IMAPS_ADDR = cfg("WATCH_MAIL_IMAPS", "127.0.0.1:993")
SMTP_ADDR = cfg("WATCH_MAIL_SMTP", "127.0.0.1:587")
CA_FILE = cfg("WATCH_CA_FILE", "")
RDAP_BASE = cfg("WATCH_RDAP_BASE", "")
CERT_STATUS = cfg("WATCH_CERT_STATUS", os.path.join(STATE_DIR, "cert-status.json"))
KEYTABLE = cfg("DKIM_KEYTABLE", "/etc/opendkim/KeyTable")
OPENDKIM_CONF = cfg("DKIM_CONF", "/etc/opendkim.conf")
UNKNOWN_ALERT_RUNS = int(cfg("WATCH_UNKNOWN_RUNS", "3"))

TLS_WARN, TLS_CRIT = int(cfg("TLS_WARN_DAYS", "21")), int(cfg("TLS_CRIT_DAYS", "7"))
DOM_WARN, DOM_CRIT = int(cfg("DOMAIN_WARN_DAYS", "60")), int(cfg("DOMAIN_CRIT_DAYS", "30"))


def log(msg):
    print("[%s] %s" % (datetime.datetime.now().strftime("%F %T"), msg), flush=True)
    try:
        subprocess.run(["logger", "-t", "anexomail-expiry", msg], timeout=5, check=False)
    except (OSError, subprocess.SubprocessError):
        pass


def iso(epoch):
    return datetime.datetime.fromtimestamp(epoch, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def split_addr(addr, default_port):
    host, _, port = addr.rpartition(":")
    if not host:
        return addr, default_port
    return host, int(port)


def level_for(days, warn, crit):
    if days < crit:
        return "crit"
    if days < warn:
        return "warn"
    return "ok"


ORDER = {"ok": 0, "unknown": 1, "warn": 2, "crit": 3}


def worst(levels):
    levels = list(levels)
    return max(levels, key=lambda x: ORDER[x]) if levels else "ok"


def item(id_, group, label, target, status, detail, days=None, expires=None):
    d = {"id": id_, "group": group, "label": label, "target": target, "status": status, "detail": detail}
    if days is not None:
        d["days_left"] = int(days)
    if expires:
        d["expires_at"] = iso(expires)
    return d


# --------------------------------------------------------------------------- TLS probe
def der_end_epoch(der):
    """DER cert -> notAfter (epoch). openssl CLI se; na ho to None."""
    try:
        pem = ssl.DER_cert_to_PEM_cert(der)
        p = subprocess.run(
            ["openssl", "x509", "-noout", "-enddate"], input=pem, capture_output=True, text=True, timeout=10
        )
        m = re.search(r"notAfter=(.+)", p.stdout)
        if m:
            return int(ssl.cert_time_to_seconds(" ".join(m.group(1).split())))
    except (OSError, subprocess.SubprocessError, ValueError):
        pass
    return None


def _ctx(verify):
    if verify:
        ctx = ssl.create_default_context(cafile=CA_FILE or None)
    else:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    return ctx


def _fetch_der(host, port, sni, mode, ctx):
    """live cert (DER). mode: 'tls' (seedha TLS) ya 'smtp' (STARTTLS). Verify fail par SSLCertVerificationError uthta hai."""
    if mode == "smtp":
        s = smtplib.SMTP(host, port, timeout=15, local_hostname="expiry-watch.local")
        try:
            s.ehlo()
            code, _msg = s.docmd("STARTTLS")
            if code != 220:
                raise smtplib.SMTPException("STARTTLS refused (%s)" % code)
            # smtplib.starttls() hostname ke liye connect-address (127.0.0.1) use karta hai — SNI/hostname verify
            # galat fail hota. Isliye khud wrap: server_hostname = asli mail host.
            ss = ctx.wrap_socket(s.sock, server_hostname=sni)
            try:
                return ss.getpeercert(True)
            finally:
                ss.close()
        finally:
            try:
                s.close()
            except Exception:
                pass
    raw = socket.create_connection((host, port), timeout=15)
    try:
        with ctx.wrap_socket(raw, server_hostname=sni) as ss:
            return ss.getpeercert(True)
    finally:
        try:
            raw.close()
        except OSError:
            pass


def probe_tls(addr, default_port, sni, mode="tls"):
    """-> dict(status_hint, end, days, verify_error, error). Do connection: pehli bina verify (taareekh), phir verify
    (chain + hostname — kya phone/browser isay maanega?)."""
    host, port = split_addr(addr, default_port)
    res = {"end": None, "days": None, "verify_error": "", "error": ""}
    last = None
    for attempt in range(2):  # ek-aadh flake par shor nahi
        try:
            der = _fetch_der(host, port, sni, mode, _ctx(False))
            res["end"] = der_end_epoch(der)
            last = None
            break
        except (OSError, ssl.SSLError, smtplib.SMTPException) as e:
            last = e
            time.sleep(1.5)
    if last is not None:
        res["error"] = "%s: %s" % (type(last).__name__, last)
        return res
    try:
        der = _fetch_der(host, port, sni, mode, _ctx(True))
        if res["end"] is None:
            res["end"] = der_end_epoch(der)
    except ssl.SSLCertVerificationError as e:
        res["verify_error"] = getattr(e, "verify_message", "") or str(e)
    except (OSError, ssl.SSLError, smtplib.SMTPException) as e:
        res["verify_error"] = "%s" % e
    if res["end"] is not None:
        res["days"] = (res["end"] - NOW) // 86400
    return res


def check_mail_tls():
    probes = [("993", probe_tls(IMAPS_ADDR, 993, MAILHOST, "tls")), ("587", probe_tls(SMTP_ADDR, 587, MAILHOST, "smtp"))]
    problems, parts, ends, days_all = [], [], [], []
    status = "ok"
    unknown_only = True
    for port, r in probes:
        if r["error"]:
            parts.append("%s: no answer" % port)
            problems.append("port %s se TLS handshake nahi hua (%s)" % (port, r["error"]))
            status = worst([status, "unknown"])
            continue
        unknown_only = False
        if r["end"] is None:
            parts.append("%s: date unreadable" % port)
            status = worst([status, "unknown"])
            continue
        ends.append(r["end"])
        days_all.append(r["days"])
        parts.append("%s: %sd" % (port, r["days"]))
        status = worst([status, level_for(r["days"], TLS_WARN, TLS_CRIT)])
        if r["verify_error"]:
            status = "crit"
            problems.append("port %s ka cert phone/Outlook ko valid nahi lagega: %s" % (port, r["verify_error"]))
    if len(set(ends)) > 1:
        status = worst([status, "warn"])
        problems.append("993 aur 587 alag alag cert de rahe hain (ek service purana cert pakde hai)")
    try:
        with open(CERT_STATUS, encoding="utf-8") as fh:
            cs = json.load(fh)
        if cs.get("problem"):
            status = worst([status, "warn"])
            problems.append("cert sync monitor: %s" % cs["problem"])
    except (OSError, ValueError):
        pass
    if not days_all:
        return item("mail-tls", "tls", "Mail TLS (IMAP/SMTP)", MAILHOST, "unknown",
                    "Could not reach IMAPS/SMTP locally. " + "; ".join(problems))
    days = min(days_all)
    detail = " · ".join(parts)
    if problems:
        detail += " — " + "; ".join(problems)
    return item("mail-tls", "tls", "Mail TLS (IMAP/SMTP)", MAILHOST, status, detail, days, min(ends) if ends else None)


# --------------------------------------------------------------------------- web hosts (Caddyfile)
HOST_RE = re.compile(r"^(?=.{4,253}$)([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$")


def caddy_hosts(path):
    hosts = []
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            lines = fh.read().splitlines()
    except OSError:
        return hosts
    depth = 0
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if depth == 0 and line.endswith("{") and not line.startswith(("(", "{", "@", "&(")):
            for a in re.split(r"[,\s]+", line[:-1].strip()):
                a = a.strip().lower()
                if not a or a.startswith("http://") or "*" in a or "{" in a or a.startswith(":"):
                    continue
                a = re.sub(r"^https://", "", a)
                a = re.sub(r":\d+$", "", a)
                a = a.rstrip("/")
                if HOST_RE.match(a) and not re.match(r"^\d+\.\d+\.\d+\.\d+$", a) and a not in hosts:
                    hosts.append(a)
        depth += line.count("{") - line.count("}")
        if depth < 0:
            depth = 0
    return hosts


def registrable(host):
    p = host.lower().strip(".").split(".")
    if len(p) <= 2:
        return ".".join(p)
    if len(p[-1]) == 2 and p[-2] in ("co", "com", "org", "net", "gov", "edu", "ac", "ltd", "plc"):
        return ".".join(p[-3:])
    return ".".join(p[-2:])


def check_web(host):
    r = probe_tls(WEB_ADDR, 443, host, "tls")
    label = "Website HTTPS"
    if r["error"]:
        return item("web:" + host, "web", label, host, "unknown", "No answer from the web server on 443 (%s)" % r["error"])
    if r["end"] is None:
        return item("web:" + host, "web", label, host, "unknown", "Certificate date unreadable")
    st = level_for(r["days"], TLS_WARN, TLS_CRIT)
    detail = "%sd left" % r["days"]
    if r["verify_error"]:
        st = "crit"
        detail += " — browsers will not trust it: %s" % r["verify_error"]
    return item("web:" + host, "web", label, host, st, detail, r["days"], r["end"])


# --------------------------------------------------------------------------- RDAP (domain registration expiry)
def _rdap_urls(domain):
    if RDAP_BASE:
        return [RDAP_BASE.rstrip("/") + "/" + domain]
    urls = ["https://rdap.org/domain/" + domain]
    tld = domain.rsplit(".", 1)[-1]
    if tld in ("com", "net"):
        urls.append("https://rdap.verisign.com/%s/v1/domain/%s" % (tld, domain))
    return urls


def rdap_lookup(domain):
    last = "no answer"
    for url in _rdap_urls(domain):
        try:
            req = urllib.request.Request(url, headers={"Accept": "application/rdap+json", "User-Agent": "anexomail-expiry-watch/1"})
            with urllib.request.urlopen(req, timeout=20) as r:
                data = json.loads(r.read().decode("utf-8", "replace"))
            exp = None
            for ev in data.get("events", []) or []:
                if str(ev.get("eventAction", "")).lower() == "expiration":
                    exp = ev.get("eventDate")
            if not exp:
                last = "RDAP has no expiration date for this domain"
                continue
            dt = datetime.datetime.fromisoformat(exp.replace("Z", "+00:00"))
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=datetime.timezone.utc)
            return {"expires": int(dt.timestamp()), "status": [str(s) for s in (data.get("status") or [])]}, ""
        except urllib.error.HTTPError as e:
            last = "RDAP HTTP %s" % e.code
        except (OSError, ValueError, urllib.error.URLError) as e:
            last = "RDAP: %s" % e
    return None, last


def check_domain(domain, state):
    cache = state.setdefault("rdap", {})
    c = cache.get(domain)
    info, why = (None, "")
    if c and NOW - c.get("at", 0) < 20 * 3600:
        info, why = {"expires": c["expires"], "status": c.get("status", [])}, ""
        cached = True
    else:
        info, why = rdap_lookup(domain)
        cached = False
        if info:
            cache[domain] = {"at": NOW, "expires": info["expires"], "status": info["status"]}
        elif c and NOW - c.get("at", 0) < 14 * 86400:
            info, cached = {"expires": c["expires"], "status": c.get("status", [])}, True
            why = "lookup failed (%s) — showing last known date" % why
    label = "Domain renewal"
    if not info:
        return item("domain:" + domain, "domain", label, domain, "unknown",
                    "Could not read the expiry date (%s). Check it at your registrar." % why)
    days = (info["expires"] - NOW) // 86400
    st = level_for(days, DOM_WARN, DOM_CRIT)
    detail = "expires %s (%sd)" % (iso(info["expires"])[:10], days)
    bad = [s for s in info["status"] if any(k in s.lower() for k in ("pending delete", "redemption", "hold"))]
    if bad:
        st = "crit"
        detail += " — registry status: " + ", ".join(bad)
    if why and not cached:
        detail += " — " + why
    elif why:
        detail += " — " + why
    return item("domain:" + domain, "domain", label, domain, st, detail, days, info["expires"])


# --------------------------------------------------------------------------- DNS (raw, stdlib)
QT = {"A": 1, "PTR": 12, "MX": 15, "TXT": 16}


def dns_servers():
    s = cfg("WATCH_DNS_SERVERS", "")
    if s:
        return s.split()
    out = ["1.1.1.1", "8.8.8.8"]
    try:
        with open("/etc/resolv.conf", encoding="utf-8") as fh:
            for line in fh:
                p = line.split()
                if len(p) >= 2 and p[0] == "nameserver" and ":" not in p[1] and p[1] not in out:
                    out.append(p[1])
    except OSError:
        pass
    return out


def _name(msg, off):
    labels, end, hops = [], None, 0
    while True:
        ln = msg[off]
        if ln == 0:
            off += 1
            break
        if ln & 0xC0 == 0xC0:
            if end is None:
                end = off + 2
            off = ((ln & 0x3F) << 8) | msg[off + 1]
            hops += 1
            if hops > 20:
                raise ValueError("dns pointer loop")
            continue
        off += 1
        labels.append(msg[off : off + ln].decode("ascii", "replace"))
        off += ln
    return ".".join(labels), (end if end is not None else off)


def _parse(msg, qid):
    rid, flags, qd, an, _ns, _ar = struct.unpack("!6H", msg[:12])
    if rid != qid:
        raise ValueError("dns id mismatch")
    off = 12
    for _ in range(qd):
        _n, off = _name(msg, off)
        off += 4
    out = []
    for _ in range(an):
        _n, off = _name(msg, off)
        t, _c, _ttl, rdlen = struct.unpack("!HHIH", msg[off : off + 10])
        off += 10
        rd = msg[off : off + rdlen]
        if t == 16:
            strs, i = [], 0
            while i < len(rd):
                ln = rd[i]
                strs.append(rd[i + 1 : i + 1 + ln].decode("utf-8", "replace"))
                i += 1 + ln
            out.append(("TXT", "".join(strs)))
        elif t == 15:
            pref = struct.unpack("!H", rd[:2])[0]
            nm, _ = _name(msg, off + 2)
            out.append(("MX", (pref, nm.lower())))
        elif t == 12:
            nm, _ = _name(msg, off)
            out.append(("PTR", nm.lower()))
        elif t == 1 and rdlen == 4:
            out.append(("A", socket.inet_ntoa(rd)))
        off += rdlen
    return flags & 0xF, bool(flags & 0x200), out


def dns_query(name, qtype):
    """-> (rcode|None, [values]). rcode None = koi server ne jawab nahi diya (unknown)."""
    qid = random.randint(1, 65535)
    q = struct.pack("!6H", qid, 0x0100, 1, 0, 0, 0)
    for lab in name.strip(".").split("."):
        q += bytes([len(lab)]) + lab.encode("ascii")
    q += b"\x00" + struct.pack("!2H", QT[qtype], 1)
    for srv in dns_servers():
        host, port = split_addr(srv, 53) if ":" in srv else (srv, 53)
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as u:
                u.settimeout(4)
                u.sendto(q, (host, port))
                data, _ = u.recvfrom(4096)
            rcode, tc, ans = _parse(data, qid)
            if tc:
                with socket.create_connection((host, port), timeout=5) as t:
                    t.sendall(struct.pack("!H", len(q)) + q)
                    ln = struct.unpack("!H", t.recv(2))[0]
                    buf = b""
                    while len(buf) < ln:
                        chunk = t.recv(ln - len(buf))
                        if not chunk:
                            break
                        buf += chunk
                rcode, _tc, ans = _parse(buf, qid)
            if rcode in (0, 3):
                return rcode, [v for t_, v in ans if t_ == qtype]
        except (OSError, ValueError, struct.error, IndexError):
            continue
    return None, []


def txt(name):
    rc, vals = dns_query(name, "TXT")
    return rc, vals


# --------------------------------------------------------------------------- DKIM
def dkim_entries():
    out = []
    try:
        with open(KEYTABLE, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                p = line.split()
                if len(p) < 2 or p[1].count(":") < 2:
                    continue
                d, sel, path = p[1].split(":", 2)
                if "%" in d or "%" in sel:
                    m = re.match(r"^(.+?)\._domainkey\.(.+)$", p[0])
                    if not m:
                        continue
                    sel, d = (m.group(1), m.group(2))
                out.append((d.lower(), sel, path))
    except OSError:
        pass
    if out:
        return out[:100]
    try:  # chhota setup: opendkim.conf mein Domain/Selector/KeyFile
        conf = {}
        with open(OPENDKIM_CONF, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                m = re.match(r"^\s*(Domain|Selector|KeyFile)\s+(\S+)", line)
                if m:
                    conf[m.group(1)] = m.group(2)
        if all(k in conf for k in ("Domain", "Selector", "KeyFile")):
            out.append((conf["Domain"].lower(), conf["Selector"], conf["KeyFile"]))
    except OSError:
        pass
    return out


def key_spki_b64(path):
    try:
        p = subprocess.run(["openssl", "pkey", "-in", path, "-pubout", "-outform", "DER"], capture_output=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return None, "openssl nahi chala"
    if p.returncode != 0 or not p.stdout:
        return None, "private key padh nahi saka (%s)" % (p.stderr.decode("utf-8", "replace").strip()[:80] or "permission?")
    return p.stdout, ""


def check_dkim(domain, selector, keyfile):
    iid = "dkim:%s" % domain
    label = "DKIM signing key"
    spki, why = key_spki_b64(keyfile)
    if spki is None:
        return item(iid, "dkim", label, "%s._domainkey.%s" % (selector, domain), "unknown", "Key at %s: %s" % (keyfile, why))
    name = "%s._domainkey.%s" % (selector, domain)
    rc, vals = txt(name)
    if rc is None:
        return item(iid, "dkim", label, name, "unknown", "DNS did not answer")
    recs = [v for v in vals if "p=" in v.replace(" ", "")]
    if not recs:
        return item(iid, "dkim", label, name, "crit", "No DKIM record in DNS — mail will fail DKIM checks")
    tags = dict(
        (k.strip().lower(), v.strip()) for k, _, v in (t.partition("=") for t in recs[0].replace(" ", "").split(";") if "=" in t)
    )
    p = re.sub(r"\s+", "", tags.get("p", ""))
    if not p:
        return item(iid, "dkim", label, name, "crit", "DKIM key in DNS is revoked (empty p=)")
    ktype = tags.get("k", "rsa").lower()
    if ktype == "ed25519":
        try:
            match = spki[-len(base64.b64decode(p)) :] == base64.b64decode(p)
        except ValueError:
            match = False
    else:
        match = base64.b64encode(spki).decode() == p
    age = ""
    try:
        age = " · key age %sd" % int((NOW - os.stat(keyfile).st_mtime) // 86400)
    except OSError:
        pass
    if not match:
        return item(iid, "dkim", label, name, "crit", "DNS public key does not match the server's signing key — signed mail fails DKIM" + age)
    return item(iid, "dkim", label, name, "ok", "DNS matches the signing key" + age)


# --------------------------------------------------------------------------- mail DNS health
def check_mail_dns():
    out = []
    # MX
    rc, mx = dns_query(MAIL_DOMAIN, "MX")
    if rc is None:
        out.append(item("mx", "dns", "MX record", MAIL_DOMAIN, "unknown", "DNS did not answer"))
    elif not mx:
        out.append(item("mx", "dns", "MX record", MAIL_DOMAIN, "crit", "No MX record — nobody can email this domain"))
    else:
        names = [n for _p, n in sorted(mx)]
        ok_ = any(n.rstrip(".") == MAILHOST.lower() for n in names)
        out.append(item("mx", "dns", "MX record", MAIL_DOMAIN, "ok" if ok_ else "warn",
                        ("points to " + ", ".join(names)) + ("" if ok_ else " — not the mail server %s" % MAILHOST)))
    # SPF
    rc, t = txt(MAIL_DOMAIN)
    if rc is None:
        out.append(item("spf", "dns", "SPF record", MAIL_DOMAIN, "unknown", "DNS did not answer"))
    else:
        spf = [v for v in t if v.lower().startswith("v=spf1")]
        if len(spf) == 1:
            out.append(item("spf", "dns", "SPF record", MAIL_DOMAIN, "ok", "present"))
        elif not spf:
            out.append(item("spf", "dns", "SPF record", MAIL_DOMAIN, "warn", "No SPF record — receivers may treat mail as spam"))
        else:
            out.append(item("spf", "dns", "SPF record", MAIL_DOMAIN, "crit", "%d SPF records — that is invalid, SPF fails" % len(spf)))
    # DMARC
    rc, t = txt("_dmarc." + MAIL_DOMAIN)
    if rc is None:
        out.append(item("dmarc", "dns", "DMARC record", MAIL_DOMAIN, "unknown", "DNS did not answer"))
    else:
        dm = [v for v in t if v.lower().startswith("v=dmarc1")]
        out.append(item("dmarc", "dns", "DMARC record", MAIL_DOMAIN, "ok" if dm else "warn",
                        "present" if dm else "No DMARC record — Gmail/Yahoo want one"))
    # PTR (reverse DNS) — Gmail bina PTR ke mail reject karta hai
    rc, a = dns_query(MAILHOST, "A")
    if rc is None:
        out.append(item("ptr", "dns", "Reverse DNS (PTR)", MAILHOST, "unknown", "DNS did not answer"))
    elif not a:
        out.append(item("ptr", "dns", "Reverse DNS (PTR)", MAILHOST, "crit", "%s has no A record" % MAILHOST))
    else:
        ip = a[0]
        rev = ".".join(reversed(ip.split("."))) + ".in-addr.arpa"
        rc, ptr = dns_query(rev, "PTR")
        if rc is None:
            out.append(item("ptr", "dns", "Reverse DNS (PTR)", ip, "unknown", "DNS did not answer"))
        elif any(p.rstrip(".") == MAILHOST.lower() for p in ptr):
            out.append(item("ptr", "dns", "Reverse DNS (PTR)", ip, "ok", "%s → %s" % (ip, MAILHOST)))
        else:
            out.append(item("ptr", "dns", "Reverse DNS (PTR)", ip, "warn",
                            "%s resolves to %s, not %s (set it in the Hetzner panel)" % (ip, ", ".join(ptr) or "nothing", MAILHOST)))
    return out


# --------------------------------------------------------------------------- state + alerts
def load_state():
    try:
        with open(STATE_FILE, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def save_json_atomic(path, obj):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(obj, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    os.chmod(tmp, 0o644)
    os.replace(tmp, path)


GROUP_FIX = {
    "tls": "Mail TLS: systemctl start anexomail-mail-cert.service ; journalctl -u anexomail-mail-cert.service -n 40 --no-pager ; cat /var/lib/anexomail/cert-status.json",
    "web": "Website cert: journalctl -u caddy --no-pager | grep -iE 'obtain|renew|error' | tail -20 ; Caddyfile mein host ka block aur DNS (A record) check karein.",
    "domain": "Domain renewal: registrar (Namecheap/GoDaddy/…) mein login karke renew karein aur auto-renew ON rakhein. Expiry ke baad domain bikne/parked hone lagta hai.",
    "dkim": "DKIM: DNS TXT <selector>._domainkey.<domain> mein server ki public key dobara daalein (opendkim-genkey ke .txt se) ya Claude ko yeh output bhejein.",
    "dns": "Mail DNS: DNS panel mein record wapas daalein (MX/SPF/DMARC), PTR Hetzner panel mein set hota hai.",
}


def send_mail(subject, body):
    to = [x for x in re.split(r"[,\s]+", FOUNDER_INBOX + " " + ALERT_TO) if x]
    msg = EmailMessage()
    msg["From"] = "ANEXOMAIL Monitor <monitor@anexomail.com>"
    msg["To"] = ", ".join(to)
    msg["Subject"] = subject
    msg["Date"] = datetime.datetime.now(datetime.timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")
    msg["X-Priority"] = "1"
    msg.set_content(body)
    try:
        subprocess.run([SENDMAIL, "-t", "-f", "monitor@anexomail.com"], input=msg.as_bytes(), check=True, timeout=30)
        return True
    except (OSError, subprocess.SubprocessError) as e:
        log("ALERT email bhejna fail (%s): %s" % (SENDMAIL, e))
        return False


def fmt_item(it):
    d = ""
    if "days_left" in it:
        d = " [%s din]" % it["days_left"]
    return "  [%s] %s — %s%s\n        %s" % (it["status"].upper(), it["label"], it["target"], d, it["detail"])


def build_body(items, intro):
    bad = [i for i in items if i["status"] != "ok"]
    lines = [intro, ""]
    if bad:
        lines.append("Dhyan talab cheezein:")
        lines += [fmt_item(i) for i in sorted(bad, key=lambda x: -ORDER[x["status"]])]
        lines.append("")
        lines.append("Kya karna hai:")
        for g in sorted({i["group"] for i in bad}):
            lines.append("  - " + GROUP_FIX.get(g, g))
    ok = [i for i in items if i["status"] == "ok"]
    if ok:
        lines += ["", "Theek cheezein: " + ", ".join("%s (%s)" % (i["label"], i["target"]) for i in ok)]
    lines += ["", "Poora haal server par: cat /var/lib/anexomail/expiry-watch.json  (founder dashboard par bhi dikhta hai).",
              "Monitor din mein 2 baar chalta hai (03:47 / 15:47 server ka waqt). Har level ki alert din mein ek hi baar."]
    return "\n".join(lines)


def alerts(items, overall, state, test):
    state.setdefault("unknown_runs", {})
    ur = state["unknown_runs"]
    for it in items:
        if it["status"] == "unknown":
            ur[it["id"]] = ur.get(it["id"], 0) + 1
        else:
            ur.pop(it["id"], None)
    for k in [k for k in ur if k not in {i["id"] for i in items}]:
        ur.pop(k)
    stuck = [i for i in items if i["status"] == "unknown" and ur.get(i["id"], 0) >= UNKNOWN_ALERT_RUNS]
    crit = [i for i in items if i["status"] == "crit"]
    warn = [i for i in items if i["status"] == "warn"]
    level = "crit" if crit else ("warn" if (warn or stuck) else "")
    sent = state.setdefault("alert_day", {})
    if test:
        send_mail("[ANEXOMAIL] Expiry watch chalu hai — pehla poora haal",
                  build_body(items, "Yeh install ke waqt ka test/pehla report hai: agar yeh email aap ko mili to alert ka rasta theek hai.\nHaal: %s." % overall.upper()))
    if level:
        if sent.get(level) != TODAY:
            subj = {
                "crit": "[ANEXOMAIL URGENT] %d cheez expire / kharab — abhi dekhein" % (len(crit)),
                "warn": "[ANEXOMAIL] Expiry watch: %d cheez dhyan talab" % (len(warn) + len(stuck)),
            }[level]
            intro = "Expiry watch ne yeh paaya (%s):" % iso(NOW)
            if stuck and not crit and not warn:
                intro += "\nSirf yeh cheezein baar baar check nahi ho pa rahin — monitor andha hai, isay theek karna hai:"
            if send_mail(subj, build_body(items, intro)):
                sent[level] = TODAY
                state["alerted"] = level
    elif state.get("alerted"):
        if send_mail("[ANEXOMAIL] Expiry watch: sab theek ho gaya", build_body(items, "Pehle ki alert wali sab cheezein ab theek hain.")):
            state["alerted"] = ""
            state["alert_day"] = {}
    return level


# --------------------------------------------------------------------------- main
def main(argv):
    dry = "--dry" in argv
    test = "--test-alert" in argv
    state = {} if dry else load_state()
    items = [check_mail_tls()]

    skip_web = set(cfg("WATCH_SKIP_WEB_HOSTS", "").split())
    hosts = caddy_hosts(CADDYFILE)
    for h in cfg("WATCH_WEB_HOSTS", "").split():
        if h not in hosts:
            hosts.append(h)
    hosts = [h for h in hosts if h not in skip_web]
    for h in hosts:
        items.append(check_web(h))

    domains = [registrable(MAILHOST), MAIL_DOMAIN] + [registrable(h) for h in hosts] + cfg("WATCH_DOMAINS", "").split()
    skip_dom = set(cfg("WATCH_SKIP_DOMAINS", "").split())
    seen = []
    for d in domains:
        d = d.lower().strip(".")
        if d and d not in seen and d not in skip_dom and HOST_RE.match(d):
            seen.append(d)
    for d in seen:
        items.append(check_domain(d, state))

    dk = dkim_entries()
    if dk:
        for d, sel, path in dk:
            items.append(check_dkim(d, sel, path))
    else:
        items.append(item("dkim:%s" % MAIL_DOMAIN, "dkim", "DKIM signing key", MAIL_DOMAIN, "unknown",
                          "OpenDKIM key table not found (%s) — set DKIM_KEYTABLE in %s" % (KEYTABLE, cfg("WATCH_ENV", "/etc/anexomail/expiry-watch.env"))))
    items += check_mail_dns()

    overall = worst(i["status"] for i in items)
    mail = next((i for i in items if i["id"] == "mail-tls"), None)
    report = {
        "version": 1,
        "checked_at": iso(NOW),
        "overall": overall,
        "headline": {"id": "mail-tls", "label": "Mail TLS", "days_left": mail.get("days_left") if mail else None,
                     "status": mail["status"] if mail else "unknown"},
        "items": items,
    }
    if dry:
        print(json.dumps(report, ensure_ascii=False, indent=1))
        return 0 if overall in ("ok", "unknown") else 1
    os.makedirs(STATE_DIR, exist_ok=True)
    level = alerts(items, overall, state, test)
    save_json_atomic(STATE_FILE, state)
    save_json_atomic(OUT_FILE, report)
    log("haal: overall=%s items=%d alert_level=%s" % (overall, len(items), level or "-"))
    return 0 if overall in ("ok", "unknown") else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
