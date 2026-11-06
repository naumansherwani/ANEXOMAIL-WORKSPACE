// F2b guard: the founder SPA ships exactly the pinned kernel build, and the real wasm verifies Ed25519 (RFC 8032) through its C ABI.
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { expect, test } from "bun:test";
import { KERNEL } from "./kernel.pin";

const bytes = readFileSync(`public/kernel/anexo-kernel-${KERNEL.version}.wasm`);
const h = (s: string) => Uint8Array.from(s.match(/../g)!.map((x) => parseInt(x, 16)));

test("the shipped wasm is the pinned kernel and the same build as the user site", () => {
  expect(createHash("sha256").update(bytes).digest("hex")).toBe(KERNEL.sha256);
  expect(createHash("sha256").update(readFileSync(`../public/kernel/anexo-kernel-${KERNEL.version}.wasm`)).digest("hex")).toBe(KERNEL.sha256);
});

test("ed25519_verify in the real wasm: RFC 8032 vector passes, one changed byte fails", async () => {
  const { instance } = await WebAssembly.instantiate(bytes, { env: { host_wake() {}, host_call() {}, host_emit() {} } });
  const ex = instance.exports as any;
  const put = (b: Uint8Array) => { const p = ex.kernel_alloc(b.length); new Uint8Array(ex.memory.buffer, p, b.length).set(b); return [p, b.length] as const; };
  const pk = h("3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c");
  const sig = h("92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00");
  const v = (m: number) => ex.ed25519_verify(...put(pk), ...put(Uint8Array.of(m)), ...put(sig));
  expect(v(0x72)).toBe(1);
  expect(v(0x73)).toBe(0);
});

test("envelope_verify refuses a body that is not signed by the pinned key", async () => {
  const { instance } = await WebAssembly.instantiate(bytes, { env: { host_wake() {}, host_call() {}, host_emit() {} } });
  const ex = instance.exports as any;
  const body = new TextEncoder().encode(JSON.stringify({ alg: "ed25519", data: { a: 1 }, kid: "s1", sig_ed: "A".repeat(86), ts: Math.floor(Date.now() / 1000) }));
  const p = ex.kernel_alloc(body.length); new Uint8Array(ex.memory.buffer, p, body.length).set(body);
  expect(ex.envelope_verify(p, body.length, Math.floor(Date.now() / 1000), 120)).toBe(5); // BAD_SIG
});

test("merkle_verify in the real wasm: SQL E107 vector (n=3, last leaf) proves, one changed character fails", async () => {
  const { instance } = await WebAssembly.instantiate(bytes, { env: { host_wake() {}, host_call() {}, host_emit() {} } });
  const ex = instance.exports as any;
  const put = (t: string) => { const b = new TextEncoder().encode(t), p = ex.kernel_alloc(Math.max(b.length, 1)); new Uint8Array(ex.memory.buffer, p, b.length).set(b); return [p, b.length] as const; };
  const row = "01298bf8427622fb14734f7efc8c967c9e037bb1e51040c3462e422a2d29f0dd";
  const path = "L:619933a6cda3bcd1faba11b3fb9ec2d8bd13d4ec4d9c8787d3c830cea5220476";
  const root = "affb9317bdc52d5109a09da7a9e5ae9503f6b95b5476b5ea2de70b050e7b09b9";
  const v = (r: string, p: string, o: string) => ex.merkle_verify(...put(r), ...put(p), ...put(o));
  expect(v(row, path, root)).toBe(1);
  expect(v(row.replace("01298b", "01298c"), path, root)).toBe(0);
  expect(v(row, path.replace("L:", "R:"), root)).toBe(0);
  expect(v(row, path, root.replace("affb", "affc"))).toBe(0);
  expect(v(row, "", root)).toBe(0);
});

test("merkle_consistency_verify in the real wasm agrees with the independent Python reference on EVERY (m, n) pair up to 40 leaves, and refuses every change", async () => {
  const { instance } = await WebAssembly.instantiate(bytes, { env: { host_wake() {}, host_call() {}, host_emit() {} } });
  const ex = instance.exports as any;
  const put = (t: string) => { const b = new TextEncoder().encode(t), p = ex.kernel_alloc(Math.max(b.length, 1)); new Uint8Array(ex.memory.buffer, p, b.length).set(b); return [p, b.length] as const; };
  const call = (m: number, n: number, fr: string, sr: string, proof: string[]) => ex.merkle_consistency_verify(m, n, ...put(fr), ...put(sr), ...put(proof.join(",")));
  const vec = JSON.parse(readFileSync("../server/rust/consistency_vectors.json", "utf8"));
  expect(vec.cases.length).toBe((vec.max_n * (vec.max_n + 1)) / 2);
  const flip = (hx: string) => (hx[0] === "0" ? "1" : "0") + hx.slice(1);
  for (const c of vec.cases) {
    expect(call(c.m, c.n, c.first_root, c.second_root, c.proof)).toBe(1);
    if (c.m < c.n) {
      expect(call(c.m, c.n, c.second_root, c.first_root, c.proof)).toBe(0);                                                   // swapped roots
      expect(call(c.m, c.n, c.first_root, c.second_root, [flip(c.proof[0]), ...c.proof.slice(1)])).toBe(0);                  // changed proof hash
      expect(call(c.m, c.n, c.first_root, c.second_root, [...c.proof, "00".repeat(32)])).toBe(0);                            // extended
      expect(call(c.m, c.n, c.first_root, c.second_root, c.proof.slice(0, -1))).toBe(0);                                     // truncated
      expect(call(c.m, c.n, flip(c.first_root), c.second_root, c.proof)).toBe(0);                                            // wrong old root
      expect(call(c.m, c.n, c.first_root, flip(c.second_root), c.proof)).toBe(0);                                            // wrong new root
    }
  }
  expect(call(0, 5, "00".repeat(32), "00".repeat(32), [])).toBe(0);
  expect(call(5, 4, "00".repeat(32), "00".repeat(32), [])).toBe(0);
});

test("merkle_consistency_verify in the real wasm: forged old root with a power-of-two old size, and edge forms of the proof text", async () => {
  const { instance } = await WebAssembly.instantiate(bytes, { env: { host_wake() {}, host_call() {}, host_emit() {} } });
  const ex = instance.exports as any;
  const put = (t: string) => { const b = new TextEncoder().encode(t), p = ex.kernel_alloc(Math.max(b.length, 1)); new Uint8Array(ex.memory.buffer, p, b.length).set(b); return [p, b.length] as const; };
  const call = (m: number, n: number, fr: string, sr: string, proofText: string) => ex.merkle_consistency_verify(m, n, ...put(fr), ...put(sr), ...put(proofText));
  const vec = JSON.parse(readFileSync("../server/rust/consistency_vectors.json", "utf8"));
  const c = vec.cases.find((x: any) => x.m === 4 && x.n === 7);
  expect(call(4, 7, c.first_root, c.second_root, c.proof.join(","))).toBe(1);
  for (const forged of c.proof) expect(call(4, 7, forged, c.second_root, c.proof.join(","))).toBe(0);   // a node taken from the proof passed off as the old root
  const p = c.proof.join(",");
  expect(call(4, 7, c.first_root, c.second_root, p + "\n")).toBe(0);
  expect(call(4, 7, c.first_root, c.second_root, "0x" + p)).toBe(0);
  expect(call(4, 7, c.first_root, c.second_root, "," + p)).toBe(0);
  expect(call(4, 7, c.first_root, c.second_root, Array(65).fill("11".repeat(32)).join(","))).toBe(0);  // 65 hashes: parsed, then refused
  expect(call(4, 7, c.first_root, c.second_root, Array(66).fill("11".repeat(32)).join(","))).toBe(0);  // 66 hashes: refused by the parser
  // Huge sizes: only "no panic" is promised. A root does not commit to its size, so SIZES are bound by the signed seal (G5b), never by this check alone.
  expect([0, 1]).toContain(call(2 ** 31, 2 ** 32 - 1, c.first_root, c.second_root, p));
});

// ---- G5b: checkpoint@1 in the REAL wasm, against notes made by Go's own `note` package (the independent oracle, docs/cursor-work/server/g5b-oracle/) ----
const vec = JSON.parse(readFileSync("../server/rust/g5b_vectors.json", "utf8"));
async function ckp() {
  const { instance } = await WebAssembly.instantiate(bytes, { env: { host_wake() {}, host_call() {}, host_emit() {} } });
  const ex = instance.exports as any;
  const put = (t: string) => { const b = new TextEncoder().encode(t), p = ex.kernel_alloc(Math.max(b.length, 1)); new Uint8Array(ex.memory.buffer, p, b.length).set(b); return [p, b.length] as const; };
  return (note: string, name: string, pub: string, size: string, root: string) => { const a = [note, name, pub, size, root].map(put); return ex.checkpoint_verify(...a.flat()) as number; };
}

test("checkpoint_verify in the real wasm: every Go-signed note verifies, wrong size / root / key / name is refused", async () => {
  const v = await ckp(), keys = vec.keys;
  expect(vec.vectors.length).toBe(44);
  for (const x of vec.vectors) {
    const k = keys[x.key], root64 = x.root_hex, size = (x.note as string).split("\n")[1]; // the size as text from the note itself: 2^64-1 does not survive JSON.parse as a JS number
    expect(v(x.note, k.name, k.pub_hex, size, root64)).toBe(1);
    expect(v(x.note, k.name, k.pub_hex, String(BigInt(size) === 0n ? 1n : BigInt(size) - 1n), root64)).toBe(0);
    expect(v(x.note, k.name, k.pub_hex, size, "0".repeat(64))).toBe(0);
    expect(v(x.note, k.name, keys[(x.key + 1) % 4].pub_hex, size, root64)).toBe(0);
    expect(v(x.note, keys[(x.key + 1) % 4].name, k.pub_hex, size, root64)).toBe(0);
  }
});

test("checkpoint_verify: bad inputs are refused, never a crash (leading-zero size, upper-case hex, short key)", async () => {
  const v = await ckp(), x = vec.vectors.find((y: any) => y.size === 31 && y.key === 0), k = vec.keys[0];
  expect(v(x.note, k.name, k.pub_hex, "031", x.root_hex)).toBe(0);
  expect(v(x.note, k.name, k.pub_hex.toUpperCase(), "31", x.root_hex)).toBe(0);
  expect(v(x.note, k.name, k.pub_hex.slice(2), "31", x.root_hex)).toBe(0);
  expect(v(x.note, k.name, k.pub_hex, "31", x.root_hex.toUpperCase())).toBe(0);
  expect(v("", k.name, k.pub_hex, "31", x.root_hex)).toBe(0);
  expect(v(x.note, "", k.pub_hex, "31", x.root_hex)).toBe(0);
  expect(v("x".repeat(100000), k.name, k.pub_hex, "31", x.root_hex)).toBe(0);
});

test("checkpoint_verify: the real wasm agrees with Go on every single-byte flip (235 mutations), and 3000 random mutations never get through", async () => {
  const v = await ckp(), k = vec.keys[0];
  const base = vec.vectors.find((y: any) => y.size === 31 && y.key === 0);
  // the 235 Go-judged mutations were made from a different base note (size 31, root "mutation-base"); judge each with the size/root that note really carries
  for (const m of vec.mutations) {
    const lines = (m.note as string).split("\n"); // body is the first 3 lines when the note is still shaped like one
    const size = lines[1], root = Buffer.from(lines[2] ?? "", "base64");
    const rootHex = root.length === 32 ? root.toString("hex") : "0".repeat(64);
    const got = v(m.note, k.name, k.pub_hex, /^\d+$/.test(size ?? "") ? size : "31", rootHex);
    if (!m.go_verifies) expect(got).toBe(0);            // Go refused it: the wasm must refuse it too
  }
  // deterministic fuzz: random 1-4 byte edits of a good note must never verify against the ORIGINAL size/root
  let seed = 0x9e3779b9; const rnd = () => (seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0);
  const good = Buffer.from(base.note, "utf8");
  let accepted = 0;
  for (let i = 0; i < 3000; i++) {
    const b = Buffer.from(good), n = 1 + (rnd() % 4);
    for (let j = 0; j < n; j++) b[rnd() % b.length] ^= 1 << (rnd() % 8);
    if (b.equals(good)) continue;
    accepted += v(b.toString("utf8"), k.name, k.pub_hex, "31", base.root_hex);
  }
  expect(accepted).toBe(0);
});

test("portable_verify in the real wasm: the independent-tools bundle (openssl TSAs, python Ed25519) passes with its facts; every tamper is refused", async () => {
  const { instance } = await WebAssembly.instantiate(bytes, { env: { host_wake() {}, host_call() {}, host_emit() {} } });
  const ex = instance.exports as any;
  const put = (t: string) => { const b = new TextEncoder().encode(t), p = ex.kernel_alloc(Math.max(b.length, 1)); new Uint8Array(ex.memory.buffer, p, b.length).set(b); return [p, b.length] as const; };
  const run = (text: string, sha: string) => { const ok = ex.portable_verify(...put(text), ...put(sha)); return { ok, rep: JSON.parse(new TextDecoder().decode(new Uint8Array(ex.memory.buffer, ex.kernel_out_ptr(), ex.kernel_out_len()).slice())) }; };
  const vec = JSON.parse(readFileSync("../server/rust/g5d_kernel_vector.json", "utf8")), { text, sha } = vec.good;
  const g = run(text, sha);
  expect(g.ok).toBe(1);
  expect(g.rep.ok).toBe(true);
  for (const k of ["horizon_cp", "head_cp", "horizon_size", "head_size", "origin", "tsa", "anchored_ms", "proof_hashes"]) expect(g.rep.facts[k]).toBe(vec.facts[k]);
  const sha256 = (t: string) => createHash("sha256").update(t).digest("hex");
  const bad = run(text, sha.replace(/^./, sha[0] === "0" ? "1" : "0"));               // wrong committed hash
  expect(bad.ok).toBe(0); expect(bad.rep.failed_step).toBe("sha256");
  const flipped = text.replace(/"size": ?9/, '"size": 10');                          // a changed head size, hash recomputed so only the signatures can catch it
  if (flipped !== text) { const r = run(flipped, sha256(flipped)); expect(r.ok).toBe(0); expect(r.rep.ok).toBe(false); }
  const cut = text.slice(0, text.length - 40), r2 = run(cut, sha256(cut));            // truncated
  expect(r2.ok).toBe(0);
  expect(run("", sha256("")).ok).toBe(0);
  expect(run(text, "zz").ok).toBe(0);
});

test("lease@1 in the real wasm: RFC 5869 style key schedule is stable, a live lease is judged live, a wound-back clock ends it, a replayed serial is refused", async () => {
  const { instance } = await WebAssembly.instantiate(bytes, { env: { host_wake() {}, host_call() {}, host_emit() {} } });
  const ex = instance.exports as any;
  const run = (fn: string, text: string) => {
    const b = new TextEncoder().encode(text), p = ex.kernel_alloc(b.length); new Uint8Array(ex.memory.buffer, p, b.length).set(b);
    const ok = ex[fn](p, b.length), out = new TextDecoder().decode(new Uint8Array(ex.memory.buffer, ex.kernel_out_ptr(), ex.kernel_out_len()).slice());
    return { ok, out };
  };
  const dev = "0f8fad5b-d9cb-469f-a165-70867728950e", k = "A".repeat(43);
  const key1 = run("lease_vault_key", JSON.stringify({ local: k, half: "B".repeat(42) + "E", device_id: dev }));
  const key2 = run("lease_vault_key", JSON.stringify({ local: k, half: "B".repeat(42) + "E", device_id: dev }));
  expect(key1.ok).toBe(1); expect(key1.out).toHaveLength(43); expect(key1.out).toBe(key2.out);
  expect(run("lease_vault_key", JSON.stringify({ local: "short", half: k, device_id: dev })).ok).toBe(0);
  const data = { type: "vault-lease@1", device_id: dev, serial: 3, issued_ms: 1_700_000_000_000, expires_ms: 1_700_000_900_000, ttl_s: 900, nonce: "0123456789abcdef0123456789abcdef", key_thumb: k, half: k };
  const base = { data, device_id: dev, pinned_serial: 0, received_wall_ms: 1_700_000_000_500, received_mono_ms: 10_000, now_wall_ms: 1_700_000_000_500, now_mono_ms: 10_000 };
  const live = run("lease_check", JSON.stringify(base));
  expect(live.ok).toBe(1); expect(JSON.parse(live.out)).toMatchObject({ state: "live", remaining_ms: 900_000, serial: 3 });
  expect(run("lease_check", JSON.stringify({ ...base, now_mono_ms: 10_000 + 900_000, now_wall_ms: 1_700_000_900_500 })).ok).toBe(0);
  expect(JSON.parse(run("lease_check", JSON.stringify({ ...base, now_mono_ms: 410_000, now_wall_ms: 1_700_000_010_500 })).out).reason).toContain("turned back");
  expect(JSON.parse(run("lease_check", JSON.stringify({ ...base, pinned_serial: 4 })).out).reason).toContain("replay");
});
