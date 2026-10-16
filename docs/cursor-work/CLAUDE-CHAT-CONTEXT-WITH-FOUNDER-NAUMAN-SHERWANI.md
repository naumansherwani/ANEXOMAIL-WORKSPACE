# CLAUDE CHAT CONTEXT WITH FOUNDER NAUMAN SHERWANI

> ## FOUNDER KA RULE (locked, 17 Oct 2026)
> **Jo bhi Claude / agent / session founder Nauman Sherwani se chat karega, woh PEHLE yeh poori file padhega, PHIR chat karega.**
> Yeh founder ka rule hai. Bina padhe chat shuru nahi hoti, aur founder se woh sawal nahi poochhe jate jinka jawab is file mein likha hai.

Yeh file isliye hai ke chat compact ho ya naya chat khule (claude.ai ka Claude chat ho ya Claude Code ka cloud session), agla Claude **wahin se** kaam shuru kare jahan pichla chhoda tha. Founder ko kuch dobara samjhana nahi parna chahiye. Isko update karna AGENTS.md **Rule 18** hai. (Pehle yeh `CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md` thi; founder ke kehne par 17 Oct 2026 ko is naam se badli — ek hi file, duplicate nahi.)

Aakhri update: **17 Oct 2026, 04:35 PKT**.

---

## 0. Naya chat shuru karte hi (tarteeb)

0. **Founder ka rule (upar):** pehle yeh file, phir chat.
1. `AGENTS.md` (Rule 1–18) — locked qaide.
2. Yeh file poori. Khaas kar **section 1 (ABHI KA QADAM)** aur **section 4 (qaide)**.
3. `docs/anexomail-blueprint.md` ke sections: "11 Oct 2026 — remaining work" (item #1–#42, ek hi list), "13 Oct" (E19–E26), "15 Oct" (U1–U7). Har item ka status wahin hai.
4. Founder se woh mat poochho jo yahan likha hai. Section 1 se seedha chalo.
5. Har natije ke baad is file ko update karo (Rule 18, section 11).

---

## 1. ABHI KA QADAM (17 Oct 2026)

Founder **asli browser login** se test accounts ek ek karke check kar raha hai. Agent har waqt **sirf ek cheez** batata hai ke kya dekhna hai; founder dekh le to agli. Current account: **`pro.buyer@anexomail.com`** (Pro plan, Business workspace). Basic founder ne chhod diya ("Basic ko chhodo, Pro karo"); Pro ke baad Business, phir Business Pro.

Ho chuka (founder ke screenshot se, 16 Oct 21:37 PKT):
- Pro rail: Dashboard | Mail | People | Calendar | Work | CRM | Domains. Org aur ANEXOChat nahi. Sahi.
- Rail ka Pro text ab naya: "Shared inbox with collision guard, boards, tasks and CRM — your team, organised." Pehle founder ko purana "…ANEXOChat — teams done right" dikha tha; wajah browser/service-worker ka purana cache thi (code mein naya tha). Hard refresh se theek hua.
- Dashboard par: storage "44 B / 50 GB · 10 GB × 5 mailboxes", badge "probuyer.axonetis.com · Domain not verified · Finish setup", Received 1, Sent 1, Send success 50%.

**Domains page ka pehla look (founder ka screenshot, 17 Oct 02:37 PKT) — 3 cheezein pakdi gayin:**
1. **Scroll bug (asli bug):** page neeche se kat raha tha ("No company addresses yet." aadha). Wajah: `AppShell` `h-screen overflow-hidden` hai aur `app.domains.tsx` par scroll dabba (`min-h-0 flex-1 overflow-y-auto`) tha hi nahi — wizard ke 5 records tak pohanchna mumkin nahi tha.
2. **Dashboard vs Domains tazaad:** dashboard "probuyer.axonetis.com · Domain not verified · Finish setup" dikhata tha, Domains page "0 of 3 · No company domain yet". Wajah: domain `organisations.domain` mein (signup/E28 seed) hai, `org_domains` khali (mera Rust test usay hata chuka tha). Asli buyer ke saath bhi yahi hota.
3. **Khali page sada tha** (plain card, CTA ek kone mein).

Fix (repo mein, 17 Oct 2026): `src/routes/app.domains.tsx` dobara likha — scroll dabba + wizard scroll-into-view, signup wala domain "Finish connecting <domain>" suggestion (dashboard summary se), hero empty state (3-step preview), jud'ti hui step lakeer, record cards 1/5…5/5, live ring (x/5) + countdown, DKIM row khud refresh, verified celebration, Addresses ka locked preview. Syntax `bun build --no-bundle` green; asli build server par.

**17 Oct 02:49 PKT:** founder ne claude.ai wale Claude chat ka context paste kiya (Appendix A) aur kaha: naye naam ki file banao, "her latest command repo mein update ho", aur yeh rule likho ke founder se chat karne wala pehle yeh context padhe. Ho gaya (yeh file, AGENTS.md Rule 18, `.cursor/rules/founder-chat-context.mdc`).

**Domains page browser mein dekha (founder ke 2 photo, 17 Oct 03:06 PKT):** scroll theek (scrollbar aaya, neeche "No company addresses yet." poori dikhi); hero "Finish connecting probuyer.axonetis.com" + 3 qadam + "Connect probuyer.axonetis.com" + "Use a different domain" + cap note; Addresses ka locked card. **Founder ka sawal:** kya yeh duniya ka best UI hai? **Mera jawab (honest): nahi — achha professional SaaS level, ~7/10.** Wajahein: sirf copy-paste (registrar detect/ek-click DNS nahi), email page par dikhti nahi, harkat/skeleton kam, "Use a different domain" button jaisa nahi lagta, login address locked card ke neeche. Yeh #8a/#8b ke naam se blueprint mein TODO likhe. Photo se contrast pakka nahi parha (code mein button navy + near-white text hai, photo mein cyan/dhundla) — asli screenshot (Win+Shift+S) maangna.

**17 Oct 03:19 PKT — founder ki maang (is ke baad ka kaam):** (1) Domains ki kamzoriyan theek karo (#8a) aur registrar pehchanna (#8b); (2) UI itni advance ke Vercel se aage ho, tab hi dikhana; phir poori website ke liye "duniya ka best"; (3) "cinematic / cinema feel UI" kya hota hai samjhao; (4) **axonetis.com founder ka doosra project hai, sirf TEST domain** — ANEXOMAIL domain nahi bechta, maqsad hai "user business email kaise banaye"; (5) "repo mein sab code hai, server par sab hai, masla compact ke baad bhool jana hai — latest technology rule par ek hi baar mein theek karo".

**Ho gaya (17 Oct ~03:35 PKT, repo mein, READY):** `src/routes/app.domains.tsx` cinematic standard par dobara likha — hero mein "From: you@<domain>" mail preview, "Use a different domain" asli button, login address pehle, skeleton loader, stagger, registrar auto-pehchan (DNS-over-HTTPS se), step 3 ka jashn. **Asli UI sandbox mein dekhi gayi** (`docs/cursor-work/frontend/ui-harness/`: har state + 390 px screenshots). Standard + poori website ka rasta: `docs/cursor-work/frontend/cinematic-ui-standard.md`. Deploy ab 13.0 (13.6 ka purana block shamil). **Founder ke browser mein dekhna baqi — isliye #8/#8a READY, DONE nahi.**

**17 Oct 03:45 PKT — founder ka asli browser (page text paste): Domains v2 server par LIVE hai aur wizard qadam 1→2 chala.** Nateeja: "1 of 3 domain · Pro", step rail, "At your registrar…" copy, Namecheap/GoDaddy/Cloudflare/Other tabs + "Open Namecheap", 5 record cards (TXT `_anexomail-verify` value `e214…`, MX `@` → `mail.anexomail.com` prio 10, SPF `v=spf1 a:mail.anexomail.com ~all`, DKIM `anexo1._domainkey` "Key is being prepared", DMARC `_dmarc`), "I've added them — check now" / "Finish later", Addresses (login address pehle, locked preview). Yaani qadam 1–2 live DONE-nayi cheez; qadam 3 (live ticks/verified) aur asli DNS check baqi. **Do asli kamiyan mili:** (1) registrar auto-pehchan `probuyer.axonetis.com` par nahi chali (subdomain ke apne NS nahi hote — parent `axonetis.com` poochhna tha), (2) subdomain par agar DNS parent zone ka ho to Name lamba likhna parta hai (`@` → `probuyer`, `_dmarc` → `_dmarc.probuyer`) — page ne yeh nahi bataya. Dono repo mein theek (blueprint 8c, READY); manifest sha badla.

**17 Oct 03:54 PKT — 13.0 ASLI SERVER PAR GREEN (founder ka output):** `origin/main = b58694f`, "memory/docs: 4 file(s) taza", `wrote src/routes/app.domains.tsx`, build OK, `/health 200`, `/app/domains 200`, memory stamp server par `03:55 PKT` = repo. Backup `/root/i9/sync-20261016-224907`. Server ki dirty tree ki list mili (#10 survey): `M` = AGENTS.md, bun.lock, 3 docs index/plan files, `src/components/app/{AppShell,CommandPalette,compose/ComposeStudio,dashboard/Greeting,dashboard/Panels,mail/MailRail}.tsx`, `src/lib/{dashboard,mail,plan-surface,workspace-i18n}.ts`, `src/routeTree.gen.ts`, `src/routes/app.admin.addresses.tsx`, `src/routes/app.mail.$folder.tsx`; `??` = `.env` (secret, repo mein KABHI nahi), purani installer scripts (`e3/e7/e30/i8-*`), `t7/t16` scripts, `E27` SQL, `mail-identities-locked…md`. Kaun si `M` file server par repo se alag hai — agle pull.sh se khud dikhega (neeche `git diff --stat origin/main`).

**FOUNDER KA MAQSAD (17 Oct 03:54 PKT, locked):** "real user ko website ka best experience dena; test account se real user wali sab cheezein nahi ho sakti, lekin jitna ho sake **user ki tarah socho**." Is liye har screen ko **asli user ke 5 minute** ki nazar se dekho (kya sochega, kahan phansega, kya kho sakta hai), aur jo test se sabit nahi ho sakta (payment, asli registrar par DNS, bahar se aane wali mail, spam folder, asli phone) use alag "founder ko khud dekhna" list mein likho. Real-user khatre ki list: blueprint #8c+.

**17 Oct 04:20 PKT — #8c banaya (READY, sandbox mein dekha):** wizard qadam 2 ab domain ke MX/SPF DNS-over-HTTPS se dekhta hai; pehle se Google/Microsoft/Zoho… ho to warning ("is domain par mail pehle se hai, MX lagane se purane mailboxes band") aur SPF ka merged value + Copy. Subdomain (probuyer) par kuch nahi aata (uska apna MX nahi). Manifest sha ab `04b1b3542f4e9706`. pull.sh ab server-vs-repo ka `git diff --stat origin/main` bhi dikhata hai (dirty-tree survey khud). **Agla qadam wahi: 13.0 dobara + qadam 3 ka check (DNS badle bina).**

**17 Oct 04:06 PKT — founder ne 13.0 (824ab3a) chalaya + 7 photo bheji: asli server par sab theek.** Step 2: "We found your DNS is at Namecheap" aaya (**axonetis.com ka DNS Namecheap par hai**), subdomain note, "If DNS zone is axonetis.com" ke lambe Name (, , , ), DKIM ki asli key (v=DKIM1; k=rsa; p=MIIB…) aa gayi. Step 3: "Checking probuyer.axonetis.com", 0/5 Waiting, countdown, "Checking…", Check now — asli backend par chal raha hai. (Photo mein button cyan/dhundla aur cards grey hain: laptop ki screen/camera ka asar lagta hai, harness mein navy + gehra; asli Win+Shift+S screenshot se pakka karna.) Pull output: server ki  files (AppShell, ComposeStudio, Greeting, mail.ts …) **repo ke BARABAR nikli** ( docs/anexomail-blueprint.md                        |  10 ++
 docs/cursor-work/frontend/ui-harness/build.mjs     |   1 +
 .../frontend/ui-harness/stubs/router.ts            |   5 +-
 docs/cursor-work/server/DEPLOY-MANIFEST.txt        |   2 +-
 src/routes/app.domains.tsx                         | 170 ++++++++++++++++++---
 5 files changed, 166 insertions(+), 22 deletions(-) mein sirf  4 lines,  42 lines, aur untracked /); yani server "dirty" sirf is liye ke server ka git HEAD purana hai.

**FOUNDER KA NAYA HUKM (17 Oct 04:06 PKT, locked):** CEO ki tarah socho; competitor **Google Workspace aur Zoho Mail**; pehle Zoho ka basic flow karo, phir ANEXOMAIL ko un se behtar banao. **Ho gaya:**  (official pages se verify kiya hua baseline + ANEXOMAIL ki jagah + tarteeb); blueprint 8d–8m; **8g READY** ("Someone else manages your DNS?": email instructions + copy all, Zoho ke "Send to DNS admin" jaisa, bina server ke) aur **8h READY** (step 3: "aap ka inbox DNS ke intezar mein bhi chal raha hai" + Open your inbox) — sandbox mein dekha, manifest sha `d3c72ea4e9351247`. **Agle (tarteeb):** 8f pehli mail ka test → 8i IMAP/SMTP settings → 8j IMAP import → 8k dashboard checklist → 8l Domain Connect (founder decide) → 8m catch-all/forwarding/vacation. AI sab se aakhir (#41).

**Agla (abhi pending, 17 Oct 03:55 PKT):** founder 13.0 dobara chalaye (manifest ka sha ab `23b0d74772a46f83`: subdomain fix) + Ctrl+Shift+R. Phir `pro.buyer` > Domains mein wohi wizard (domain pehle se jura hai, qadam 2). Dikhna chahiye: "We found your DNS is at …" wali hari line (axonetis.com ka DNS jahan hai), "probuyer.axonetis.com is a subdomain of axonetis.com" ka note, har card ke neeche "If DNS zone is axonetis.com" ka lamba Name. Phir **"I've added them — check now"** dabaye **bina koi DNS badle** (axonetis.com founder ka doosra project hai — apex par `@` MX/SPF kabhi nahi) aur qadam 3 ka screenshot bheje: 0/5 "Waiting", countdown, "Key is being prepared" wala row. Asli verified tick ka proof baad mein (alag test domain ya sirf `probuyer` subdomain ke naam se, jab founder tay kare).

Uske baad wizard ka proof (D) ek ek qadam: Connect → naam (suggestion chip) → 5 DNS records + Namecheap/GoDaddy/Cloudflare tabs + Copy buttons → live ticks. Phir E ka proof (Compose "Send from", Inbox address label, aane wali mail par bhi).

---

## 2. Founder ki maangen jo abhi khuli hain

- **D proof** — domain wizard founder ke browser mein dikhe aur kaam kare (backend server par green hai, browser ka dekhna baqi). `#8` isliye READY hai, DONE nahi.
- **E proof** — `#7`: Compose "From" mein company address, Inbox mein address ka label, aane wali mail dono par. Backend 15 Oct ko proven; browser ka proof baqi. `#7` READY.
- **Frontend UI/UX duniya ke level ka** (founder: "duniya ka advance Frontend UI UX", "Vercel se advance", poori website). Domains page cinematic standard par dobara likha gaya (READY, founder ka browser baqi). **Agli screens:** `docs/cursor-work/frontend/cinematic-ui-standard.md` ke "Poori website ka rasta" table ki tarteeb (Dashboard → Compose → Inbox → baqi). Har screen: harness screenshot (desktop + 390 px) → sha-guarded single-file block → founder ka asli screenshot. `src/lib/domains.ts` ke hooks na badlo, `vite.config.ts` / `package.json` / `bunfig.toml` na chhuo.
- **Compact-chat masla** — yeh file + Rule 18 (17 Oct 2026 ko founder ke kehne par bani).

---

## 3. Locked tarteeb (founder, 14 Oct 2026)

1. **User side**, blueprint ke number se: #10, #13, #14–#35, #37–#39 (#7, #8 pehle browser se confirm hon).
2. **Founder side** (`[FOUNDER]` tag): #3a, #11, #12, #36, #36a.
3. **ANEXOChat** (#40, #40a) — Phase 32+ sirf founder ke paste par.
4. **Sab se aakhir** `ai.anexomail.com` (#41). AI ko haath nahi lagana.
5. Real test tarteeb (#20): Basic → Pro → Business → Business Pro.

Company addresses ka **ek unified inbox**; `hello@` ka kaam founder-side. **Ali (`alikhan@anexomail.com`) ko delete nahi karna.**

---

## 4. Founder ke saath kaam ke qaide (locked)

- **Zubaan:** Roman Urdu, "aap", "kero/chalao". Kabhi "tu/tera/kar" nahi. Jawab chhote.
- **Seedha sawal = seedha jawab chat mein.** Jawab ke liye repo mein mat jao, repo ki baat mat chhedo jab tak woh na kahe. Founder bohot jaldi gussa hota hai jab agent repo-centric ho jata hai ya lamba block deta hai.
- **Manual test = ek waqt mein ek cheez** ("jab ek dekh lo gay phir next").
- **Bina zaroorat sawal nahi.** Gate / "PASS PASS" scripts nahi. Asli output wale seedhe commands (curl code, grep, psql, pm2).
- **Rule 15:** server ka sach server par. Agent server par kuch nahi chala sakta; chat mein ek copy-paste block deta hai, founder chalata hai aur output paste karta hai. Output aane se pehle "DONE" nahi.
- **Rule 17:** test browser se nahi (SQL-seeded accounts, token, curl). Ab founder UI khud apne login se dekh raha hai, to browser sirf wahan jahan screen dekhni zaroori ho.
- **Har jawab jo repo badle, uske aakhir mein founder ko 13.0 ki EK pull command do** (founder, 17 Oct 03:39 PKT: "hamesha pull ki command do, pm2 restart hamesha"). Woh command `pull.sh` chalati hai: server ki memory file (yeh file), AGENTS.md aur docs taza karti hai, manifest ki code files sha-guard se lagati hai, aur **hamesha** `pm2 restart anexomail-web --update-env && pm2 save`. Code file badlo to `DEPLOY-MANIFEST.txt` mein uska sha usi commit mein badlo.
- **Har deploy/pull block mein `pm2 restart <app> --update-env && pm2 save` hamesha** (founder, 17 Oct 2026): web badla to `anexomail-web`, Rust badla to `anexomail-rust`, Brain badla to `anexomail-leo`. `polar-rust-payment` kabhi nahi.
- **Rule 5:** status sirf DONE (live verify) / READY / TODO.
- **Secrets repo ya chat mein nahi.** Test passwords sirf server par `/root/test-accounts/<handle>.pw`.
- **SQL fail** ho to usi file ko theek karo (`_v2` nahi). Naya SQL = E-series (`docs/cursor-work/sql/E<n>_….sql`); abhi tak E30 tak bana hai, agla E31.
- **Git:** force-push / amend / squash nahi. Har commit ke aakhir mein do trailers: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` aur `Claude-Session: <is chat ka session URL>` (URL har chat ka system-reminder deta hai).
- **Branding:** build-platform ka naam/logo repo ya UI copy mein nahi. NEXATECT sirf internal, public copy mein nahi.
- **Backend:** naya kaam Rust :3200 primary; Bun sirf fallback.

---

## 5. System map (founder ka Hetzner server — asli system)

| Cheez | Jagah |
|---|---|
| Web (SSR, Bun) | `/opt/anexomail-web`, pm2 `anexomail-web`, :3000. Build `bun run build:bun`, output `.output/` |
| Brain (Bun, fallback) | `/opt/anexomail`, pm2 `anexomail-leo`, :3100 |
| Rust (primary) | `/opt/anexomail-rust`, pm2 `anexomail-rust`, :3200, `/rpc/<proc>` |
| Polar payment (Rust) | pm2 `polar-rust-payment`, :3400 — **NO TOUCH** |
| Mail | Postfix / Dovecot / OpenDKIM |
| DB | `. /etc/anexomail/sync.env && psql "$WORKING_URL"` |
| Env | `/opt/anexomail/.env` (`SUPABASE4_URL`, `SUPABASE4_ANON_KEY`), `/etc/anexomail/sync.env` |
| Test accounts | `/root/test-accounts/<handle>.pw` (chmod 700 folder) |
| Domain DKIM cron | `server/mail/e15c/sync-domains.sh`, har minute (domain add ke baad DKIM value ~1 min mein aati hai) |

Deploy ke baad hamesha `pm2 restart <app> --update-env && pm2 save`. `polar-rust-payment` ko restart bhi nahi.

---

## 6. Delivery ka tareeqa (agent → server)

- File badalni ho: chat mein ek block. Ya to **gzip+base64 + sha256 guard**, ya `git -C /opt/anexomail-web fetch` + `git show origin/main:<path>` + sha guard. Server par poora `git pull` nahi (Rule 14): sirf specific files, anchor-gated installer, backup + `restore.sh`, build fail ho to sab wapas.
- Installer generators: `docs/cursor-work/server/i8-build-installer.py` (#8), `e30-build-installer.py` (E30). Generator **commit se pehle** chalana hai (git HEAD vs worktree diff leta hai).
- SQL seedha server se `psql "$WORKING_URL"`.
- Agent ke sandbox mein `anexomail.com` nahi khulta (proxy 403), `node_modules` / registry nahi, to asli `tsc` nahi chalta (sirf `bun build --no-bundle` syntax check); asli build server par. Built-in browser / computer tools is chat se linked nahi — agent live site khud nahi dekh sakta, founder ke screenshot par chalta hai.

---

## 7. Test accounts (E28 SQL se, Business workspace; passwords sirf server par)

| Handle | Plan | Test domain |
|---|---|---|
| `basic.buyer@anexomail.com` | basic | `basicbuyer.axonetis.com` |
| `pro.buyer@anexomail.com` | pro | `probuyer.axonetis.com` |
| `business.buyer@anexomail.com` | business | `businessbuyer.axonetis.com` |
| `bpro.buyer@anexomail.com` | business_pro | `bprobuyer.axonetis.com` |

Ek block jo sab chaar ko seed/dekh leta hai (pm2 restart, public pages, har plan ki rail/dashboard/send-from/domains/addresses/gate, #10 survey): `docs/cursor-work/server/t16-accounts-look.sh`.

Plan table (live verify, Pro ki 16 Oct output): domain cap Basic 1 / Pro 3 / Business+ unlimited; mailbox cap Basic 3 / Pro 5 / Business 30 / Business Pro unlimited; Pro storage 10 GB × 5 mailbox = 50 GB; `work.tasks.list` Pro par 200, Basic par 403.

---

## 8. Status snapshot (Rule 5) — 17 Oct 2026

**DONE (live):** #1, #2, #3, #4, #5, #6, #7a (domains A/B/C), #9, #18a, #18b; U1 (backend), U2, **U3** (Pro rail text browser mein dekha).
**READY (repo/server mein, browser ya live verify baqi):** **#7** (Compose From + Inbox label), **#8** (Domains page), #10 (live-only Brain files), #15, #16, #17a, U4, U6 (Mail rail browser mein nahi dekha), E21, E22, E23, E24.
**TODO:** #11, #12, #13, #14, #17, #17b, #18, #18c, #19, #19a, #20 (real card), #20b, #20c, #21–#30a, #31–#41, U5, U7.

Detail aur har item ka text: blueprint ki list. Yeh snapshot sirf navigation ke liye hai — farq ho to **blueprint jeetta hai**.

---

## 9. Khule findings / founder ke faislay

- **axonetis.com sirf TEST domain hai** (founder, 17 Oct 03:19 PKT): founder ka doosra project; `probuyer.axonetis.com` jaise test domains. ANEXOMAIL domain bechta nahi — product ka maqsad: user apne domain par business email banaye. Agent kabhi "domain khareedo" jaisa flow ya copy na banaye.
- **Sandbox UI harness** (`docs/cursor-work/frontend/ui-harness/`, 17 Oct): asli `src/styles.css` + asli page code se screenshot. Yeh sabut **READY** deta hai, DONE nahi (stubs nakli, founder ka browser alag). Sandbox mein asli `tsc` nahi (npm registry band, `@types/react` nahi), sirf esbuild syntax + render.
- **Primary button ka rang:** founder ke photo mein Connect button cyan/dhundla text, repo CSS aur harness mein navy (`--primary`) + saaf near-white text. Photo ya live server ki CSS ka farq — asli screenshot (Win+Shift+S) se tay hoga.
- **Registrar auto-pehchan** browser se `cloudflare-dns.com` ko DoH call karti hai; Caddy par koi `connect-src` CSP lagi ho to lookup chup-chaap fail hoga (manual tabs rahenge). Repo mein CSP nahi, server ka Caddy dekha nahi.
- **Server tree ka asli sach (17 Oct 04:06):** 20  files repo ke barabar hain; farq sirf stale git HEAD ka hai. Ek non-destructive ilaaj (sirf founder ke "haan" par):  (HEAD aage, files jaisi hain waisi; purana HEAD reflog mein) — phir On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   docs/anexomail-blueprint.md
	modified:   docs/cursor-work/frontend/ui-harness/build.mjs
	modified:   docs/cursor-work/frontend/ui-harness/stubs/router.ts
	modified:   docs/cursor-work/server/DEPLOY-MANIFEST.txt
	modified:   src/routes/app.domains.tsx

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	docs/cursor-work/founder/competitive-baseline-zoho-google-2026-10-17.md

no changes added to commit (use "git add" and/or "git commit -a") mein sirf , ,  (secret, kabhi commit nahi) bachte hain aur Rule 1 ka seedha  dobara chal sakta hai. Abhi pull.sh isse bina bhi sahi chal raha hai.
- **Server ki git tree dirty hai** (17 Oct): Rule 1 ka `git pull --rebase` "unstaged changes" par ruk jata hai, kyunke installers ne files badli hain. Poora pull tab chalega jab `cd /opt/anexomail-web && git status --short` ka output dekh kar tay ho jaye ke kaun si files repo jaisi hain (commit karni hain) aur kaun si live-only (repo mein pehle aani hain). Tab tak single-file sha-guarded block.
- Basic/Pro par **storage ledger nahi banti** (`chat_ensure_workspace` `chat_not_entitled` deta hai, mail-worker `workspaceId` null par reserve/commit chhor deta hai) — yani Basic/Pro par quota enforce/record nahi hota. Founder decide.
- **U5** CRM Loop Pro par (numbers 1, 2, 5, 9 dikhte hain; 3/4/6/8 gayab) aur **U7** "Assigned to me" folder khali — dono founder decide.
- Dashboard par **"Send success 50%"** dikha (pro.buyer: 1 mail bheji, 1 receive). `mail_scheduled` ke sent/failed se aata hai; kya waqai ek failed hai — check baqi.
- Brain (`/opt/anexomail/src`) ke **live-only libs repo mein nahi** (#10) — jo import hote hain woh pehle repo mein aane hain (`lib/leo-brain.ts` wagairah; AI ko chhedna nahi). Live `anexochat.ts` repo se purani hai. Sab "repo update" par.
- Survey ke hisaab se missing: Delete for everyone, Voice notes, Permanent business search, one-click access revocation (abhi sirf device revoke), Support SLA code.
- **Service worker cache:** deploy ke baad users ko purani UI dikh sakti hai jab tak hard refresh na ho (`src/lib/pwa.ts`, `/sw.js`, `?sw=off` kill switch; VitePWA `registerType: "autoUpdate"`, `vite.config.ts` no-touch). Fix ka idea (abhi kiya nahi): `pwa.ts` mein update par `controllerchange` par reload. Founder decide.
- Ali ka personal account payment ke baad provisioning abhi test nahi hui. Test passwords rotate karne hain (F, founder).
- Bina payment ke Polar 100%-off discount se checkout test ka idea blueprint (E22) mein hai; real card test founder ka faisla.

---

## 10. Founder ka server par purana chat record

Founder ke mutabiq purani chats server par pehle se mehfooz hain, lekin **path unhe yaad nahi (17 Oct)**. Dhoondhne ke liye server par yeh chalao aur output yahan se parh kar path **is section mein likh do**:

```bash
find /root /home /srv /mnt /opt -maxdepth 4 \( -path '*/node_modules' -o -path '*/.git' -o -path /opt/anexomail-web -o -path /opt/anexomail -o -path /opt/anexomail-rust -o -path '*/.cache' -o -path '*/.npm' -o -path '*/.bun' \) -prune -o -type f \( -iname '*chat*' -o -iname '*session*' -o -iname '*transcript*' -o -iname '*context*' -o -iname '*handoff*' -o -iname '*record*' \) \( -iname '*.md' -o -iname '*.txt' -o -iname '*.jsonl' -o -iname '*.json' -o -iname '*.log' \) -printf '%TY-%Tm-%Td %TH:%TM  %s  %p\n' 2>/dev/null | sort -r | head -40; ls -lat /root | head -30
```

Path mila: `TODO — founder ka output chahiye` (abhi nahi mila).

Qaida: kachchi chat dump (transcript) repo mein **commit nahi** hoti (usmein secret ho sakte hain). Repo mein sirf yeh khulasa jata hai.

---

## 11. Rule 18 — is file ko kaise update karna hai

Har natije ke baad (server ka green/red output, founder ka screenshot ya faisla, naya finding, commit), usi turn mein:

1. **Section 1 (ABHI KA QADAM)** dobara likho — agla ek qadam kya hai.
2. **Section 8 (status)** badlo agar status badla (Rule 5: DONE sirf live verify par).
3. **Section 9** mein naya finding / faisla.
4. **Section 12 (log)** aur, agar naya server block diya gaya, **section 13 (aakhri commands)** mein ek line: tareekh, PKT waqt, kya hua.
5. Sirf docs ka commit (`handoff: …`), `main` par push. Force-push nahi.

Founder ne 17 Oct 2026 ko kaha: "her jo kaam hum kar rahe hain ya kiya hai woh repo mein update ho taake compact chat wala Claude context dekh sake." Is liye yeh standing order hai aur Rule 14 ke "push sirf 'repo update' par" wale jumle ko docs/records ke liye override karta hai. Server par asli badlav phir bhi Rule 15 ke tareeqe se (chat block) hota hai, repo us ki copy hai.

Chat compact hone se pehle (context bhar raha ho to) ek baar poori file taza karo.

---

## 12. Session log (naya upar)

- **17 Oct 04:35 PKT** — Founder ne 13.0 (824ab3a) ka asli output + 7 photo (step 2/3 asli backend par theek, Namecheap pehchana gaya, DKIM key aayi) bheje aur hukm diya: Google/Zoho se behtar, pehle Zoho ka basic. Agent ne Zoho/Google ke official pages parhe (WebFetch),  likha, blueprint 8d–8m, aur 8g (IT wale ko instructions) + 8h (intezar mein inbox) banaye; sandbox mein dekhe. Server ki dirty tree = repo ke barabar (HEAD stale) — section 9.

- **17 Oct 04:20 PKT** — #8c (existing-mail guard) code + harness (Google Workspace scenario, desktop + 390 px) theek; pull.sh mein server-vs-repo diff stat; manifest sha badla. Founder ko 13.0 dobara.

- **17 Oct 04:05 PKT** — Founder ne 13.0 ka asli output paste kiya: green (b58694f, build OK, health 200, memory stamp barabar) + server ki dirty-tree list (section 1). Phir maqsad likha: real user ko best experience, test account ki had, "user ki tarah socho". Agent ne real-user lens se Domains par sab se bara khatra pakda: user ke domain par pehle se MX/SPF (Google/Microsoft) ho to hamara MX/SPF lagane se purani mail band ya SPF do ho jata hai — blueprint #8c (existing-mail guard) likha aur banaya.

- **17 Oct 03:55 PKT** — Founder ne wohi page-text dobara aur ek photo bheji (asli browser, step 2 theek). Do chats ek hi kaam par chal rahe the; 6ca2218 (subdomain fix) pehle push ho chuka tha. Agent ne harness mein subdomain scenario dekha (hint parent se, note, lamba Name) — theek. Section 1 ka "Agla" purana tha, naya likha. Founder ko 13.0 dobara aur step 3 ka check (DNS badle bina) diya.

- **17 Oct 03:48 PKT** — Founder ne Domains wizard qadam 2 ka page text paste kiya (asli browser): v2 live, qadam 1→2 sahi. Agent ne do kamiyan theek kin (subdomain par registrar-detect parent zone se; lamba Name "If DNS zone is axonetis.com"), harness mein dekha, manifest sha badla (blueprint 8c). 13.0 dobara chalana hai.

- **17 Oct 03:47 PKT** — Compact ke baad naya chat; founder (03:39): "context kabhi lose na ho, server par bhi update karo, hamesha pull command do, pm2 restart hamesha". Agent ne `docs/cursor-work/server/pull.sh` + `DEPLOY-MANIFEST.txt` likhe (dirty tree ke saath bhi chalta hai; memory/docs taza, code sha-guard, hamesha pm2 restart+save; nakli server par test: pehli bar, dobara, build-fail restore). Section 13.0 (EK command), section 15 (memory qaida: pehle likho phir kaam), AGENTS.md Rule 1 + Rule 18, cursor rule update. Asli server par abhi chala nahi.

- **17 Oct 03:35 PKT** — Founder ne 03:19 par kaha: Domains ki kamzoriyan theek karo, Vercel se aage UI banao tab hi dikhao, "cinematic" samjhao, axonetis sirf test domain hai, sab ek hi baar theek karo. Agent ne `app.domains.tsx` dobara likha (hero mail preview, outline "different domain", login address pehle, skeleton, stagger, registrar DoH detect, step 3 jashn), sandbox harness mein har state aur 390 px dekha, `cinematic-ui-standard.md` aur `ui-harness/README.md` likhe, blueprint #8a/#8b badla (READY). Deploy block 13.6. Browser dekhna baqi.

- **17 Oct 03:09 PKT** — Founder ke 2 photo: Domains page ka khali state theek (scroll, hero, locked addresses). Founder ne poochha "kya yeh duniya ka best UI hai?" — jawab: nahi, ~7/10; #8a (polish) aur #8b (registrar detect / ek-click DNS, founder decide) blueprint mein TODO. Wizard abhi dekha nahi.

- **17 Oct 03:03 PKT** — 13.1 (Domains page, sha `12fdbcdcb0d437e9`) founder ke server par green: build ok, pm2 restart + save, `/health` 200, `/app/domains` 200. Browser ka dekhna baqi; #8 READY.

- **17 Oct 03:03 PKT** — Founder ne Rule 1 ki pull command chalayi: git ne `cannot pull with rebase: You have unstaged changes` kehkar roka (kuch nahi badla). Founder ko 13.1 ka sha-guarded block dobara diya gaya. Khula kaam: server tree ki `git status --short` dekhna (live-only files, #10).

- **17 Oct 02:53 PKT** — Founder ne pull ki command maangi, kaha "pm2 restart hamesha karwaya karo", aur poochha "kya sab kaam latest technology par ho raha hai". Pull command section 13.4 mein; pm2 restart ka qaida section 4 mein. Jawab (chat mein): locked stack (React 19.2, TanStack Start, Vite 8.2, Tailwind 4.2, Bun, Rust primary) par; teen kamiyan: sandbox mein asli tsc/build nahi, live ticks polling se (WebTransport push E26 TODO), PWA cache purani UI dikhata hai.

- **17 Oct 02:49–03:35 PKT** — Founder ne claude.ai chat ka context paste kiya (Appendix A). File ka naam `SESSION-HANDOFF.md` se badal kar `CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md` kiya (git mv, ek hi file), upar founder ka rule likha ("pehle yeh padho, phir chat"), section 13 (aakhri commands) aur 14 (do chats ka rishta) jode. AGENTS.md top line + Rule 18, `.cursor/rules/founder-chat-context.mdc`, `docs/cursor-work/README.md` naye naam par.

- **17 Oct 02:37–03:10 PKT** — Founder ne Domains page ka screenshot bheja aur kaha "CEO ki nazar se dekho". Scroll bug + dashboard/Domains domain tazaad + sada empty state mila; `app.domains.tsx` dobara likha (section 1). Founder ko deploy block diya jata hai; browser dekhna baqi, isliye #8 abhi bhi READY.

- **17 Oct 02:29–02:50 PKT** — Founder ne compact-chat masla uthaya (context kho jata hai). Yeh `CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md`, AGENTS.md Rule 18, `.cursor/rules/session-handoff.mdc` aur `t16-accounts-look.sh` repo mein aaye. Blueprint U3 ko DONE kiya (founder screenshot). Founder ka server par chat-record path abhi nahi mila (section 10).
- **16 Oct 21:37 PKT** — Founder ka screenshot: pro.buyer ka rail aur naya Pro text theek; Domains rail mein hai. Agent ne pehla qadam diya: Domains kholo, screenshot bhejo. Founder ne D aur E ka proof maanga aur advanced UI/UX ki maang ki.
- **16 Oct ~20:00–21:30 PKT** — `#8` Domains installer server par chala (9 files, web build ok, `/health` 200, `/app/domains` 200); Rust domain flow green pro.buyer par (add → 5 records → verify → remove). Founder ne `anexomail-rust`, `anexomail-leo`, `anexomail-web` restart karaye (sab online). Test accounts basic/business/bpro bane (E28). #10 survey chali (live-only Brain libs ka natija section 9). Founder ne "repo ko chodo, accounts ek ek karke dekho" kaha.
- **16 Oct** — E30 live (Rust `dashboard.summary|analytics` aur Bun fallback dono sahi); U1/U2 DONE.
- **15 Oct** — E30 code (dashboard ki sachchai), pro.buyer ka UX review (U1–U7), `pro.buyer` account bana.
- **14 Oct** — AGENTS Rule 15 (server ka sach server par), Rule 16 (mail identities), Rule 17 (test ka tareeqa); E15–E28 ka bohot sa kaam (blueprint ke E-rows).
- Isse pehle ka sab: `docs/anexomail-blueprint.md` ("SESSION 18–21 SEP 2026" aur uske baad ke GREEN sections).

---

## 13. Aakhri commands (copy-paste ready, founder ke server ke liye)

**13.0 — EK pull command (har jawab mein yahi do; founder ka hukm 17 Oct 03:39 PKT).** `git pull --rebase` server par refuse hota hai (tree dirty), isliye yeh script tree ko chhere bina: dirty files ki list dikhati hai, memory/docs taza karti hai, manifest ki code files sha-guard se lagati hai (build fail ho to purani wapas), phir **hamesha** `pm2 restart anexomail-web --update-env && pm2 save` aur health check. Script: `docs/cursor-work/server/pull.sh`, code list: `docs/cursor-work/server/DEPLOY-MANIFEST.txt`. Sirf web; Rust/Brain ke deploy alag block.

```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh)
```
Aakhir mein `OK - memory taza, server taza` aaye aur `memory stamp:` wali line ka waqt is file ke "Aakhri update" se mile to server ki memory taza hai. Status: sandbox mein nakli server par test hua (dirty tree, dobara chalana, build fail par restore); **asli server par abhi chala nahi** (17 Oct 03:47 PKT).

Har naya block jo founder ko diya jaye woh yahan bhi likho (Rule 18). Neeche wale sab server par chalte hain, repo ya sandbox mein nahi.

**13.1 — Domains page deploy (commit `e4bf8a6`, 17 Oct 2026).** Sirf ek file (`src/routes/app.domains.tsx`), sha-guarded, backup `/root/i9/`, build fail ho to purani file wapas. Sha sirf is commit ki file ke liye hai; file badle to naya block do.

```bash
(
set -e -o pipefail
W=/opt/anexomail-web; F=src/routes/app.domains.tsx
mkdir -p /root/i9 && cd /root/i9
git -C $W fetch -q origin main
git -C $W show origin/main:$F > app.domains.new
[ "$(sha256sum app.domains.new | cut -c1-16)" = 12fdbcdcb0d437e9 ] || { echo "CHECKSUM MISMATCH - kuch nahi badla"; exit 9; }
cp $W/$F app.domains.bak
cp app.domains.new $W/$F
cd $W
if bun run build:bun > /root/i9/build.log 2>&1; then
  pm2 restart anexomail-web --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 4
  curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health
  curl -s -o /dev/null -w "web /app/domains %{http_code}\n" --max-time 5 http://127.0.0.1:3000/app/domains
  echo "OK - ab browser mein Ctrl+Shift+R"
else
  tail -15 /root/i9/build.log
  cp /root/i9/app.domains.bak $W/$F
  bun run build:bun >/dev/null 2>&1
  echo "BUILD FAIL - purani file wapas rakh di"; exit 1
fi
)
```
Status (17 Oct 03:03 PKT, founder ka output): **chala, green** — `web /health 200`, `web /app/domains 200`, "OK". Build ke baad `pm2 restart anexomail-web --update-env` + `pm2 save` ho chuka. Backup `/root/i9/app.domains.bak`. Browser par dekhna baqi (isliye #8 READY).

**13.2 — Purani chat ka server par path dhoondna:** section 10 ka `find` command. Status: output abhi nahi aaya; path milte hi section 10 mein likho.

**13.3 — Chaar test accounts ek saath dekhna** (pm2 restart rust/leo/web, public pages, har plan ka rail/dashboard/send-from/domains/addresses/gate, #10 survey; password sirf server par):
```bash
git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/t16-accounts-look.sh | bash
```

**13.4 — Pull (AGENTS.md Rule 1, `--rebase` wala; founder ne 17 Oct 02:53 PKT ko maanga).** Server ki tree installers se badli hui ho sakti hai; us surat mein git `cannot pull with rebase: You have unstaged changes` kehkar **bina kuch badle** ruk jata hai (`&&` ki wajah se build/restart tak nahi pohanchta) — tab 13.1 jaisa sha-guarded single-file block chalao.
```bash
cd /opt/anexomail-web && git restore src/routeTree.gen.ts && git pull --rebase origin main && bun install && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save && curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health
```
Status (17 Oct 03:03 PKT, founder ka output): **refused** — `error: cannot pull with rebase: You have unstaged changes.` Kuch nahi badla (`&&` ne build/restart se pehle rok diya). Matlab server ki `/opt/anexomail-web` tree installers se dirty hai; poora pull tab tak nahi chalega jab tak `git status --short` ka output dekh kar tay na ho ke kaun si files live-only hain (#10 ka hissa). Tab tak sirf 13.1 jaisa sha-guarded single-file block.

**13.6 — (purana, ab zaroorat nahi: 13.0 isay shamil karta hai) Domains page v2 deploy (cinematic, 17 Oct 2026, sha `b49297b2f57ff586`).** Sirf `src/routes/app.domains.tsx`; sha-guarded; backup `/root/i9/`; build fail ho to purani file wapas; pm2 restart + save. (Commit push hone ke baad chalao: `git fetch` usi se file uthata hai.)

```bash
(
set -e -o pipefail
W=/opt/anexomail-web; F=src/routes/app.domains.tsx
mkdir -p /root/i9 && cd /root/i9
git -C $W fetch -q origin main
git -C $W show origin/main:$F > app.domains.v2.new
[ "$(sha256sum app.domains.v2.new | cut -c1-16)" = b49297b2f57ff586 ] || { echo "CHECKSUM MISMATCH - kuch nahi badla"; exit 9; }
cp $W/$F app.domains.v2.bak
cp app.domains.v2.new $W/$F
cd $W
if bun run build:bun > /root/i9/build.log 2>&1; then
  pm2 restart anexomail-web --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 4
  curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health
  curl -s -o /dev/null -w "web /app/domains %{http_code}\n" --max-time 5 http://127.0.0.1:3000/app/domains
  echo "OK - ab browser mein Ctrl+Shift+R"
else
  tail -15 /root/i9/build.log
  cp /root/i9/app.domains.v2.bak $W/$F
  bun run build:bun >/dev/null 2>&1
  pm2 restart anexomail-web --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1
  echo "BUILD FAIL - purani file wapas rakh di"; exit 1
fi
)
```
Status: **founder ne abhi chalaya nahi** (17 Oct 03:47 PKT); 13.0 chalane par yeh file bhi lag jati hai (manifest). Natija aane par yahan likho.

**13.5 — DB ka chhota check (claude.ai chat se, 15–16 Oct; E30 ke baad theek nikla):**
```bash
. /etc/anexomail/sync.env && psql "$WORKING_URL" -c "select direction,count(*) from mail_messages group by 1"
```

---

## 15. Memory kabhi lose na ho — qaida (founder, 17 Oct 03:39 PKT)

Sach: Claude ki apni yaadasht ek chat se doosre chat mein nahi jati. **Yeh file hi memory hai.** Isliye:
1. **Pehle likho, phir kaam karo.** Founder naya hukm, faisla ya khabar de to agent kaam shuru karne SE PEHLE section 1/2 mein likh kar docs-only commit push kare (compact kisi bhi lamhe aa sakta hai).
2. **Har natije ke baad** section 1, 8, 9, 12, 13 (Rule 18). Lamba kaam chal raha ho to beech beech mein checkpoint.
3. **Compact / naya chat:** pehla kaam yeh poori file padhna, phir founder ko ek line: "abhi yahan hain: …" aur section 1 se seedha chalna.
4. **Server ki copy:** 13.0 har baar `/opt/anexomail-web/docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md` taza karta hai. Founder `memory stamp` se dekh sakta hai ke server wali copy repo ke barabar hai.
5. **Agent bhool jaye to?** Founder ek sawal poochh sakta hai: "section 1 ka stamp kab ka hai?" — purana ho to wohi nishani hai ke update chhoota. Phir agent pehle file update kare.

---

## 14. Do chats ka rishta (context kahan se aata hai)

Founder do jagah Claude se kaam karta hai; dono ka context isi file mein jama hota hai:

1. **claude.ai ka Claude chat** — salah, CEO/user ki nazar se review, tarteeb ka mashwara. Wahan 15 Oct ko pro.buyer ke asli login ka review hua (U1–U7, blueprint "15 Oct 2026" section) aur mashwara diya gaya: pehle **#7 ka "Send from" check**, phir **#8 (domains)**, aur **U1 jald** (jhoote dashboard numbers har plan par). U1/U2 ab live DONE hain (16 Oct).
2. **Claude Code ka cloud session** (yeh repo, commits, server ke liye chat blocks). Yeh sandbox se `anexomail.com` ya founder ka server nahi dekh sakta; sab live sabut founder ke paste kiye output / screenshot se aata hai.

Jab founder purani chat ka text paste kare (jaise 17 Oct ko) to us ka kaam ka hissa yahan section 1/8/9/12 mein aata hai, aur khaas matn Appendix mein (sirf tab jab usmein secret na ho — paste karne se pehle parho).

---

## Appendix A — claude.ai chat ka paste kiya hua matn (founder ne 17 Oct 2026 ko paste kiya; secret nahi, parh liya gaya)

Yeh us chat ka pehla (CEO-review wala) hissa hai. Paste ka baqi hissa isi cloud session ke jawab the aur section 1–12 mein darj hain.

```text
“Command center” founder-side ka nahi hai. Yeh user Dashboard (/app) ka chhota heading hai, src/components/app/dashboard/Greeting.tsx mein. Founder wali cheezein (/app/founder, Admin, Speed) sirf founder host par dikhti hain, Pro ke rail mein nahi.

Ek user aur CEO ki nazar se: pehla taassur achha hai. Dark glass look saaf hai, rail mein sirf wohi cheezein hain jo is plan ko milti hain, aur mail bhejne ke kuch minute baad Mail mein dikhne lagi. Lekin pehli screen par kuch cheezein sach nahi hain. Paying buyer paanch minute mein bharosa kho sakta hai.

Yeh sab repo ke code aur schema se mile hain, abhi live server par check nahi hue:

Dashboard ke numbers galat hain. Ek mail gayi aur ek aayi, magar dashboard Received 0 / Sent 2 / Delivered 100% dikha raha hai. Code "inbound" dhoondta hai, jabke database mein in/out hota hai. Isliye har aane wali mail Sent mein ginti hai. Delivered hard-coded 100% hai, bounce hui mail bhi 100% ginti hai. Yeh fake success state hai.
Storage 30 GB dikha raha hai. Pro plan 10GB per mailbox, 5 mailbox deta hai. Dashboard plan nahi dekhta, ek flat default uthata hai.
Plan ki copy jhooti hai. Pro ke neeche likha hai “…and ANEXOChat”. Plan table mein ANEXOChat Business se shuru hota hai, aur Pro ke rail mein dikhta bhi nahi.
Business buyer ka pehla din. Pro 3 company address aur 5 mailbox ka wada karta hai, lekin rail mein domain ya address jodne ki koi screen nahi dikhti. Org sirf Business+ ko milta hai, aur Admin platform ka hai. Dashboard par setup checklist bhi nahi. Yeh #8 (domain wizard) hai. Pro ko bhi dikhna chahiye aur dashboard se link hona chahiye. Ek baat aur: dashboard “ANEXOMAIL hosted” dikha raha hai jabke is org ka domain probuyer.axonetis.com hai. Code ke hisaab se “Domain not verified” aana chahiye tha.
CRM Loop Pro par: 4 step dikhte hain, numbers 1, 2, 5, 9. Gaps toote hue lagte hain. Aap tay kero ke Pro ko kaun se steps milenge.
Chhoti cheezein: rail mein login address beech se toot jata hai (anexomail.c / om), aur ek hi address par “All addresses” aur “Unified inbox” dohrate hain.

Kuch theek nahi kiya. Rule 14 ke mutabiq sab pehle list mein likhe hain (U1 se U6, d321f46). Tarteeb aap tay karenge. Mera mashwara: #7 ka “Send from” check, phir #8, aur U1 jald (jhoote numbers sab plans par hain).

Do baatein live confirm karne ke liye, ek chhota command:

. /etc/anexomail/sync.env && psql "$WORKING_URL" -c "select direction,count(*) from mail_messages group by 1" -c "select slug,domain,domain_verified,storage_limit_bytes from organisations where slug like 'pro-buyer-test%'"

Output paste kero.
```

Is review ke har nukte ka anjaam: U1/U2 DONE (16 Oct live), U3 DONE (16 Oct browser), U4/U6 READY, U5/U7 founder ka faisla (section 9), #8 ab browser dekhne ke qareeb (section 1).

