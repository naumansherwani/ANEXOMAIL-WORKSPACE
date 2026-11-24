const { chromium } = require("playwright");
(async()=>{const b=await chromium.launch();
for(const [w,h] of [[1280,800],[820,1000],[390,844]]){const p=await b.newPage({viewport:{width:w,height:h}});
await p.goto("http://127.0.0.1:5391/auth",{waitUntil:"networkidle",timeout:60000}).catch(()=>{});await p.waitForTimeout(3500);
const o=await p.evaluate(()=>({sw:document.documentElement.scrollWidth,cw:document.documentElement.clientWidth,rule:document.body.innerText.includes("Rule 52"),h:document.querySelector("h1")?.innerText}));
console.log(w,JSON.stringify(o));await p.screenshot({path:`/tmp/claude-0/auth-${w}.png`});await p.close();}
await b.close();})();
