#!/usr/bin/env bash
# G5c oracle: REAL RFC 3161 time-stamp replies made by an independent implementation (OpenSSL `openssl ts` acting as a TSA), so the Rust parser/verifier
# is judged against bytes it did not write. Output: g5c_tsa_vectors.json (hex). Run in a sandbox with OpenSSL 3.x; the server never runs this.
set -euo pipefail
OUT="${1:-$(cd "$(dirname "$0")" && pwd)/g5c_tsa_vectors.json}"; T="$(mktemp -d)"; cd "$T"
echo 1000 > tsaserial
mk() { # name keyspec digestalg
  local n="$1" ks="$2" da="$3"
  openssl req -x509 -newkey "$ks" -nodes -keyout "$n.key" -out "$n.crt" -days 3650 -subj "/CN=G5c Test TSA $n/O=ANEXOMAIL oracle" -addext "extendedKeyUsage=critical,timeStamping" -addext "keyUsage=critical,digitalSignature" -sha256 2>/dev/null
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
# G5c: the original set (default). R2 (3 Nov): G5C_SET=r2 adds the P-384 pairs real TSAs use (freetsa = P-384 key + ecdsa-with-SHA512), made by the same independent OpenSSL.
if [ "${G5C_SET:-base}" = "r2" ]; then
  mk ec384x512 ec:<(openssl ecparam -name secp384r1) sha512; mk ec384x384 ec:<(openssl ecparam -name secp384r1) sha384; mk ec256x512 ec:<(openssl ecparam -name prime256v1) sha512
  SET='[("ec384x512", "ec", "sha256"), ("ec384x384", "ec", "sha256"), ("ec256x512", "ec", "sha256")]'
else
  mk rsa256 rsa:2048 sha256; mk rsa512 rsa:3072 sha512; mk ec256 ec:<(openssl ecparam -name prime256v1) sha256
  SET='[("rsa256", "rsa", "sha256"), ("rsa512", "rsa", "sha256"), ("ec256", "ec", "sha256")]'
fi
export SET
python3 - "$OUT" <<'PY'
import subprocess, json, sys, hashlib, re, os
out = sys.argv[1]; vecs = []
def run(*a, inp=None): return subprocess.run(a, check=True, capture_output=True, input=inp).stdout
for n, alg, hashname in eval(os.environ["SET"]):
    for k in range(2):
        data = f"g5c oracle {n} {k}".encode(); digest = hashlib.sha256(data).hexdigest()
        run("openssl", "ts", "-query", "-digest", digest, "-sha256", "-cert", "-out", f"{n}.tsq")
        run("openssl", "ts", "-reply", "-queryfile", f"{n}.tsq", "-config", f"{n}.cnf", "-out", f"{n}.tsr")
        q = run("openssl", "ts", "-query", "-in", f"{n}.tsq", "-text").decode(); r = run("openssl", "ts", "-reply", "-in", f"{n}.tsr", "-text").decode()
        nonce = re.search(r"Nonce: 0x([0-9A-Fa-f]+)", q).group(1).lower(); serial = re.search(r"Serial number: 0x([0-9A-Fa-f]+)", r).group(1).lower()
        gen = re.search(r"Time stamp: (.+)", r).group(1).strip()
        spki = run("openssl", "x509", "-in", f"{n}.crt", "-pubkey", "-noout"); spki_der = run("openssl", "pkey", "-pubin", "-outform", "DER", inp=spki)
        vecs.append({"name": n, "alg": alg, "digest_hex": digest, "nonce_hex": nonce, "serial_hex": serial, "gen_time_text": gen,
                     "query_hex": open(f"{n}.tsq", "rb").read().hex(), "reply_hex": open(f"{n}.tsr", "rb").read().hex(), "spki_sha256": hashlib.sha256(spki_der).hexdigest()})
json.dump({"generator": "openssl ts (OpenSSL 3.x) acting as a TSA", "vectors": vecs}, open(out, "w"), indent=1)
print("wrote", out, len(vecs), "vectors")
PY
rm -rf "$T"
