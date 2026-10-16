# SESSION HANDOFF — naya ya compact chat: PEHLE YEH POORI PADHO

Yeh file isliye hai ke chat compact ho ya naya chat khule, agla Claude **wahin se** kaam shuru kare jahan pichla chhoda tha. Founder ko kuch dobara samjhana nahi parna chahiye. Isko update karna AGENTS.md **Rule 18** hai.

Aakhri update: **17 Oct 2026, 02:50 PKT**.

---

## 0. Naya chat shuru karte hi (tarteeb)

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

**Agla (abhi pending):** founder ne left rail mein **Domains** kholna hai aur page ka screenshot bhejna hai. Dikhna chahiye: "Domains & addresses"; "1 of 3 domains · Pro"; `probuyer.axonetis.com` ki row ("Needs DNS · x/5", **Continue setup** button); neeche Addresses mein `pro.buyer@anexomail.com` "Your login" ke saath. Founder ne abhi screenshot nahi bheja.

Uske baad wizard ka proof (D) ek ek qadam: Connect a domain → naam → 5 DNS records + Namecheap/GoDaddy/Cloudflare tabs + Copy buttons → live ticks. Phir E ka proof (Compose "Send from", Inbox address label, aane wali mail par bhi).

---

## 2. Founder ki maangen jo abhi khuli hain

- **D proof** — domain wizard founder ke browser mein dikhe aur kaam kare (backend server par green hai, browser ka dekhna baqi). `#8` isliye READY hai, DONE nahi.
- **E proof** — `#7`: Compose "From" mein company address, Inbox mein address ka label, aane wali mail dono par. Backend 15 Oct ko proven; browser ka proof baqi. `#7` READY.
- **Frontend UI/UX duniya ke level ka** (founder ne kaha: "duniya ka advance Frontend UI UX"). Domains page abhi sirf **functional** hai (`src/routes/app.domains.tsx`, `ax-plane` cards). "Cinematic" wizard ka dobara design baqi — `frontend-design` skill use karo, `src/lib/domains.ts` ke hooks na badlo, `vite.config.ts` / `package.json` / `bunfig.toml` na chhuo. Founder jo screen kamzor bataye wahi pehle.
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
4. **Section 12 (log)** mein ek line: tareekh, PKT waqt, kya hua.
5. Sirf docs ka commit (`handoff: …`), `main` par push. Force-push nahi.

Founder ne 17 Oct 2026 ko kaha: "her jo kaam hum kar rahe hain ya kiya hai woh repo mein update ho taake compact chat wala Claude context dekh sake." Is liye yeh standing order hai aur Rule 14 ke "push sirf 'repo update' par" wale jumle ko docs/records ke liye override karta hai. Server par asli badlav phir bhi Rule 15 ke tareeqe se (chat block) hota hai, repo us ki copy hai.

Chat compact hone se pehle (context bhar raha ho to) ek baar poori file taza karo.

---

## 12. Session log (naya upar)

- **17 Oct 02:29–02:50 PKT** — Founder ne compact-chat masla uthaya (context kho jata hai). Yeh `SESSION-HANDOFF.md`, AGENTS.md Rule 18, `.cursor/rules/session-handoff.mdc` aur `t16-accounts-look.sh` repo mein aaye. Blueprint U3 ko DONE kiya (founder screenshot). Founder ka server par chat-record path abhi nahi mila (section 10).
- **16 Oct 21:37 PKT** — Founder ka screenshot: pro.buyer ka rail aur naya Pro text theek; Domains rail mein hai. Agent ne pehla qadam diya: Domains kholo, screenshot bhejo. Founder ne D aur E ka proof maanga aur advanced UI/UX ki maang ki.
- **16 Oct ~20:00–21:30 PKT** — `#8` Domains installer server par chala (9 files, web build ok, `/health` 200, `/app/domains` 200); Rust domain flow green pro.buyer par (add → 5 records → verify → remove). Founder ne `anexomail-rust`, `anexomail-leo`, `anexomail-web` restart karaye (sab online). Test accounts basic/business/bpro bane (E28). #10 survey chali (live-only Brain libs ka natija section 9). Founder ne "repo ko chodo, accounts ek ek karke dekho" kaha.
- **16 Oct** — E30 live (Rust `dashboard.summary|analytics` aur Bun fallback dono sahi); U1/U2 DONE.
- **15 Oct** — E30 code (dashboard ki sachchai), pro.buyer ka UX review (U1–U7), `pro.buyer` account bana.
- **14 Oct** — AGENTS Rule 15 (server ka sach server par), Rule 16 (mail identities), Rule 17 (test ka tareeqa); E15–E28 ka bohot sa kaam (blueprint ke E-rows).
- Isse pehle ka sab: `docs/anexomail-blueprint.md` ("SESSION 18–21 SEP 2026" aur uske baad ke GREEN sections).
