// node run.js  (needs: npx vite dev --port 5391 in the repo root, and playwright). Renders the real /auth page with demo.js at 1280 and 390 for the three states.
const { chromium } = require("playwright"); const fs = require("fs"); const path = require("path");
const URL = process.env.GG_URL || "http://127.0.0.1:5391/auth"; const OUT = path.join(__dirname, "screens"); const js = fs.readFileSync(path.join(__dirname, "demo.js"), "utf8");
(async () => { const b = await chromium.launch();
  for (const state of ["idle", "verify", "passkey"]) for (const [w, h] of [[1280, 800], [390, 844]]) {
    const p = await b.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 2 });
    await p.goto(URL, { waitUntil: "networkidle", timeout: 60000 }).catch(() => {}); await p.waitForTimeout(2500);
    await p.evaluate((s) => { window.GG = { state: s }; }, state); await p.addScriptTag({ content: js }); await p.waitForTimeout(1500);
    await p.screenshot({ path: path.join(OUT, `awam-signin-${state}-${w}.png`) }); await p.close(); }
  await b.close(); })();
