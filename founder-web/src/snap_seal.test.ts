import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { b64u } from "./lease_pure";
import { openSealed, seal, snapKey } from "./snap_seal";

const vk = () => b64u(crypto.getRandomValues(new Uint8Array(32)));
const DEV = "11111111-2222-4333-8444-555555555555", PLAIN = '{"ok":true,"secret":"BRIDGE-DATA-123","n":[1,2,3]}';

test("round trip: the plain text comes back exactly", async () => {
  const k = await snapKey(vk(), DEV), t = Date.now();
  const o = await openSealed(k, await seal(k, PLAIN, DEV, t), DEV);
  expect(o).toEqual({ t, plain: PLAIN });
});
test("at rest it is ciphertext: no part of the plain text is in the stored string", async () => {
  const k = await snapKey(vk(), DEV), s = await seal(k, PLAIN, DEV, 1);
  for (const w of ["BRIDGE-DATA", "secret", "ok", "123"]) expect(s.includes(w)).toBe(false);
  expect(JSON.parse(s).v).toBe(1);
});
test("a fresh IV every time: sealing the same text twice gives different records", async () => {
  const k = await snapKey(vk(), DEV), a = JSON.parse(await seal(k, PLAIN, DEV, 1)), b = JSON.parse(await seal(k, PLAIN, DEV, 1));
  expect(a.iv).not.toBe(b.iv); expect(a.c).not.toBe(b.c);
});
test("no key / wrong key = unreadable (the lease ended, or another device's key)", async () => {
  const s = await seal(await snapKey(vk(), DEV), PLAIN, DEV, 5);
  expect(await openSealed(await snapKey(vk(), DEV), s, DEV)).toBeNull();
  const same = vk(); expect(await openSealed(await snapKey(same, DEV), await seal(await snapKey(same, DEV), PLAIN, DEV, 5), DEV)).not.toBeNull();
  expect(await openSealed(await snapKey(same, "99999999-2222-4333-8444-555555555555"), await seal(await snapKey(same, DEV), PLAIN, DEV, 5), DEV)).toBeNull();   // key bound to the device
});
test("tampering is refused: flipped ciphertext, flipped IV, re-stamped time, other device, junk", async () => {
  const key = vk(), k = await snapKey(key, DEV), s = JSON.parse(await seal(k, PLAIN, DEV, 100));
  const flip = (x: string) => (x[0] === "A" ? "B" : "A") + x.slice(1);
  expect(await openSealed(k, JSON.stringify({ ...s, c: flip(s.c) }), DEV)).toBeNull();
  expect(await openSealed(k, JSON.stringify({ ...s, iv: flip(s.iv) }), DEV)).toBeNull();
  expect(await openSealed(k, JSON.stringify({ ...s, t: 101 }), DEV)).toBeNull();          // AAD carries the time
  expect(await openSealed(k, JSON.stringify(s), "99999999-2222-4333-8444-555555555555")).toBeNull();
  expect(await openSealed(k, JSON.stringify({ ...s, v: 2 }), DEV)).toBeNull();
  expect(await openSealed(k, JSON.stringify({ ...s, iv: "AAAA" }), DEV)).toBeNull();
  for (const junk of ["", "x", "{}", "null", "[1]", '{"v":1}']) expect(await openSealed(k, junk, DEV)).toBeNull();
});
test("the key is non-extractable and different from the vault key itself", async () => {
  const k = await snapKey(vk(), DEV);
  expect(k.extractable).toBe(false); expect(k.algorithm.name).toBe("AES-GCM"); expect((k.algorithm as AesKeyAlgorithm).length).toBe(256);
  await expect(crypto.subtle.exportKey("raw", k)).rejects.toBeDefined();
});
test("wiring: api.ts never stores plain text any more; the lease wipe deletes the record; the key exists only while live", () => {
  const api = readFileSync(new URL("./api.ts", import.meta.url), "utf8"), lease = readFileSync(new URL("./lease.ts", import.meta.url), "utf8");
  expect(api).not.toContain("JSON.stringify({ t: Date.now(), b:");
  expect(api).toContain("await seal(k.key");
  expect(api).toContain("openSealed(k.key, raw, k.device)");
  expect(lease).toContain("clearSnap();");
  expect(lease).toContain("registerSnapKey(");
  expect(lease).toContain("const k = vaultKey()");   // vaultKey() is null unless the phase is live
});

test("api.ts deletes a legacy plain-text snapshot at load", async () => {
  const src = await Bun.file(new URL("./api.ts", import.meta.url)).text();
  expect(src).toContain("anything that is not a sealed {v:1,iv,c} record is deleted at load");
  expect(src).toMatch(/o\.v === 1 && typeof o\.iv === "string" && typeof o\.c === "string"/);
});
