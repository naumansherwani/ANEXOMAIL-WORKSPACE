const { chromium } = require("playwright");
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:1280,height:800},deviceScaleFactor:1.085});
await p.goto("http://127.0.0.1:5391/auth",{waitUntil:"networkidle",timeout:60000}).catch(()=>{});await p.waitForTimeout(2000);
const d=process.env.OUT||"/tmp/claude-0";const tops=[];
for (const i of [1,2,3]){await p.waitForTimeout(i===1?0:2500);tops.push(await p.evaluate(()=>Math.round(document.querySelector(".ax-auth-scan").getBoundingClientRect().top)));await p.screenshot({path:`${d}/still-light-${i}.png`,clip:{x:0,y:0,width:440,height:800}});}
console.log("light top at 3 moments:",tops);await p.screenshot({path:d+"/still-light-full.png"});await b.close();})();
