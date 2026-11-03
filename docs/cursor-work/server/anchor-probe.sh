#!/usr/bin/env bash
# anchor-probe.sh — G5c repair, step 1: READ-ONLY look at what the outside time services REALLY answer (founder 3 Nov 05:20: "yeh 4 points read kero likho aur theek kero").
# Why: the live server has 12 dead anchoring jobs. Three OpenTimestamps calendars end in "calendar commitment is not 32 bytes" and freetsa ends in "unsupported ECDSA curve/hash pair".
# The sandbox that wrote the code cannot reach these services (403 on the tunnel), so the fix must be written against REAL bytes, not memory. This script only asks the services about a
# RANDOM digest (not a ledger digest), prints what came back, and writes nothing: no database, no ledger, no key, no file outside a temp dir that is deleted at the end.
# Usage: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/anchor-probe.sh) 2>&1 | tail -80
set -u
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
echo "== A) OpenTimestamps calendars: reply to a random digest"
for cal in https://alice.btc.calendar.opentimestamps.org https://bob.btc.calendar.opentimestamps.org https://finney.calendar.eternitywall.com; do
  head -c 32 /dev/urandom > "$T/d.bin"
  code=$(curl -s -m 20 -o "$T/r.bin" -w '%{http_code}' -X POST -H 'Accept: application/vnd.opentimestamps.v1' -H 'Content-Type: application/x-www-form-urlencoded' --data-binary @"$T/d.bin" "$cal/digest" 2>/dev/null || echo 000)
  echo "-- $cal  http=$code  bytes=$(wc -c < "$T/r.bin" 2>/dev/null || echo 0)"
  [ "$code" = 200 ] && python3 - "$T/d.bin" "$T/r.bin" <<'PY'
import sys, hashlib
d = open(sys.argv[1], 'rb').read(); b = open(sys.argv[2], 'rb').read()
print("   reply hex (first 160 bytes):", b[:160].hex())
def varuint(b, i):
    n = 0; s = 0
    while True:
        x = b[i]; i += 1; n |= (x & 0x7f) << s; s += 7
        if not x & 0x80: return n, i
def varbytes(b, i):
    n, i = varuint(b, i); return b[i:i+n], i + n
leaves = []
def parse(b, i, msg, trace):
    while True:
        tag = b[i]; i += 1; more = False
        if tag == 0xff: more = True; tag = b[i]; i += 1
        if tag == 0x00:
            att = b[i:i+8]; i += 8; payload, i = varbytes(b, i)
            leaves.append((len(msg), msg.hex(), att.hex(), payload, trace[:]))
        else:
            t2 = trace[:]
            if tag == 0x08: nm = hashlib.sha256(msg).digest(); t2.append("sha256")
            elif tag == 0xf0: a, i = varbytes(b, i); nm = msg + a; t2.append("append%d" % len(a))
            elif tag == 0xf1: a, i = varbytes(b, i); nm = a + msg; t2.append("prepend%d" % len(a))
            elif tag == 0xf2: nm = msg[::-1]; t2.append("reverse")
            elif tag == 0xf3: nm = msg.hex().encode(); t2.append("hexlify")
            else: raise SystemExit("   unknown op tag %02x at %d" % (tag, i - 1))
            i = parse(b, i, nm, t2)
        if not more: break
    return i
try:
    end = parse(b, 0, d, [])
    print("   parsed %d of %d bytes, %d leaf(s)" % (end, len(b), len(leaves)))
    for ln, mh, att, payload, tr in leaves:
        print("   LEAF message_len=%d attestation=%s payload=%r" % (ln, att, payload[:80]))
        print("        message=%s" % mh[:140])
        print("        ops=%s" % " > ".join(tr))
except Exception as e:
    print("   could not parse:", repr(e))
PY
done
echo
echo "== B) Time-Stamp Authorities: which signature algorithm do they REALLY use (a random digest is stamped)"
for spec in "freetsa|https://freetsa.org/tsr" "digicert-tsa|http://timestamp.digicert.com" "sectigo-tsa|http://timestamp.sectigo.com"; do
  name="${spec%%|*}"; url="${spec#*|}"
  head -c 64 /dev/urandom > "$T/m.bin"
  openssl ts -query -data "$T/m.bin" -sha256 -cert -out "$T/q.tsq" 2>/dev/null
  code=$(curl -s -m 25 -o "$T/r.tsr" -w '%{http_code}' -H 'Content-Type: application/timestamp-query' --data-binary @"$T/q.tsq" "$url" 2>/dev/null || echo 000)
  echo "-- $name $url  http=$code  bytes=$(wc -c < "$T/r.tsr" 2>/dev/null || echo 0)"
  if [ "$code" = 200 ]; then
    openssl ts -reply -in "$T/r.tsr" -text 2>/dev/null | grep -E 'Status:|Hash Algorithm|Policy OID|Time stamp:' | sed 's/^/   /'
    openssl ts -reply -in "$T/r.tsr" -token_out -out "$T/tok.der" 2>/dev/null
    openssl pkcs7 -inform DER -in "$T/tok.der" -print_certs -out "$T/certs.pem" 2>/dev/null
    awk '/BEGIN CERT/{n++} {print > "'"$T"'/c" n ".pem"}' "$T/certs.pem" 2>/dev/null
    for c in "$T"/c1.pem; do [ -s "$c" ] && openssl x509 -in "$c" -noout -text 2>/dev/null | grep -E 'Signature Algorithm|Public Key Algorithm|NIST CURVE|ASN1 OID|Public-Key' | sort -u | sed 's/^/   cert: /'; done
    echo "   signerInfo algorithm OIDs inside the token:"
    openssl asn1parse -inform DER -in "$T/tok.der" 2>/dev/null | grep -E 'OBJECT' | grep -E 'ecdsa|sha|rsa|prime' | sort | uniq -c | sed 's/^/     /' | head -8
  fi
done
echo
echo "DONE: only the services were asked; nothing was written. Paste ALL of this output."
