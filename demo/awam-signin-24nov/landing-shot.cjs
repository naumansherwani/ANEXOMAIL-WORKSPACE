const { chromium } = require("playwright");
(async()=>{const b=await chromium.launch();
for (const [w,h] of [[1280,800],[390,844]]){const p=await b.newPage({viewport:{width:w,height:h}});
await p.goto("http://127.0.0.1:5391/",{waitUntil:"networkidle",timeout:60000}).catch(()=>{});await p.waitForTimeout(2500);
const f=await p.$("footer");await f.scrollIntoViewIfNeeded();await p.waitForTimeout(800);
const o=await p.evaluate(()=>({sw:document.documentElement.scrollWidth,cw:document.documentElement.clientWidth}));console.log(w,JSON.stringify(o));
await f.screenshot({path:`${process.env.OUT||"/tmp/claude-0"}/landing-footer-${w}.png`});await p.close();}
await b.close();})();
