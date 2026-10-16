// Usage: node shot.mjs <outDir> <name> <hash> [width] [height] [steps...]
// steps: click:<text> | fill:<placeholder>=<value> | wait:<ms> | scroll:<top|bottom|px> | shot:<file>
import path from "node:path";
import { createRequire } from "node:module";
const TOOLS = process.env.TOOLS || "/opt/npm-tools/node_modules";
const { chromium } = createRequire(TOOLS + "/")("playwright");
const [outDir, name, hash = "empty", w = "1440", h = "900", ...steps] = process.argv.slice(2);
const browser = await chromium.launch({ executablePath: process.env.CHROME || "/opt/pw-browsers/chromium-1194/chrome-linux/chrome", args: ["--no-sandbox"] });
const page = await (await browser.newContext({ viewport: { width: +w, height: +h }, deviceScaleFactor: 1 })).newPage();
const errs = [];
// DoH mock: DOH=namecheap|cloudflare|none (default none -> request fails, fallback path)
const doh = process.env.DOH || "none";
const NS = { namecheap: "dns1.registrar-servers.com.", cloudflare: "ada.ns.cloudflare.com.", godaddy: "ns01.domaincontrol.com." };
await page.route("**/cloudflare-dns.com/**", (r) => doh === "none" ? r.abort() : r.fulfill({ status: 200, contentType: "application/dns-json", body: JSON.stringify({ Answer: [{ data: NS[doh] }] }) }));
page.on("pageerror", (e) => errs.push("pageerror: " + e.message));
page.on("console", (m) => { if (m.type() === "error") errs.push("console: " + m.text()); });
await page.goto("file://" + path.join(outDir, "index.html") + "#" + hash);
await page.waitForTimeout(700);
const scroller = () => page.evaluate(() => document.querySelector("main .overflow-y-auto"));
for (const s of steps) {
  const [k, ...r] = s.split(":"); const v = r.join(":");
  if (k === "click") await page.getByText(v, { exact: false }).first().click();
  else if (k === "fill") { const [ph, val] = v.split("="); await page.getByPlaceholder(ph).fill(val); }
  else if (k === "wait") await page.waitForTimeout(+v);
  else if (k === "scroll") await page.evaluate((t) => { const el = document.querySelector("main .overflow-y-auto"); if (el) el.scrollTop = t === "bottom" ? el.scrollHeight : t === "top" ? 0 : +t; }, v);
  else if (k === "shot") await page.screenshot({ path: path.join(outDir, v) });
}
const m = await page.evaluate(() => { const el = document.querySelector("main .overflow-y-auto"); const inner = [...document.querySelectorAll("main *")].filter((e) => e !== el && (e.scrollTop || e.scrollLeft)).map((e) => (e.tagName + "." + String(e.className).slice(0, 30) + ":" + e.scrollTop + "," + e.scrollLeft)); return el ? { scrollH: el.scrollHeight, clientH: el.clientHeight, innerScrolled: inner } : null; });
await page.screenshot({ path: path.join(outDir, name + ".png") });
console.log(name, "scroller:", JSON.stringify(m), errs.length ? "\nERRORS:\n" + errs.join("\n") : "no-errors");
await browser.close();
