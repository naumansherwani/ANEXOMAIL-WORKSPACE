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
 const obs=()=>{const t=stack.querySelector('p');if(t)t.classList.add('gg-tag')};obs();setInterval(obs,200);
});
await p.waitForTimeout(700);await p.screenshot({path:'/tmp/claude-0/s/awam-r52-a.png'});
await p.waitForTimeout(3300);await p.screenshot({path:'/tmp/claude-0/s/awam-r52-b.png'});
await b.close()})()
