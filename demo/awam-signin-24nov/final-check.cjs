const { chromium } = require("playwright");
(async()=>{const b=await chromium.launch();
for (const [w,h,rm] of [[1280,800,"no-preference"],[1280,800,"reduce"],[820,1000,"no-preference"],[390,844,"no-preference"]]){
const p=await b.newPage({viewport:{width:w,height:h},reducedMotion:rm,deviceScaleFactor:1.085});const errs=[];p.on("pageerror",e=>errs.push(e.message));p.on("console",m=>{if(m.type()==="error")errs.push(m.text().slice(0,120))});
await p.goto("http://127.0.0.1:5391/auth",{waitUntil:"networkidle",timeout:60000}).catch(e=>errs.push("goto "+e.message));await p.waitForTimeout(3500);
const o=await p.evaluate(()=>({h1:document.querySelector("h1")?.innerText,inputs:document.querySelectorAll("input").length,sw:document.documentElement.scrollWidth,cw:document.documentElement.clientWidth,dust:!!document.querySelector(".ax-auth-dust"),rule52:document.body.innerText.includes("Rule 52")}));
console.log(w,rm,JSON.stringify(o),JSON.stringify(errs.slice(0,3)));await p.screenshot({path:`/tmp/claude-0/final-${w}-${rm}.png`});await p.close();}
await b.close();})();
