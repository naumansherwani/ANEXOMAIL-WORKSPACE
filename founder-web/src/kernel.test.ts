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
