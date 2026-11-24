const { chromium } = require("playwright");
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:1280,height:800},deviceScaleFactor:1.085});
await p.goto("http://127.0.0.1:5391/auth",{waitUntil:"networkidle",timeout:60000}).catch(()=>{});await p.waitForTimeout(2500);
await p.screenshot({path:(process.env.OUT||"/tmp/claude-0")+"/exact-1280.png"});await b.close();})();
