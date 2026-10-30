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
