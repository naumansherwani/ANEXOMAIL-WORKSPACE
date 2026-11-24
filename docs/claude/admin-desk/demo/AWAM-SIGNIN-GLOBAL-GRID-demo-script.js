const {chromium}=require('playwright');(async()=>{const b=await chromium.launch();
const p=await b.newPage({viewport:{width:1280,height:800},deviceScaleFactor:2});
await p.goto('http://127.0.0.1:5391/auth',{waitUntil:'networkidle',timeout:60000}).catch(()=>{});
await p.waitForTimeout(3000);
await p.evaluate(()=>{
 for(const e of document.querySelectorAll('h1,h2,p,div')){if(e.children.length===0){const t=e.textContent.trim();if(t==='Sign in'&&e.tagName!=='BUTTON'){e.textContent='Enter The Global Grid'}else if(t.startsWith('Your mail, people, calendar and work')){e.textContent='Your enterprise. Your network. Your access.'}}}
 const aside=document.querySelector('aside');
 const st=document.createElement('style');st.textContent=`
 .gg-grid{position:absolute;inset:0;pointer-events:none;background-image:linear-gradient(rgba(255,255,255,.07) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.07) 1px,transparent 1px);background-size:44px 44px;-webkit-mask-image:radial-gradient(ellipse 75% 60% at 50% 45%,#000 20%,transparent 75%);mask-image:radial-gradient(ellipse 75% 60% at 50% 45%,#000 20%,transparent 75%);animation:ggdrift 18s linear infinite}
 @keyframes ggdrift{from{background-position:0 0}to{background-position:44px 44px}}
 .gg-scan{position:absolute;left:0;right:0;height:140px;pointer-events:none;background:linear-gradient(180deg,transparent,rgba(160,190,255,.10),transparent);animation:ggscan 7s ease-in-out infinite}
 @keyframes ggscan{from{top:-140px}to{top:100%}}
 .gg-eyebrow{font-size:11px;letter-spacing:.42em;color:rgba(200,215,255,.6);text-transform:uppercase;margin-bottom:-14px}`;
 document.head.appendChild(st);
 const g=document.createElement('div');g.className='gg-grid';const s=document.createElement('div');s.className='gg-scan';
 aside.insertBefore(g,aside.children[2]);aside.insertBefore(s,aside.children[3]);
 const stack=aside.querySelector('.relative.z-10');const eb=document.createElement('div');eb.className='gg-eyebrow';eb.textContent='Inside the Global Grid';
 const tag=stack.children[1];stack.insertBefore(eb,tag);
});
await p.waitForTimeout(600);await p.screenshot({path:'/tmp/claude-0/s/awam-cine-a.png'});
await p.waitForTimeout(3300);await p.screenshot({path:'/tmp/claude-0/s/awam-cine-b.png'});
await b.close()})()
