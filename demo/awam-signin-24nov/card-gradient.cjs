// his 13:05 demo: the faint logo-colour gradient moving over the sign-in card; shots at 3 moments of the 14 s sheen
const { chromium } = require("playwright");
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:1280,height:800},deviceScaleFactor:1.085});
await p.goto("http://127.0.0.1:5391/auth",{waitUntil:"networkidle",timeout:60000}).catch(()=>{});await p.waitForTimeout(1500);
const dir=process.env.OUT||"/tmp/claude-0";
for (const [i,t] of [[1,0],[2,3500],[3,3500]]){await p.waitForTimeout(t);console.log(i,await p.evaluate(()=>getComputedStyle(document.querySelector(".ax-auth-card")).backgroundPosition));await p.screenshot({path:`${dir}/card-gradient-${i}.png`});}
await b.close();})();
