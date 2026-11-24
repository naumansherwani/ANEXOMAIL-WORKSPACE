const { chromium } = require("playwright");
(async()=>{const b=await chromium.launch();
for (const [w,h] of [[1280,800],[1366,768],[1920,1080]]){const p=await b.newPage({viewport:{width:w,height:h},deviceScaleFactor:1.085});
await p.goto("http://127.0.0.1:5391/auth",{waitUntil:"networkidle",timeout:60000}).catch(()=>{});await p.waitForTimeout(3500);
const o=await p.evaluate(()=>{const u=document.querySelector("aside ul");const a=document.querySelector("aside").getBoundingClientRect();const r=u.getBoundingClientRect();return {ulTop:r.top,ulBottom:r.bottom,asideH:a.height,rule:document.body.innerText.includes("Rule 52")}});
console.log(w,h,JSON.stringify(o));await p.screenshot({path:`${process.env.OUT||"/tmp/claude-0"}/list-${w}.png`});await p.close();}
await b.close();})();
