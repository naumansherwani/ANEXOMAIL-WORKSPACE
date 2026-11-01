#!/usr/bin/env python3
"""G5a reference: an INDEPENDENT implementation of RFC 9162 section 2.1.4 (consistency proofs) written from the RFC text in a different language than the
Rust and SQL code, so one bug cannot hide in two copies. It (1) builds the same tree as the ledger (leaf = sha256(00||row_hash), node = sha256(01||l||r),
row hash g = sha256("founder-merkle-vector-"+g)), (2) generates every proof for 1 <= m <= n <= N and checks them with its own verifier, (3) writes
server/rust/consistency_vectors.json which a Rust test compares byte for byte. Usage: g5a-reference.py [N=40]  (writes the json)  |  --sql-parity HOST_PORT_DB (compare with local Postgres)."""
import hashlib, json, sys, os

def H(b): return hashlib.sha256(b).digest()
def leaf(rh): return H(b"\x00" + rh)
def node(l, r): return H(b"\x01" + l + r)
def rows(n): return [H(("founder-merkle-vector-%d" % g).encode()) for g in range(1, n + 1)]
def leaves(n): return [leaf(r) for r in rows(n)]

def k_below(n):
    k = 1
    while k * 2 < n: k *= 2
    return k
def mth(d):
    if len(d) == 1: return d[0]
    k = k_below(len(d)); return node(mth(d[:k]), mth(d[k:]))
def subproof(m, d, b):
    n = len(d)
    if m == n: return [] if b else [mth(d)]
    k = k_below(n)
    if m <= k: return subproof(m, d[:k], b) + [mth(d[k:])]
    return subproof(m - k, d[k:], False) + [mth(d[:k])]
def proof(d, m, n): return subproof(m, d[:n], True)

def verify(first, second, first_hash, second_hash, p):          # RFC 9162 2.1.4.2, step by step
    if first == second: return p == [] and first_hash == second_hash
    if not p: return False
    if first & (first - 1) == 0: p = [first_hash] + p
    fn, sn = first - 1, second - 1
    while fn & 1: fn >>= 1; sn >>= 1
    fr = sr = p[0]
    for c in p[1:]:
        if sn == 0: return False
        if fn & 1 or fn == sn:
            fr = node(c, fr); sr = node(c, sr)
            if not fn & 1:
                while not fn & 1 and fn != 0: fn >>= 1; sn >>= 1
        else:
            sr = node(sr, c)
        fn >>= 1; sn >>= 1
    return fr == first_hash and sr == second_hash and sn == 0

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--sql-parity":
        import subprocess
        N = int(sys.argv[2]) if len(sys.argv) > 2 else 40
        d = leaves(N); bad = 0; cnt = 0
        for n in range(1, N + 1):
            for m in range(1, n + 1):
                q = "select public._fm_g5a_vector(%d,%d)" % (m, n)
                out = subprocess.run(["psql", "-h", "/tmp", "-p", "5545", "-U", "postgres", "-d", "postgres", "-Atc", q], capture_output=True, text=True).stdout.strip()
                want = [x.hex() for x in proof(d, m, n)]
                got = json.loads(out)["proof"] if out else None
                cnt += 1
                if got != want: bad += 1; print("DIFF", m, n, got, want)
        print("sql parity: %d pairs, %d differences" % (cnt, bad)); sys.exit(1 if bad else 0)
    N = int(sys.argv[1]) if len(sys.argv) > 1 else 40
    d = leaves(N); cases = []
    for n in range(1, N + 1):
        rn = mth(d[:n])
        for m in range(1, n + 1):
            rm = mth(d[:m]); p = proof(d, m, n)
            assert verify(m, n, rm, rn, p), (m, n)                       # the reference proves its own proofs
            if p:
                bad = list(p); bad[0] = bytes([bad[0][0] ^ 1]) + bad[0][1:]
                assert not verify(m, n, rm, rn, bad), ("bit flip accepted", m, n)
            cases.append({"m": m, "n": n, "first_root": rm.hex(), "second_root": rn.hex(), "proof": [x.hex() for x in p]})
    out = os.path.join(os.path.dirname(__file__), "..", "..", "..", "server", "rust", "consistency_vectors.json")
    out = os.path.normpath(out)
    json.dump({"rule": "RFC 9162 2.1.4; rows sha256('founder-merkle-vector-'+g), leaf=sha256(00||row) node=sha256(01||l||r)", "max_n": N, "cases": cases}, open(out, "w"), separators=(",", ":"))
    print("wrote %s: %d cases (n<=%d), all verified by the reference" % (out, len(cases), N))
if __name__ == "__main__": main()
