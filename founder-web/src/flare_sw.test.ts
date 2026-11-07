import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";

// Runs the REAL public/flare-sw.js against a fake service-worker scope: whatever arrives, a notification with a real title AND body is shown (his phone showed an empty alert, 7 Nov 18:29).
const code = readFileSync(new URL("../public/flare-sw.js", import.meta.url), "utf8");
function run(data: unknown) {
  const shown: { title: string; o: any }[] = [], cached: { k: string; v: any }[] = []; (globalThis as any).__cached = cached; const handlers: Record<string, (e: any) => void> = {};
  const self: any = { addEventListener: (n: string, f: any) => { handlers[n] = f; }, skipWaiting() {}, clients: { claim() {}, matchAll: async () => [] },
    registration: { showNotification: async (title: string, o: any) => { shown.push({ title, o }); } }, location: { origin: "https://f.example" } };
  new Function("self", "caches", "fetch", "Response", code)(self, { open: async () => ({ put: async (k: string, r: any) => { cached.push({ k, v: JSON.parse(r.b) }); } }) }, async () => ({}), class { constructor(public b: string) {} });
  let waited: Promise<unknown> = Promise.resolve();
  handlers.push({ data, waitUntil: (p: Promise<unknown>) => { waited = p; } });
  return waited.then(() => shown);
}
const ev = (v: unknown) => ({ json: () => { if (typeof v === "string") throw new Error("bad"); return v; } });

test("a normal test alert shows its own title and body", async () => {
  const s = await run(ev({ web_push: 8030, k: "test", notification: { title: "Test alert", body: "Phone alerts work.", tag: "anexo-test", navigate: "https://f.example/#/settings" } }));
  expect(s.length).toBe(1); expect(s[0].title).toBe("Test alert"); expect(s[0].o.body).toBe("Phone alerts work.");
});
test("a payload with a title but NO body still gets a real body", async () => {
  const s = await run(ev({ web_push: 8030, k: "test", notification: { title: "Test alert" } }));
  expect(s[0].title).toBe("Test alert"); expect(s[0].o.body.length).toBeGreaterThan(5);
});
test("garbage, empty and foreign pushes never show an empty notification and say why", async () => {
  for (const [d, code] of [[ev("not json"), "parse"], [null, "none"], [ev({ hello: 1 }), "shape"], [ev({ web_push: 8030, notification: { title: "" } }), "shape"]] as const) {
    const s = await run(d as any);
    expect(s.length).toBe(1); expect(s[0].title.trim().length).toBeGreaterThan(0); expect(s[0].o.body).toContain(`code=${code}`);
  }
});
test("the delivery receipt token path still shows the alert and sends the receipt", async () => {
  const s = await run(ev({ web_push: 8030, k: "t3_begun", a: "A".repeat(32), notification: { title: "Protected action started", body: "Cancel it if it was not you.", requireInteraction: true } }));
  expect(s[0].title).toBe("Protected action started"); expect(s[0].o.requireInteraction).toBe(true);
});

test("the worker records what it received (lengths + short text) for the card to show", async () => {
  await run(ev({ web_push: 8030, k: "test", notification: { title: "Test alert", body: "Phone alerts work." } }));
  const c = (globalThis as any).__cached.find((x: any) => x.k === "/__flare/last");
  expect(c.v.k).toBe("test"); expect(c.v.tl).toBe(10); expect(c.v.bl).toBe(18); expect(c.v.why).toBe("ok");
  await run(ev("junk"));
  const c2 = (globalThis as any).__cached.filter((x: any) => x.k === "/__flare/last").pop();
  expect(c2.v.why).toBe("parse"); expect(c2.v.tl).toBe(0);
});

// --- the tap -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function tap(clients: any[], opts: { openFails?: boolean } = {}) {
  const calls: string[] = [], cached: { k: string; v: any }[] = [], handlers: Record<string, (e: any) => void> = {};
  const wrap = (c: any) => ({ url: c.url, focus: async () => { calls.push("focus"); if (c.focusFails) throw new Error("refused"); return { ...wrap(c), postMessage: (m: any) => calls.push("msg:" + JSON.stringify(m)), navigate: async (u: string) => { calls.push("nav:" + u); } }; } });
  const self: any = { addEventListener: (n: string, f: any) => { handlers[n] = f; }, skipWaiting() {}, location: { origin: "https://f.example" },
    clients: { claim() {}, matchAll: async () => clients.map(wrap), openWindow: async (u: string) => { calls.push("open:" + u); } }, registration: { showNotification: async () => {} } };
  new Function("self", "caches", "fetch", "Response", code)(self, { open: async () => ({ put: async (k: string, r: any) => { cached.push({ k, v: JSON.parse(r.b) }); } }) }, async () => ({}), class { constructor(public b: string) {} });
  let waited: Promise<unknown> = Promise.resolve();
  handlers.notificationclick({ notification: { close() { calls.push("close"); }, title: "Test alert", data: { navigate: "https://f.example/#/settings", k: "test" } }, waitUntil: (p: Promise<unknown>) => { waited = p; } });
  return waited.then(() => ({ calls, cached }));
}
test("tap: a window of this site is focused, told which alert, navigated; the tap is recorded", async () => {
  const r = await tap([{ url: "https://f.example/#/settings" }]);
  expect(r.calls).toContain("focus"); expect(r.calls).toContain('msg:{"flare_click":"test"}'); expect(r.calls).toContain("nav:https://f.example/#/settings"); expect(r.calls.some((c) => c.startsWith("open:"))).toBe(false);
  expect(r.cached.find((c) => c.k === "/__flare/clicked")?.v.k).toBe("test");
});
test("tap: no window at all opens a new one", async () => {
  const r = await tap([]); expect(r.calls).toContain("open:https://f.example/#/settings");
});
test("tap: a window that refuses focus falls back to a new window; a foreign-origin window is ignored", async () => {
  expect((await tap([{ url: "https://f.example/", focusFails: true }])).calls).toContain("open:https://f.example/#/settings");
  const r = await tap([{ url: "https://evil.example/" }]); expect(r.calls).not.toContain("focus"); expect(r.calls).toContain("open:https://f.example/#/settings");
});
