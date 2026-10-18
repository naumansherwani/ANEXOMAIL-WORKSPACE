// Usage: node shot.mjs <outDir> <name> <hash> [width] [height] [steps...]
// steps: select:<label>=<value> | ff:<ms> (needs CLOCK=1) | btn:<exact button name> | click:<text> | into:<text> (scroll into view) | label:<aria-label> | fill:<placeholder>=<value> | fillx:<exact placeholder>=<value> | wait:<ms> | scroll:<top|bottom|px> | shot:<file>
import path from "node:path";
import { createRequire } from "node:module";
const TOOLS = process.env.TOOLS || "/opt/npm-tools/node_modules";
const { chromium } = createRequire(TOOLS + "/")("playwright");
const [outDir, name, hash = "empty", w = "1440", h = "900", ...steps] = process.argv.slice(2);
const browser = await chromium.launch({ executablePath: process.env.CHROME || "/opt/pw-browsers/chromium-1194/chrome-linux/chrome", args: ["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--enable-webgl"] });
// TOUCH=1: coarse pointer + touch (phone/tablet) so (pointer: coarse) rules (ax-tap, ax-hit, 16px inputs) apply.
const touch = process.env.TOUCH === "1";
const page = await (await browser.newContext({ viewport: { width: +w, height: +h }, deviceScaleFactor: 1, hasTouch: touch, isMobile: touch })).newPage();
const errs = [];
// DoH mock: DOH=namecheap|cloudflare|none (default none -> request fails, fallback path)
const doh = process.env.DOH || "none";
const NS = { namecheap: "dns1.registrar-servers.com.", cloudflare: "ada.ns.cloudflare.com.", godaddy: "ns01.domaincontrol.com." };
// Subdomains (3+ labels) have no NS of their own -> empty answer, like the real internet; the parent answers.
// EXISTING=google|none -> apex domains already have MX/SPF at that provider (8c warning); subdomains never do.
const existing = process.env.EXISTING || "none";
await page.route("**/cloudflare-dns.com/**", (r) => {
  if (doh === "none") return r.abort();
  const u = new URL(r.request().url());
  const name = u.searchParams.get("name") || "";
  const type = u.searchParams.get("type") || "NS";
  const sub = name.split(".").length >= 3;
  const ans = (t, data) => ({ Status: 0, Answer: [{ type: t, data }] });
  let body = { Status: 0, Authority: [{ type: 6 }] };
  if (type === "NS" && !sub) body = ans(2, NS[doh]);
  if (type === "MX" && !sub && existing === "google") body = ans(15, "1 aspmx.l.google.com.");
  if (type === "TXT" && !sub && existing === "google") body = ans(16, '"v=spf1 include:_spf.google.com ~all"');
  return r.fulfill({ status: 200, contentType: "application/dns-json", body: JSON.stringify(body) });
});
page.on("pageerror", (e) => errs.push("pageerror: " + e.message));
page.on("console", (m) => { if (m.type() === "error") errs.push("console: " + m.text()); });
// CLOCK=1: fake timers so long waits (e.g. 30 DNS polls = 10 min) can be skipped with the `ff:<ms>` step.
if (process.env.CLOCK === "1") await page.clock.install({ time: Date.now() });
await page.goto("file://" + path.join(outDir, "index.html") + "#" + hash);
await page.waitForTimeout(700);
const scroller = () => page.evaluate(() => document.querySelector("main .overflow-y-auto"));
for (const s of steps) {
  const [k, ...r] = s.split(":"); const v = r.join(":");
  if (k === "click") await page.getByText(v, { exact: false }).first().click();
  else if (k === "btn") await page.getByRole("button", { name: v, exact: true }).first().click();
  else if (k === "into") await page.getByText(v, { exact: false }).first().scrollIntoViewIfNeeded();
  else if (k === "label") await page.getByLabel(v).first().click();
  else if (k === "fill") { const [ph, val] = v.split("="); await page.getByPlaceholder(ph).fill(val); }
  else if (k === "fillx") { const [ph, val] = v.split("="); await page.getByPlaceholder(ph, { exact: true }).fill(val); }  // fillx:<exact placeholder>=<value> (when a placeholder is a substring of another)
  else if (k === "upload") await page.setInputFiles('input[type="file"]', v);  // upload:/abs/path/file.csv
  else if (k === "select") { const i = v.lastIndexOf("="); await page.getByLabel(v.slice(0, i)).selectOption(v.slice(i + 1)); }  // select:<aria-label>=<option value>
  else if (k === "wait") await page.waitForTimeout(+v);
  else if (k === "ff") await page.clock.runFor(+v);
  else if (k === "scroll") await page.evaluate((t) => { const el = document.querySelector("main .overflow-y-auto"); if (el) el.scrollTop = t === "bottom" ? el.scrollHeight : t === "top" ? 0 : +t; }, v);
  else if (k === "shot") await page.screenshot({ path: path.join(outDir, v) });
}
const m = await page.evaluate(() => { const el = document.querySelector("main .overflow-y-auto"); const inner = [...document.querySelectorAll("main *")].filter((e) => e !== el && (e.scrollTop || e.scrollLeft)).map((e) => (e.tagName + "." + String(e.className).slice(0, 30) + ":" + e.scrollTop + "," + e.scrollLeft)); return el ? { scrollH: el.scrollHeight, clientH: el.clientHeight, innerScrolled: inner } : null; });
const docW = await page.evaluate(() => ({ scrollW: document.documentElement.scrollWidth, winW: window.innerWidth, scrollH: document.documentElement.scrollHeight }));
await page.screenshot({ path: path.join(outDir, name + ".png"), fullPage: process.env.FULL === "1" });
console.log(name, "page:", JSON.stringify(docW), docW.scrollW > docW.winW ? "HORIZONTAL-OVERFLOW" : "", "scroller:", JSON.stringify(m), errs.length ? "\nERRORS:\n" + errs.join("\n") : "no-errors");
await browser.close();
