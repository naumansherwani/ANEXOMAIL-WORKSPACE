import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";

// Runs the REAL public/flare-sw.js against a fake service-worker scope: whatever arrives, a notification with a real title AND body is shown (his phone showed an empty alert, 7 Nov 18:29).
const code = readFileSync(new URL("../public/flare-sw.js", import.meta.url), "utf8");
function run(data: unknown) {
  const shown: { title: string; o: any }[] = []; const handlers: Record<string, (e: any) => void> = {};
  const self: any = { addEventListener: (n: string, f: any) => { handlers[n] = f; }, skipWaiting() {}, clients: { claim() {}, matchAll: async () => [] },
    registration: { showNotification: async (title: string, o: any) => { shown.push({ title, o }); } }, location: { origin: "https://f.example" } };
  new Function("self", "caches", "fetch", "Response", code)(self, { open: async () => ({ put: async () => {} }) }, async () => ({}), class { constructor(public b: string) {} });
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
