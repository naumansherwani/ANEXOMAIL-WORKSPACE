const { chromium } = require("playwright");
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:1389,height:868}});
await p.goto("http://127.0.0.1:5391/auth",{waitUntil:"networkidle",timeout:60000}).catch(()=>{});
for(const t of [1,3,5,7,9,11]){await p.waitForTimeout(t===1?1000:2000);
const c=await p.evaluate(()=>{const e=document.querySelector(".ax-auth-cinema-bg");return getComputedStyle(e).backgroundPosition});
await p.screenshot({path:`/tmp/claude-0/phase-${t}.png`,clip:{x:0,y:0,width:478,height:868}});console.log(t,c);}
await b.close();})();
