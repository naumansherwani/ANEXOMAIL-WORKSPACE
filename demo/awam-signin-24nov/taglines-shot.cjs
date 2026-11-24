// his 13:35: the dot-dot-dot rotating taglines; one crop per tagline
const { chromium } = require("playwright");
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:1280,height:800},deviceScaleFactor:1.085});
await p.goto("http://127.0.0.1:5391/auth",{waitUntil:"networkidle",timeout:60000}).catch(()=>{});await p.waitForTimeout(1500);
const d=process.env.OUT||"/tmp/claude-0";const seen=new Set();
for (let k=0;k<60&&seen.size<8;k++){const t=await p.evaluate(()=>document.querySelector("aside p")?.innerText);
 if(t&&!seen.has(t)){seen.add(t);await p.waitForTimeout(700);await p.screenshot({path:`${d}/tagline-${seen.size}.png`,clip:{x:0,y:60,width:440,height:200}});console.log(seen.size,t);}
 await p.waitForTimeout(500);}
await b.close();})();
