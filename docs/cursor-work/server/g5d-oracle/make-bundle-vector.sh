#!/usr/bin/env bash
# G5d oracle: a COMPLETE portable bundle made by independent tools, so the browser WASM kernel module `portable@1` is judged against bytes it did not write:
#   * Ed25519 key + signatures: Python `cryptography` (OpenSSL), C2SP signed-note layout written here from the spec;
#   * RFC 9162 tree + consistency proof: the Python reference `g5a-reference.py` (step-by-step spec transcription), never the Rust code;
#   * RFC 3161 time-stamp replies: two real OpenSSL `openssl ts` TSAs (an RSA key and a P-256 key) over sha256(horizon note).
# Output: server/rust/g5d_kernel_vector.json  {"generator", "good": {"text", "sha"}, "facts": {...}}. Run in a sandbox with OpenSSL 3.x + python3-cryptography; the server never runs this.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"; OUT="${1:-$ROOT/server/rust/g5d_kernel_vector.json}"; T="$(mktemp -d)"; cd "$T"; echo 1000 > tsaserial
mk() { # name keyspec digestalg
  local n="$1" ks="$2" da="$3"
  openssl req -x509 -newkey "$ks" -nodes -keyout "$n.key" -out "$n.crt" -days 3650 -subj "/CN=G5d Test TSA $n/O=ANEXOMAIL oracle" -addext "extendedKeyUsage=critical,timeStamping" -addext "keyUsage=critical,digitalSignature" 2>/dev/null
  cat > "$n.cnf" <<EOT
[ tsa ]
default_tsa = t
[ t ]
dir = .
serial = ./tsaserial
crypto_device = builtin
signer_cert = ./$n.crt
certs = ./$n.crt
signer_key = ./$n.key
signer_digest = $da
default_policy = 1.2.3.4.1
other_policies = 1.2.3.4.5
digests = sha256, sha384, sha512
accuracy = secs:1
ordering = yes
tsa_name = yes
ess_cert_id_chain = no
ess_cert_id_alg = sha256
EOT
}
mk tsa_rsa rsa:2048 sha256; mk tsa_ec ec:<(openssl ecparam -name prime256v1) sha256
export G5A_REF="$ROOT/docs/cursor-work/server/g5a-reference.py" OUT
python3 - <<'PY'
import hashlib, json, os, subprocess, re, base64, time, calendar, importlib.util
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization
spec = importlib.util.spec_from_file_location("g5a", os.environ["G5A_REF"]); g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
H = g.H; run = lambda *a, inp=None: subprocess.run(a, check=True, capture_output=True, input=inp).stdout
ORIGIN = "g5d-oracle.example/audit-log"
sk = Ed25519PrivateKey.from_private_bytes(H(b"g5d oracle audit-log key seed")); pub = sk.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
kid = H(ORIGIN.encode() + b"\n\x01" + pub)[:4]
leaves = [g.leaf(H(("g5d kernel vector %d" % i).encode())) for i in range(1, 10)]
def note(size):
    root = g.mth(leaves[:size]); body = "%s\n%d\n%s\n" % (ORIGIN, size, base64.b64encode(root).decode())
    sig = sk.sign(body.encode()); return body + "\n— %s %s\n" % (ORIGIN, base64.b64encode(kid + sig).decode()), root
HS, DS = 4, 9
hnote, hroot = note(HS); dnote, droot = note(DS)
digest = hashlib.sha256(hnote.encode()).hexdigest()
now_ms = int(time.time() * 1000); ev = []
for name, prov in (("tsa_rsa", "oracle-tsa-rsa"), ("tsa_ec", "oracle-tsa-ec")):
    run("openssl", "ts", "-query", "-digest", digest, "-sha256", "-cert", "-out", name + ".tsq"); run("openssl", "ts", "-reply", "-queryfile", name + ".tsq", "-config", name + ".cnf", "-out", name + ".tsr")
    r = run("openssl", "ts", "-reply", "-in", name + ".tsr", "-text").decode(); gen = re.search(r"Time stamp: (.+)", r).group(1).strip()
    gen_ms = int(calendar.timegm(time.strptime(re.sub(r"\s+", " ", gen).replace(" GMT", ""), "%b %d %H:%M:%S %Y")) * 1000)
    spki = run("openssl", "x509", "-in", name + ".crt", "-pubkey", "-noout"); pin = hashlib.sha256(run("openssl", "pkey", "-pubin", "-outform", "DER", inp=spki)).hexdigest()
    ev.append({"kind": "rfc3161", "stage": "tsa_token", "provider": prov, "version": 1, "evidence_hex": open(name + ".tsr", "rb").read().hex(), "parsed": {"gen_time_ms": gen_ms, "signer_pin": pin}})
gens = [e["parsed"]["gen_time_ms"] for e in ev]
signed_ms = min(gens) - 5000
pr = g.proof(leaves, HS, DS); assert g.verify(HS, DS, g.mth(leaves[:HS]), g.mth(leaves[:DS]), pr)
bundle = {"v": 1,
  "horizon": {"found": True, "cp_id": 2, "size": HS, "root": hroot.hex(), "origin": ORIGIN, "note": hnote, "signed_ms": signed_ms, "key_id": 1, "tsa": 2, "bitcoin": 0, "anchored_ms": min(gens),
              "first_signed_cp": 1, "skipped": 1, "min_tsa": 2, "digest_hex": digest, "evidence": ev},
  "head": {"cp_id": 3, "size": DS, "root": droot.hex(), "origin": ORIGIN, "note": dnote, "signed_ms": signed_ms + 60000, "key_id": 1},
  "keys": [{"id": 1, "name": ORIGIN, "status": "active", "pub_hex": pub.hex(), "key_id_hex": kid.hex()}],
  "proof": {"first": HS, "second": DS, "first_root": hroot.hex(), "second_root": droot.hex(), "proof": [x.hex() for x in pr], "rule": "RFC 9162 2.1.4"}, "proof_problem": None}
text = json.dumps(bundle, sort_keys=True, ensure_ascii=False)
json.dump({"generator": "ed25519: python-cryptography; tree+proof: g5a-reference.py; TSA: openssl ts (RSA + P-256)", "good": {"text": text, "sha": hashlib.sha256(text.encode()).hexdigest()},
           "facts": {"horizon_cp": 2, "head_cp": 3, "horizon_size": HS, "head_size": DS, "origin": ORIGIN, "pub_hex": pub.hex(), "tsa": 2, "anchored_ms": min(gens), "proof_hashes": len(pr)}}, open(os.environ["OUT"], "w"), indent=1)
print("wrote", os.environ["OUT"])
PY
rm -rf "$T"
