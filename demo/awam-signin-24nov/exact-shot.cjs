const { chromium } = require("playwright");
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:1280,height:800},deviceScaleFactor:1.085});
await p.goto("http://127.0.0.1:5391/auth",{waitUntil:"networkidle",timeout:60000}).catch(()=>{});await p.waitForTimeout(2200);
const d=process.env.OUT||"/tmp/claude-0";
for (const [i,t] of [[1,0],[2,2500],[3,2500]]){await p.waitForTimeout(t);await p.screenshot({path:`${d}/exact-single-light-${i}.png`,clip:{x:0,y:0,width:440,height:800}});}
await p.screenshot({path:d+"/exact-1280.png"});await b.close();})();
