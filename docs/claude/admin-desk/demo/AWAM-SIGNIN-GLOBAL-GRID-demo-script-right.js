const {chromium}=require('playwright');(async()=>{const b=await chromium.launch();
const p=await b.newPage({viewport:{width:1280,height:800},deviceScaleFactor:2});
await p.goto('http://127.0.0.1:5391/auth',{waitUntil:'networkidle',timeout:60000}).catch(()=>{});
await p.waitForTimeout(3000);
await p.evaluate(()=>{
 for(const e of document.querySelectorAll('h1,h2,p,div')){if(e.children.length===0){const t=e.textContent.trim();if(t==='Sign in'&&e.tagName!=='BUTTON'){e.textContent='Enter The Global Grid'}else if(t.startsWith('Your mail, people, calendar and work')){e.textContent='Your enterprise. Your network. Your access.'}}}
 const aside=document.querySelector('aside');
 const st=document.createElement('style');st.textContent=`
 aside .ax-auth-cinema-bg{background:linear-gradient(135deg,#0b1220 0%,#1E3557 38%,#2C4C79 62%,#0b1220 100%)!important;background-size:400% 400%!important}
 aside .ax-auth-cinema-mesh{background-image:radial-gradient(ellipse 60% 50% at 35% 30%,rgba(111,166,242,.20) 0%,transparent 70%),radial-gradient(ellipse 50% 60% at 70% 75%,rgba(195,204,216,.10) 0%,transparent 70%)!important}
 .gg-grid{position:absolute;inset:0;pointer-events:none;background-image:linear-gradient(rgba(195,204,216,.08) 1px,transparent 1px),linear-gradient(90deg,rgba(195,204,216,.08) 1px,transparent 1px);background-size:44px 44px;-webkit-mask-image:radial-gradient(ellipse 75% 60% at 50% 45%,#000 20%,transparent 75%);mask-image:radial-gradient(ellipse 75% 60% at 50% 45%,#000 20%,transparent 75%);animation:ggdrift 18s linear infinite}
 @keyframes ggdrift{from{background-position:0 0}to{background-position:44px 44px}}
 .gg-scan{position:absolute;left:0;right:0;height:140px;pointer-events:none;background:linear-gradient(180deg,transparent,rgba(195,204,216,.10),transparent);animation:ggscan 7s ease-in-out infinite}
 @keyframes ggscan{from{top:-140px}to{top:100%}}
 .gg-eyebrow{font-size:10.5px;letter-spacing:.5em;margin-right:-.5em;color:#C3CCD8;opacity:.75;text-transform:uppercase;margin-bottom:-14px}
 aside .gg-tag{background-image:linear-gradient(170deg,#F4F7FB 0%,#C3CCD8 55%,#8E9BB0 100%);-webkit-background-clip:text;background-clip:text;color:transparent!important}
 aside .gg-rule{height:1px;width:80px;background:linear-gradient(90deg,transparent,#6FA6F2,transparent)}
 aside span.text-\\[13px\\]{color:#C3CCD8}`;
 document.head.appendChild(st);
 const g=document.createElement('div');g.className='gg-grid';const s=document.createElement('div');s.className='gg-scan';
 aside.insertBefore(g,aside.children[2]);aside.insertBefore(s,aside.children[3]);
 const stack=aside.querySelector('.relative.z-10');const eb=document.createElement('div');eb.className='gg-eyebrow';eb.textContent='Inside the Global Grid';
 stack.insertBefore(eb,stack.children[1]);
 
 const trust=stack.querySelector('.flex.flex-col.gap-4');
 if(trust){trust.innerHTML='';const items=["Rust WASM kernel verifies every answer","Signed answers: Ed25519, replay refused (Rule 52)","Rust + Tokio + Axum engine","WebTransport · HTTP/3 · QUIC","TLS 1.3 · AES-256-GCM · X25519MLKEM768","Argon2id · passkeys · device-bound sessions","PostgreSQL 16 RLS · hash-chained ledger"];
 trust.style.gap='11px';items.forEach((t,i)=>{const d=document.createElement('div');d.style.cssText='display:flex;align-items:center;gap:10px;text-align:left;color:#C3CCD8;font-size:12.5px;letter-spacing:-.005em;opacity:0;animation:ggin .6s ease forwards;animation-delay:'+(0.2+i*0.12)+'s';d.innerHTML='<span style="width:5px;height:5px;border-radius:50%;background:#6FA6F2;box-shadow:0 0 8px #6FA6F2;flex:none"></span><span>'+t+'</span>';trust.appendChild(d)});
 const k=document.createElement('style');k.textContent='@keyframes ggin{from{opacity:0;transform:translateX(-8px)}to{opacity:.9;transform:none}}';document.head.appendChild(k)}

 const rp=document.querySelector('main > div.flex.flex-1');
 const rs=document.createElement('style');rs.textContent=`
 main{background:#070d1a!important}
 main > div.flex.flex-1{position:relative;background:radial-gradient(ellipse 70% 55% at 50% 42%,rgba(44,76,121,.38) 0%,rgba(30,53,87,.22) 40%,transparent 75%),linear-gradient(180deg,#0a1324 0%,#070d1a 60%,#05080f 100%)!important;overflow:hidden}
 .gg-rgrid{position:absolute;inset:0;pointer-events:none;background-image:linear-gradient(rgba(195,204,216,.05) 1px,transparent 1px),linear-gradient(90deg,rgba(195,204,216,.05) 1px,transparent 1px);background-size:44px 44px;-webkit-mask-image:radial-gradient(ellipse 70% 60% at 50% 45%,#000 10%,transparent 78%);mask-image:radial-gradient(ellipse 70% 60% at 50% 45%,#000 10%,transparent 78%);animation:ggdrift 18s linear infinite}
 .gg-rbeam{position:absolute;left:50%;top:-10%;width:2px;height:120%;pointer-events:none;background:linear-gradient(180deg,transparent,rgba(111,166,242,.35),transparent);transform:translateX(-50%);filter:blur(1px);opacity:.5}
 .gg-rfloor{position:absolute;left:10%;right:10%;bottom:0;height:2px;pointer-events:none;background:linear-gradient(90deg,transparent,rgba(224,170,90,.55),transparent);box-shadow:0 0 40px 6px rgba(224,170,90,.18)}
 .ax-in > div.relative, .ax-in > div[class*=rounded]{ }
 main .ax-in [class*="rounded-2xl"],main .ax-in [class*="rounded-3xl"]{background:linear-gradient(160deg,rgba(24,40,68,.72),rgba(10,18,34,.78))!important;border:1px solid rgba(160,190,235,.22)!important;backdrop-filter:blur(14px);box-shadow:0 0 0 1px rgba(111,166,242,.06),0 30px 80px rgba(0,0,0,.55),0 0 90px rgba(44,76,121,.35)!important}
 .gg-dust{position:absolute;inset:0;pointer-events:none}`;
 document.head.appendChild(rs);
 for(const c of ['gg-rgrid','gg-rbeam','gg-rfloor']){const d=document.createElement('div');d.className=c;rp.insertBefore(d,rp.firstChild)}
 const cv=document.createElement('canvas');cv.className='gg-dust';rp.insertBefore(cv,rp.firstChild);cv.width=rp.clientWidth;cv.height=rp.clientHeight;const x=cv.getContext('2d');
 const P=Array.from({length:46},()=>({x:Math.random(),y:Math.random(),v:.0004+Math.random()*.0012,s:.5+Math.random()*1.3,p:Math.random()*6}));
 const f=()=>{x.clearRect(0,0,cv.width,cv.height);for(const p of P){p.y-=p.v;p.p+=.03;if(p.y<0){p.y=1;p.x=Math.random()}x.globalAlpha=.2+.45*Math.abs(Math.sin(p.p));x.fillStyle='#bfd6ff';x.beginPath();x.arc(p.x*cv.width,p.y*cv.height,p.s,0,6.3);x.fill()}requestAnimationFrame(f)};f();
 const obs=()=>{const t=stack.querySelector('p');if(t)t.classList.add('gg-tag')};obs();setInterval(obs,200);
});
await p.waitForTimeout(700);await p.screenshot({path:'/tmp/claude-0/s/awam-right-a.png'});
await p.waitForTimeout(3300);await p.screenshot({path:'/tmp/claude-0/s/awam-right-b.png'});
const q=await b.newPage({viewport:{width:390,height:844},deviceScaleFactor:2});await q.goto('http://127.0.0.1:5391/auth',{waitUntil:'networkidle',timeout:60000}).catch(()=>{});await q.waitForTimeout(3000);
await q.evaluate(()=>{for(const e of document.querySelectorAll('h1,h2,p,div')){if(e.children.length===0){const t=e.textContent.trim();if(t==='Sign in'&&e.tagName!=='BUTTON'){e.textContent='Enter The Global Grid'}else if(t.startsWith('Your mail, people, calendar and work')){e.textContent='Your enterprise. Your network. Your access.'}}}
const rp=document.querySelector('main > div.flex.flex-1');const rs=document.createElement('style');rs.textContent=`main{background:#070d1a!important}main > div.flex.flex-1{position:relative;background:radial-gradient(ellipse 90% 50% at 50% 40%,rgba(44,76,121,.38) 0%,transparent 75%),linear-gradient(180deg,#0a1324 0%,#070d1a 60%,#05080f 100%)!important}main .ax-in [class*="rounded-2xl"],main .ax-in [class*="rounded-3xl"]{background:linear-gradient(160deg,rgba(24,40,68,.72),rgba(10,18,34,.78))!important;border:1px solid rgba(160,190,235,.22)!important;box-shadow:0 30px 80px rgba(0,0,0,.55),0 0 90px rgba(44,76,121,.35)!important}`;document.head.appendChild(rs)});
await q.waitForTimeout(600);await q.screenshot({path:'/tmp/claude-0/s/awam-right-390.png'});
await b.close()})()
