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

// J6 live bug 3 (3 Nov 12:58): the nonce the door needs is the one the SERVER issued with the options (Proved.nonce), not a field of the grant result; an empty one fails the 's' shape ("a field is missing or has the wrong shape").
test("protected-step doors send the server-issued nonce (Proved.nonce)", () => {
  const fs = require("node:fs");
  for (const f of ["./Flare.tsx", "./Keys.tsx"]) { const src = fs.readFileSync(new URL(f, import.meta.url), "utf8") as string; expect(src).not.toContain("result.nonce"); expect(src).toContain("p.nonce"); }
});

import { browserName } from "./devicelabel";
describe("device label names the real browser", () => {
  const cases: Array<[string, string]> = [
    ["Mozilla/5.0 (Linux; U; Android 13; en-US) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/100.0.4896.58 UCBrowser/13.5.0.1306 Mobile Safari/537.36", "UC Browser"],
    ["Mozilla/5.0 (Linux; Android 13; SM-S911B) AppleWebKit/537.36 Chrome/120.0 Mobile Safari/537.36 OPR/80.1.4244", "Opera"],
    ["Mozilla/5.0 (Android 14; Mobile; rv:126.0) Gecko/126.0 Firefox/126.0", "Firefox"],
    ["Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0 Mobile Safari/537.36 EdgA/120.0", "Edge"],
    ["Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0 SamsungBrowser/23.0 Mobile Safari/537.36", "Samsung Internet"],
    ["Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0 Mobile Safari/537.36", "Chrome"],
    ["Mozilla/5.0 (iPhone; CPU iPhone OS 17_0) AppleWebKit/605.1.15 Version/17.0 Mobile Safari/604.1", "Safari"],
    ["Mozilla/5.0 (iPhone; CPU iPhone OS 17_0) AppleWebKit/605.1.15 FxiOS/126.0 Mobile Safari/605.1.15", "Firefox"],
    ["", "Browser"],
  ];
  for (const [ua, n] of cases) test(n + ": " + ua.slice(-40), () => { expect(browserName(ua)).toBe(n); });
});

describe("mobile + tablet CSS rules (Rule 19/34, founder 6 Nov 2026)", () => {
  const fs = require("node:fs"); const dx: string = fs.readFileSync(new URL("./dx.css", import.meta.url), "utf8"), ui: string = fs.readFileSync(new URL("./ui.css", import.meta.url), "utf8");
  test("no bare 1fr grid column is left (it grows to the widest nowrap line and cuts cards off)", () => {
    for (const css of [dx, ui]) expect(/grid-template-columns:\s*(repeat\(\d+,\s*1fr\)|1fr)\s*[;}]/.test(css)).toBe(false);
  });
  test("cards never exceed their column", () => { expect(dx).toContain(".dx-card,.dx-feat,.dx-tile,.dx-gate{min-width:0;max-width:100%}"); });
  test("44 px touch targets on touch screens and up to tablet landscape, switches keep their look", () => {
    expect(dx).toContain("@media (pointer:coarse), (max-width:1100px)"); expect(dx).toContain(".pg button:not(.switch)"); expect(dx).toContain("min-height: 44px"); expect(dx).toContain(".switch::after");
  });
  test("settings tabs scroll inside their own strip and never shrink into each other", () => { expect(dx).toContain(".setnav .setitem { flex: 0 0 auto; white-space: nowrap;"); expect(dx).toContain("overflow-x: auto"); });
  test("deck tabs are one scrolling strip on a phone", () => { expect(dx).toContain(".tabs { flex-wrap: nowrap; overflow-x: auto;"); });
});

describe("phone and laptop run the SAME code (founder 6 Nov 2026: only the layout differs)", () => {
  const fs = require("node:fs"), path = require("node:path"); const dir = path.dirname(new URL(import.meta.url).pathname);
  const src = fs.readdirSync(dir).filter((f: string) => /\.(tsx?|ts)$/.test(f) && !/\.test\./.test(f)).map((f: string) => [f, fs.readFileSync(path.join(dir, f), "utf8") as string]);
  test("no JavaScript screen-size switch anywhere (no innerWidth / matchMedia width / userAgent device branch)", () => {
    for (const [f, t] of src) { if (f === "devicelabel.ts" || f === "api.ts") continue; expect([f, /innerWidth|matchMedia\(["'`]\((max|min)-width|isMobile|isTablet/.test(t)]).toEqual([f, false]); }
  });
  test("the device trust label stays visible on a phone", () => { expect(fs.readFileSync(path.join(dir, "ui.css"), "utf8")).not.toMatch(/\.trustbtn \.tt\s*\{[^}]*display:\s*none/); });
});
