import { describe, expect, test } from "bun:test";
import { b64u, cleanExt, friendly, prepareCreate, prepareGet, toB64u } from "./passkey_pure";

describe("passkey helpers", () => {
  test("base64url round trip without padding", () => {
    for (const n of [0, 1, 2, 3, 31, 32, 33]) { const u = new Uint8Array(n).map((_, i) => (i * 37 + 11) & 255); const t = b64u.enc(u); expect(t).not.toMatch(/[+/=]/); expect([...b64u.dec(t)]).toEqual([...u]); }
    expect(b64u.enc(new Uint8Array([0xfb, 0xff]))).toBe("-_8");
  });
  test("options become bytes", () => {
    const c = prepareCreate({ challenge: "AAEC", user: { id: "AQID", name: "a@b.c" }, excludeCredentials: [{ type: "public-key", id: "BAUG" }], pubKeyCredParams: [] });
    expect([...(c.challenge as Uint8Array)]).toEqual([0, 1, 2]);
    expect([...(c.user.id as Uint8Array)]).toEqual([1, 2, 3]);
    expect([...(c.excludeCredentials![0].id as Uint8Array)]).toEqual([4, 5, 6]);
    const g = prepareGet({ challenge: "AAEC", allowCredentials: [{ type: "public-key", id: "BAUG" }], userVerification: "required" });
    expect(g.userVerification).toBe("required");
    expect([...(g.allowCredentials![0].id as Uint8Array)]).toEqual([4, 5, 6]);
    expect(prepareGet({ challenge: "AAEC" }).allowCredentials).toEqual([]);
  });
  test("signal user ids are base64url", () => { expect(toB64u("ab+/cd==")).toBe("ab-_cd"); });
  test("extension results become JSON-safe", () => {
    const e = cleanExt({ prf: { enabled: true, results: { first: new Uint8Array([1, 2]).buffer } }, credProps: { rk: true } });
    expect(e.prf.results.first).toBe("AQI"); expect(e.credProps.rk).toBe(true);
  });
  test("errors are said in plain words", () => {
    expect(friendly({ name: "NotAllowedError", message: "x" })).toContain("cancelled");
    expect(friendly({ name: "InvalidStateError", message: "x" })).toContain("already registered");
    expect(friendly({ name: "SecurityError", message: "x" })).toContain("address");
    expect(friendly(new Error("boom"))).toBe("boom");
  });
});

import { b64uBytes, isConfirmToken, pushSupported, sha256Hex, subscriptionFields } from "./flare_pure";
describe("phone alerts (J6) helpers", () => {
  test("sha-256 hex matches the known vector (this is the value SQL _fh_sha computes)", async () => {
    expect(await sha256Hex("abc")).toBe("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  });
  test("base64url key becomes bytes", () => { expect([...b64uBytes("AAEC")]).toEqual([0, 1, 2]); expect([...b64uBytes("-_8")]).toEqual([0xfb, 0xff]); });
  test("subscription fields mirror the server door", () => {
    const ok = { endpoint: "https://fcm.googleapis.com/fcm/send/abc", keys: { p256dh: "B" + "A".repeat(86), auth: "A".repeat(22) } };
    expect(subscriptionFields(ok)).toEqual({ endpoint: ok.endpoint, p256dh: ok.keys.p256dh, auth: ok.keys.auth });
    expect(subscriptionFields({ ...ok, endpoint: "http://x/y" })).toBeNull();
    expect(subscriptionFields({ ...ok, keys: { ...ok.keys, p256dh: "C" + "A".repeat(86) } })).toBeNull();
    expect(subscriptionFields({ ...ok, keys: { ...ok.keys, auth: "A".repeat(21) } })).toBeNull();
    expect(subscriptionFields({ endpoint: ok.endpoint })).toBeNull();
  });
  test("confirm token shape and push support", () => {
    expect(isConfirmToken("A".repeat(32))).toBe(true); expect(isConfirmToken("A".repeat(31))).toBe(false); expect(isConfirmToken("a b".padEnd(32, "a"))).toBe(false); expect(isConfirmToken(5)).toBe(false);
    expect(pushSupported({})).toBe(false); expect(pushSupported({ Notification: {}, PushManager: {}, navigator: { serviceWorker: {} } })).toBe(true);
  });
});

import { readFileSync } from "node:fs";
describe("mobile + tablet rule (Rule 19 / 34) for the key and phone panels", () => {
  const css = readFileSync(new URL("./dx.css", import.meta.url), "utf8");
  test("touch targets are 44 px and inputs 16 px on narrow or touch screens", () => {
    expect(css).toMatch(/@media \(pointer:coarse\), \(max-width:820px\)/);
    expect(css).toMatch(/\.mini \{ min-height: 44px; min-width: 44px;/);
    expect(css).toMatch(/input, select, textarea \{ font-size: 16px; \}/);
  });
  test("the phone and key panel rows wrap on narrow screens", () => { expect(css).toContain('.panel[aria-label="Phone alerts"] .setrow { flex-wrap: wrap; }'); });
});

// J6 live bug (3 Nov 12:30): the CSP demands Trusted Types, so registering the push service worker with a plain string throws. The source must go through the narrow policy.
test("Flare registers the service worker through a Trusted Types policy", () => {
  const src = require("node:fs").readFileSync(new URL("./Flare.tsx", import.meta.url), "utf8") as string;
  expect(src).toContain('createPolicy("anexo-flare-sw"');
  expect(src).not.toMatch(/serviceWorker\.register\(swUrl\(\)\)/);
  expect(src).toContain("serviceWorker.register(swScript() as string)");
});

test("Flare waits for THIS service worker registration to be active, not serviceWorker.ready", () => {
  const src = require("node:fs").readFileSync(new URL("./Flare.tsx", import.meta.url), "utf8") as string;
  expect(src).toContain("whenActive(await navigator.serviceWorker.register(");
  expect(src).not.toContain("await navigator.serviceWorker.ready");
});
