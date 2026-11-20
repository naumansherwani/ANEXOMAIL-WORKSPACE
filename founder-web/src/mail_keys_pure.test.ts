import { describe, expect, test } from "bun:test";
import { DK_LEN, PUB_LEN, X_LEN, newKeyId, pubHex, unwrapDeviceKey, wipe, wrapDeviceKey } from "./mail_keys_pure";
const rnd = (n: number, s = 1) => Uint8Array.from({ length: n }, (_, i) => (i * 7 + s) & 255);
describe("DK3 device key custody (pure)", () => {
  const prf = rnd(32, 3), dk = rnd(DK_LEN, 5), x = rnd(X_LEN, 9), pub = rnd(PUB_LEN, 11);
  test("wrap then unwrap gives the same private halves", async () => {
    const w = await wrapDeviceKey(prf, "dk-20261120-a1b2c3", dk, x, pub); expect(w).not.toBeNull();
    expect(w!.ct.length).toBe((DK_LEN + X_LEN + 16) * 2);
    const o = await unwrapDeviceKey(prf, w!); expect(o).not.toBeNull(); expect(o!.dk).toEqual(dk); expect(o!.x).toEqual(x);
  });
  test("wrong PRF, tampered ct, swapped key id or swapped fingerprint all give null", async () => {
    const w = (await wrapDeviceKey(prf, "dk-20261120-a1b2c3", dk, x, pub))!;
    expect(await unwrapDeviceKey(rnd(32, 4), w)).toBeNull();
    expect(await unwrapDeviceKey(prf, { ...w, ct: (w.ct[0] === "0" ? "1" : "0") + w.ct.slice(1) })).toBeNull();
    expect(await unwrapDeviceKey(prf, { ...w, key_id: "dk-20261120-ffffff" })).toBeNull();
    expect(await unwrapDeviceKey(prf, { ...w, pub_fp: "0".repeat(64) })).toBeNull();
  });
  test("bad sizes and ids are refused before any crypto", async () => {
    expect(await wrapDeviceKey(rnd(16), "dk-20261120-a1b2c3", dk, x, pub)).toBeNull();
    expect(await wrapDeviceKey(prf, "dk-20261120-a1b2c3", dk.slice(1), x, pub)).toBeNull();
    expect(await wrapDeviceKey(prf, "bad id!", dk, x, pub)).toBeNull();
    expect(pubHex(pub)!.length).toBe(2432); expect(pubHex(pub.slice(1))).toBeNull();
  });
  test("wipe zeroes, key ids are new and well formed", () => {
    const b = rnd(8); wipe(b, undefined, null); expect([...b].every((v) => v === 0)).toBe(true);
    const a = newKeyId(new Date(Date.UTC(2026, 10, 20)), Uint8Array.of(1, 2, 3)); expect(a).toBe("dk-20261120-010203"); expect(newKeyId()).not.toBe(newKeyId());
  });
});
