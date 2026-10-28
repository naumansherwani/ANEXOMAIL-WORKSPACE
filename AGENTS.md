# ANEXOMAIL Workspace — Agent Rules

> **AGLA KAAM: `docs/cursor-work/NEXT-TASKS.md` (tarteeb, founder-locked 22 Oct 2026).**
>
> **RULE 48 (STRICT, founder 23 Oct 2026 03:01 PKT): founder ko sirf repo ki likhi aazmayi hui commands do; apni taraf se command (khaas kar `git merge`/`pull` `/opt/anexomail-web` mein) KABHI nahi gharni. Neeche Rule 48 dekho.**
>
> **RULE 44 (STRICT, founder 22 Oct 2026 20:32 PKT): SQL AB SERVER PAR CHALTI HAI, Supabase editor par nahi. Jo SQL pehle editor mein paste hoti thi ab server par `sql-run.sh` se chalti hai, aur YEH COMMAND PEHLE CHALEGI (Rust/Web se pehle). Har nayi SQL ke baad founder ko sirf yeh do mein se sahi command do: (a) sab nayi: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)` (b) khaas file, naam aakhir mein bina `.sql`: `… sql-run.sh) E65_rls_and_advisor_sweep CHECK_E65`. "Supabase editor mein paste karo" kabhi nahi kehna. Compact ke baad bhi yehi.**
>
> **RULE 24 (strict): compact/naye chat par KAAM SHURU karne se pehle `docs/cursor-work/founder/founder-commands.md` padho — founder ki chat commands wahan verbatim + halat. Uske baghair kaam nahi.**
>
> **RULE 28 (STRICT, founder 20 Oct 2026, 10:32 PKT): koi bhi file badalne YA revert karne ke baad, push se PEHLE: (1) `python3 docs/cursor-work/server/manifest-sync.py <har badli/revert hui file>` (2) `python3 docs/cursor-work/server/manifest-verify.py` — exit 0 aur "0 bad" chahiye. Exit 1 ho to push MAT karo. Warna server par `SHA MISMATCH` se file chhoot jati hai, aadha deploy hota hai, build FAIL, aur purani files wapas — founder ko kuch badla nazar nahi aata (20 Oct ka `useDragScroll` hadsa). Revert ka matlab bhi "file badli" hai.**
>
> **RULE 27: compact ke baad `docs/cursor-work/BASIC-AUDIT-DONE.md` bhi padho — 20 Oct 2026 ke live audit mein kya fix ho chuka (batch 1-6), kya baqi; wahi cheez dobara mat banao. Har naya batch us file ki table mein ek row + founder-commands.md mein entry.**
>
> **FOUNDER KA RULE: jo bhi founder se chat karega, pehle `docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md` poori padhega, phir chat karega (Rule 18).** Naya ya compact chat bhi wahin se shuru hota hai — "ABHI KA QADAM" dekho, founder se purani baat dobara mat poochho.

> **RULE 49 (founder 23 Oct 2026, 03:38 PKT): test accounts aur ASLI users kabhi mix na hon.** Asli user/buyer jab workspace banaye to usay sab kuch naya, asli wiring, KOI mock/demo/sample data nahi (naya workspace sirf org + mailbox + member + trial row banata hai — audit 23 Oct: koi seed/demo path nahi mila). Test account ka koi special-casing NAAM-pattern par nahi: chhoot sirf `test_accounts` registry (E76) mein maujood email ko milti hai (pattern AUR registry dono; fail-closed). Naya special-casing likhne se pehle yeh rule parho; naya test account E28/E36 se banta hai aur registry mein jata hai.

**Founder:** Muhammad Nauman Sherwani (NEXATECT Global Ltd, internal only — public copy mein NEXATECT ka zikr nahi).

---

## TECHNOLOGY CONSTITUTION (locked — touch nahi)

| Layer | Technology |
|---|---|
| Host | Hetzner only |
| Edge | Caddy — HTTPS + HTTP/3 |
| Frontend | React 19.2 |
| Router / SSR | TanStack Start v1 (router 1.17.0) |
| Build | Vite 8.2 |
| CSS | Tailwind v4.2 (`src/styles.css`) |
| UI | Radix + shadcn/ui |
| Animation | Framer Motion, GSAP, Three.js |
| SSR runtime | Bun — Nitro bun preset |
| PM2 interpreter | bun |
| Frontend port | 3000 |
| Backend PRIMARY | Rust :3200 — Tokio async, WebTransport, QUIC, tRPC, PostgreSQL. **Har naya phase yahi (locked 12 Sep 2026).** |
| Backend FALLBACK | Bun :3100–3300 — **fallback total**. Naya Bun-primary **nahi**. |
| Emergency only | Node 22 (normal kaam mein nahi) |
| Database | Supabase / PostgreSQL (source of truth) |
| Mail | Postfix / Dovecot / OpenDKIM (Hetzner pe installed) |
| Payments | Polar — Rust webhook (PM2 mein) |

**Vistaar (Rule 20, 17 Oct 2026):** har technology kis kaam ke liye aur kis ke liye NAHI, latest versions, aur purane/naye ka farq `docs/cursor-work/TECH-MAP.md` mein. Upar ki rows locked hain; unka vistaar wahi file karti hai.

**Constitution violations banned:** WebContainer, Supabase Realtime/WebSocket (unless already exists + founder approve), mock backend, fake success states.

---

## HOST MAP (locked)

| Domain | Surface | Users |
|---|---|---|
| `anexomail.com` | Public mail workspace | Awam (registered users) |
| `ai.anexomail.com` | AI workspace (LEO) | Awam — Coming Soon publicly |
| `founderworkspace.anexomail.com` | Owner protocol | Sirf Nauman |

`src/lib/host.ts` browser mein `window.location.hostname` check karta hai — yeh browser-side code hai, alag server nahi.

---

## TARTEEB (build order — locked)

1. `anexomail.com` — awam mail product (real login, real send/receive)
2. Founder workspace — `founderworkspace.anexomail.com`
3. AI — `ai.anexomail.com` (Coming Soon for awam)
4. ANEXOChat Phase 1–31A — live wire
5. ANEXOChat Phase 32+ — sirf founder ke paste karne pe
6. GitHub → Server 2 pull

---

## RULES (sab locked)

### Rule 1 — GitHub is source of truth
Sab kuch GitHub repo mein. Server sirf pull karta hai. **Founder pull command locked** — ALWAYS `--rebase`, NEVER `--no-rebase`. Ek `&&` block only:
```bash
cd /opt/anexomail-web && git restore src/routeTree.gen.ts && git pull --rebase origin main && bun install && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save && curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health
```
Agent `web /health` **200** confirm kare.

**Founder ka hukm (17 Oct 2026): har jawab jo repo badle, uske aakhir mein pull command do aur pm2 restart hamesha.** Server ki tree installers se dirty hai, to upar wali `--rebase` pull "unstaged changes" par refuse hoti hai. Isliye amali command yeh EK hai (`docs/cursor-work/server/pull.sh`: memory/docs taza, `DEPLOY-MANIFEST.txt` ki code files sha-guard + build + restore-on-fail, hamesha `pm2 restart anexomail-web --update-env && pm2 save`):
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh)
```
Code file badlo to usi commit mein manifest ka sha badlo. Rust/Brain ke deploy alag block (restart `anexomail-rust` / `anexomail-leo`); `polar-rust-payment` kabhi nahi.

### Rule 2 — No local clone on agent
Agent sirf GitHub repo read karta hai, push karta hai. Server pull karta hai. Agent ke pass kuch nahi.

### Rule 3 — No code without founder approval
Ek bhi file tab tak nahi banti jab tak founder "Phase N shuru karo" na bole.

### Rule 4 — No touch (locked items)
- Landing pages, logo, existing UI
- Polar Rust payment webhook (already fixed by founder)
- `package.json` / `vite.config.ts` / `bunfig.toml` build packages
- `.env` / secrets

### Rule 5 — Status sirf teen
- **DONE** — live test hua (green verify command)
- **READY** — repo mein, server par nahi
- **TODO** — abhi nahi bana

"Implemented" / "Locked" / "Working" kehna banned hai jab tak verify green na ho.

### Rule 6 — No mix, no duplicate
- ANEXOChat aur ANEXOMAIL mix nahi
- Lovable / ChatGPT / Grok suggestions nahi banane jab tak founder original block paste na kare
- Duplicate systems nahi

### Rule 7 — Blueprint law
- ANEXOMAIL phases → `docs/anexomail-blueprint.md` (founder paste karay)
- ANEXOChat phases → `anexochat/docs/anexochat-blueprint.md`
- Phase 32+ sirf founder paste karne pe

### Rule 8 — cursor-work folder
Ab se sab kaam `docs/cursor-work/` mein:
- Naya SQL → `docs/cursor-work/sql/`
- Frontend log → `docs/cursor-work/frontend/`
- Server commands → `docs/cursor-work/server/`
- Founder phases → `docs/cursor-work/founder/`
- AI phases → `docs/cursor-work/ai/`
- ANEXOChat 32+ → `docs/cursor-work/anexochat/`

**SQL fail rule (locked):** Fail ho to **usi file** ko shuru se theek likho. Naya naam (`phaseNNb`, `_fix`, `_v2`) **banned**. Duplicate patch file delete.

**Phase 60s no-touch (locked 11 Sep 2026):** `sql/phase60–62` aur `docs/cursor-work/sql/phase63–65` founder blueprint hain. Agent edit / rewrite / dubara-run **nahi**. Naya SQL = E-series `docs/cursor-work/sql/E<n>_….sql` (`ANEXOMAIL-EXECUTE.md`).
### Rule 9 — Wire rule
Har wiring ka record `docs/wire/` ya `docs/cursor-work/` mein. Status sirf DONE / READY / TODO.

### Rule 10 — Branding rule
Repo mein sirf founder + ANEXOMAIL/ANEXOChat/ANEXOVideoCall ka naam. Build-platform ka naam, logo ya credit kisi doc, comment, UI copy ya asset mein nahi.

### Rule 11 — Git history
Force push, rebase/amend/squash on pushed commits banned. Connected branch hamesha working state mein rahe.

### Rule 12 — Blueprint protection (locked — touch nahi)
ANEXOMAIL aur ANEXOChat blueprints HAMESHA alag rahenge. Kisi bhi agent/session ko yeh files delete, overwrite, ya merge karne ki ijazat nahi.

| File | Kya hai | Status |
|---|---|---|
| `docs/anexomail-blueprint.md` | ANEXOMAIL workspace blueprint (Phase 1–62+) | PROTECTED |
| `anexochat/docs/anexochat-blueprint-original.md` | ANEXOChat Phase 1–57 founder original | PROTECTED |
| `anexochat/docs/anexochat-blueprint-original-with-added-features.md` | ANEXOChat Phase 1–57 + Founder Suggestions + Proof Mode + WOW-FACTOR | PROTECTED |

**Delete ban.** **Mix ban.** **Rename sirf founder ke kehne pe.**
ANEXOChat Phase 32+ build sirf tab jab founder original `## PHASE N` text paste kare.

### Rule 13 — Mail send + receive gate (locked 10 Sep 2026)
Asli email **bhejni aur aani** ke baghair agla flow nahi.

- **F5 thread / F6 contacts / F7 calendar / F8 work / F9 founder polish / ANEXOChat 32+ / AI** — wait
- Awam Basic + Pro + Business — **mail included** (chat alag; Basic/Pro ko email nahi katni)
- Proof: website se send → Postfix → bahar; bahar se receive → Postfix/Dovecot pipe → inbox list
- Status **DONE** sirf `bash server/gates/mail-gate.sh` green + founder ne live send/receive dekha

### Rule 14 — Kaam ki tarteeb LOCKED (locked 11 Oct 2026)
Ek hi list: `docs/anexomail-blueprint.md` → section "11 Oct 2026 — remaining work" (27 items; dusri queue nahi). `docs/cursor-work/server/PLAN-order-2026-10-11.md` sirf us ki copy hai; farq ho to blueprint jeetta hai. Tarteeb **#1 se #27**, section A (#1–#10) pehle.

- Agent **skip nahi** karta, aage nahi jata, naya kaam shuru nahi karta jab tak founder na kahe ya pehle wala item DONE na ho.
- Naya kaam pehle list mein likho, phir tarteeb mein; chupke se beech mein nahi.
- Item **DONE** sirf live verify (green output) par; warna READY ya TODO (Rule 5).
- Server par poora `git pull` nahi: sirf specific files, sha-gated installer, backup + `restore.sh`.
- Har deploy mein build ke baad `pm2 restart anexomail-web --update-env && pm2 save` hamesha.
- Server 1 (main brain) sensitive: agent wahan kuch chalane ko nahi kehta.
- Repo `main` par push sirf founder ke "repo update" kehne par; live-only files (jo GitHub par nahi) pehle repo mein aayen, phir overwrite.

### Rule 15 — Server ka sach server par (locked 14 Oct 2026, founder)
Repo sirf update ki machine hai, sach nahi. Server par jo code/state dekhna ho (live file, diff, pm2, logs, DB) uske liye agent **seedha chat mein command deta hai**, founder server par chalata hai aur output paste karta hai. Agent repo ko live ka sabut nahi maanta, aur "repo == server" ka andaza nahi lagata.
- Command chat mein, ek block, copy-paste ready. Agent khud server par kuch nahi chalata.
- **Delivery ka asli tareeqa (founder, 14 Oct):** server hi backend + frontend hai. File badalni ho to chat mein base64 payload (`echo '<b64>' | base64 -d > <server path>`, pehle `.bak`), SQL ho to seedha server se PostgreSQL par (`. /etc/anexomail/sync.env && psql "$WORKING_URL" ...`). Fix ke liye GitHub pull ka intezar nahi. Repo sirf copy/update ki machine hai.
- Gate/"PASS PASS" scripts founder ko nahi dene; asli output wale seedhe commands (curl code, grep, psql, pm2).
- Mismatch ho to pehle live ka output manga kar dekhe, phir faisla.

### Rule 16 — Mail identities LOCKED (locked 14 Oct 2026, founder)
Spec: `docs/cursor-work/founder/mail-identities-locked-2026-10-14.md`.
- Founder account `naumansherwani.founder@anexomail.com` ka UI/UX **alag**; baqi company addresses (`hello`, `moveyourbusiness`, `resolved`, `billing`, `leo`) ka **ek unified inbox** (address badge ke saath).
- Send-from = 6 choices (5 company + founder). `hello@` auto-reply (Option C template) aur `billing@` receipt (Polar payment success) ka text spec file mein locked hai; founder ke kehne ke baghair badla nahi jata.
- Tarteeb blueprint ki numbering se, public user pehle (Rule 14). Polar :3400 engine no-touch rehta hai.
- Founder se baat hamesha "aap" ke lehje mein, "kero/chalao" — "tu/tera/kar" nahi.

### Rule 17 — Test ka tareeqa + purani records (locked 14 Oct 2026, founder)
- **Test browser se nahi.** Agent test khud banata hai: test account SQL se (`docs/cursor-work/sql/E28_seed_buyer_test_account.sql` — asli signup ke wohi steps, sirf payment ki jagah `entitlement_state` row), phir login token (GoTrue password grant, keys `/opt/anexomail/.env` se) -> Rust `:3200 /rpc/<proc>` aur Brain `:3100 /api/...` par `curl` -> `mail.log` / `psql` se asli output. Template: `docs/cursor-work/server/t7-send-identity-test.sh`. Founder ko signup/click karne ko nahi kehna; browser sirf wahan jahan screen dekhni zaroori ho (UI dikhna).
- Command chat mein, ek block, copy-paste (Rule 15). Password/secret repo mein nahi.
- **Kuch bhi TODO/READY likhne se pehle purani records padho:** `docs/anexomail-blueprint.md` ke "SESSION 18–21 SEP 2026" aur uske baad ke GREEN sections, `.cursor/rules/session-1821-lock.mdc`, aur founder ne server par jo chat record rakha hai (command se dekho). Jo wahan GREEN / "do not redo" hai woh dobara TODO nahi likhna, na dobara banana.

### Rule 18 — Claude chat context with founder Nauman Sherwani (locked 17 Oct 2026, founder)
Chat compact hone par context kho jata tha. Ab ek hi file hai: `docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md` (founder ka rule, ABHI KA QADAM, founder ki maangen, qaide, system map, test accounts, status snapshot, khule findings, session log, aakhri commands, do chats ka rishta).
- **Founder ka rule:** koi bhi founder se chat karega to **pehle yeh context file padhega, phir chat karega.** Naya chat, compact ke baad ka chat, claude.ai ka Claude ya Claude Code session — sab par laagu.
- **Har natije ke baad** (server ka output, founder ka screenshot/faisla/paste, naya finding, naya command block) usi turn mein file ke sections 1, 8, 9, 12 (log) aur 13 (aakhri commands) update karo, sirf docs ka commit (`handoff: …`) aur `main` par push. Founder ka standing order (17 Oct 2026): "her latest command aur kaam repo mein update ho taake compact chat wala Claude context dekh sake" — Rule 14 ke "push sirf 'repo update' par" ko docs/records ke liye override karta hai.
- Server par asli badlav phir bhi Rule 15 se (chat block); repo us ki copy/record hai. Status Rule 5 ke mutabiq; farq ho to blueprint jeetta hai.
- **Pehle likho, phir kaam karo:** founder naya hukm/faisla de to kaam shuru karne se pehle file mein likh kar docs-only commit push karo (compact kisi bhi waqt aa sakta hai). Server ki copy `pull.sh` se taza hoti hai; file ka section 15 dekho.
- Founder jo purani chat paste kare uska khaas hissa file ke Appendix mein (pehle secret ke liye parho). Kachchi poori transcript dump nahi.

### Rule 19 — Mobile + tablet pehle din se (locked 17 Oct 2026, founder)
Founder ka hukm: "ab se ek rule hai — mobile users aur tablet users ke liye bhi website build karo; unki tadad bahut zyada hai; woh kabhi mobile se ANEXOMAIL use kar saken."
- Har naya ya badla hua screen **desktop ke saath mobile (390 px) aur tablet (820 px) par bhi** banta aur dekha jata hai (harness screenshot teeno par: 1440 / 820 / 390). Mobile baad ki cheez nahi; ek screen tab READY nahi jab tak teeno width theek na hon.
- Minimum: koi horizontal page-scroll nahi; touch targets >= 44 px; mobile par nav (rail) chhote-screen ka apna tareeqa (drawer/bottom bar); `100dvh` (browser ki toolbar se na kate); safe-area (notch/home bar); input 16 px (iOS zoom na ho); keyboard khule to action button na chhupe; lambi cheezein (email, DNS value) wrap/scroll-in-place.
- CEO soch (founder ka hukm): har section mein gaps aur loopholes dhoondo jo user ka dil jeetein ya tod den, aur "yeh duniya mein viral kaise hoga" ki nazar se: pehle 60 second mein user ko apna address kaam karta dikhe, ek tap mein share/invite, phone se bhi poora kaam.

### Rule 20 — Latest technology, har cheez sirf apne kaam ke liye; har plan ko duniya ka best experience (locked 17 Oct 2026, founder)
Founder ka hukm (17 Oct 06:04 PKT): backend par **latest technology, koi compromise nahi**; mail bhi Rust (ya jo sab se latest ho) par jayegi; **website sirf latest technology par**; aur repo mein likha ho **kaun si technology kis kaam ke liye hai — aur sirf usi kaam ke liye.**
- **Ek hi sach: `docs/cursor-work/TECH-MAP.md`.** Har technology ki ek line: kaam, kis kaam ke liye NAHI, status (LIVE sirf live verify par / READY / PLANNED / REJECTED + wajah). Naya tech lagane se pehle map mein likho (kaam + status + kyun purane se behtar); map mein na ho to code mein na aaye. Constitution ki upar ki rows (locked) nahi badalti — unka vistaar map karta hai.
- Naya backend kaam Rust (Tokio async) par; Bun sirf emergency. Purani technology badalna (jaise mail server) sirf founder ke "haan" aur parallel staging ke baad — mail send/receive GREEN hai, use tod'na nahi.
- "Latest" ka matlab verify kiya hua: version/tareekh official source se, andaza nahi (Rule 17 jaisa: purani records pehle).
- **Agent = CEO + user ka dimaagh.** Maqsad: user ko lage product uska apna hai, competitors se behtar aur aasaan. **Basic, Pro, Business, Business Pro — har plan ka duniya ka best experience**, cinematic frontend; plan-wise soch `docs/cursor-work/founder/plan-experience-2026-10-17.md` mein. Blueprint ke gaps tarteeb se (Rule 14), Rule 19 (mobile + tablet) ke saath.

### Rule 21 — Mission: user ko anexomail.com tak laana; loophole khud band karo; har fix ke saath pull + pm2 restart; end par loophole ledger (locked 17 Oct 2026 18:24 PKT, founder)
Founder ka hukm: agent CEO hai; **khud screenshot le kar** dekhe (user ke dimaagh se) ke visitor kaise anexomail.com par aaye, ruke aur khareede/signup kare — yehi mission hai. Har chat ka context repo mein update rehta hai (Rule 18).
- **Loophole/gap khud theek karo, jab tak 100% na ho sakoon nahi.** Jo agent theek kar sakta hai (frontend, docs, scripts, Rust source) woh isi chakkar mein; jo sirf founder kar sakta hai (DNS records, production mail config ka 'haan', paise/account) woh saaf likha jaye — chhupa nahi, bhoola nahi.
- **Har theek hui cheez ke saath founder ko ek hi pull command**, jo `pm2 restart anexomail-web --update-env && pm2 save` karti hai (purana cache nikalne ke liye; `pull.sh` yeh hamesha karta hai) aur **server==repo ka saboot** chhapti hai (`src/ same/differ/missing`). Repo hamesha up-to-date, server hamesha up-to-date.
- **Har summary ke aakhir mein "Loophole ledger"**: jo band hue, jo khule hain (wajah + kis ka kaam + agla qadam), aur sach likha ho — jhoota "ek bhi nahi chhoda" kabhi nahi. Ledger ki ek jagah: `docs/cursor-work/founder/loophole-ledger.md` (har fix par update; DONE sirf live saboot par, Rule 5).

### Rule 22 — Founder workspace sirf latest Rust stack par; founder ka pasandida kaam ka style (locked 17 Oct 2026 19:34 PKT, founder)
Founder ka hukm: founder ka account/protocol awam user se **alag** hai. Founder ki poori profile/workspace **sirf latest technology** par: Rust (axum + tokio async), tRPC-style typed RPC (`/rpc/*`), WebTransport + QUIC (quinn / wtransport). **Founder workspace mein Bun nahi, Node nahi, webhook nahi** — kuch mix nahi (awam ka raasta alag rahe; Polar payment webhook alag cheez hai aur NO-TOUCH hai).
- **Aaj ki sachai pehle (Rule 5):** founder pages ki kuch calls abhi Bun REST fallback par bhi ja sakti hain, aur page ka HTML/JS Bun SSR se aata hai. Pehle har founder call ka audit (`docs/cursor-work/founder/founder-stack-audit.md`), phir ek ek call Rust par; **fallback tab hi band** jab uska Rust proc live verify ho (warna founder ka page tootega).
- Rust code sandbox mein compile nahi hota: Rust badlav `rust-safe-deploy.sh` se, founder ke server par compile + rollback ke saath.
- **Founder ko jo kaam ka style pasand hai (usne kaha "love you ho gaya", 17 Oct 19:34 PKT) — yehi chalta rahe:** (1) har theek hui cheez ke saath **ek hi pull command** (pm2 restart + save), (2) agent **khud screenshot le kar** assess kare (390 / 820 / 1366 laptop / 1440), (3) kaam **bina ruke jaari**, ek batch ke baad agla, (4) har summary ke end mein **sach wali Loophole ledger**, (5) repo + memory file hamesha taaza, (6) founder ke bheje screenshots (live site ki tasveer) ko pehle padho — woh asli user ki nazar hai.

### Rule 23 — ai.anexomail.com BAND: koi kaam nahi (locked 18 Oct 2026, 05:35 PKT, founder)
Founder ka hukm: `ai.anexomail.com` (LEO AI) alag product hai, **agle saal launch**, abhi priority nahi; pehle anexomail.com 100% bug-free. Jab tak founder khud likh kar na kahe: **AI surface par koi kaam nahi** — na naya feature, na copy/UI badlav, na check script, na installer, na Rust/Brain proc usi ke liye. Jo pehle se repo mein hai (SiteLock: awam ko sirf `/` coming-soon, baqi gated; `docs/cursor-work/ai/`) jaisa hai waisa rahe aur awam ko wahan kuch naya nazar nahi aana chahiye. Koi kaam AI surface ko chhuta lage to ruk kar founder se poochho.

---

### Rule 24 — Founder ki chat commands repo mein paste; compact ke baad PEHLE wohi padho; kaam hote hi pull command (locked 19 Oct 2026 05:20 PKT, founder)
Founder ka hukm (verbatim): "jo chat main command dun ga … woh paste hoga repo main … compact chat ho bhi jaye tum meri command jo mainay chat pe di thi us ko repo main ja ke read kero gay aur jo kaam us main se hogaya hai us ko usi time mujhe pull ki command do gay … yeh rule strictly follow kerna hai yeh rule read kiye bina kaam nahi shuru hoga."
- **Ek jagah: `docs/cursor-work/founder/founder-commands.md`** (halat table + verbatim commands). Founder ka har naya hukm/command **usi turn mein, kaam shuru karne se pehle**, verbatim wahan paste (naya sabse upar) + halat (DONE/READY/TODO) — phir docs-only commit + push.
- **Har naye chat / compact ke baad: pehle yeh file (aur Rule 18 ki memory file) poori padho; uske baghair koi command/kaam shuru nahi.** Purani command dobara chalane se pehle yahan halat dekho.
- **Jo kaam ho chuka (READY/DONE) uski usi waqt founder ko pull/install command do** — **har technology ki alag, ek ek karke**: SQL (psql), Rust (`rust-engine-install.sh`), Web (`pull.sh`), Brain, Caddy. Mix ek block mein nahi.
- **Ek time par sirf 1–2 point (founder, 19 Oct 05:47):** `founder-commands.md` ke "ABHI KA KAAM" mein bas yehi 1–2 point; baqi "Baad mein". Agla point tab jab ye server par pull/chalne ke baad green ho (founder batata hai). Agent apne se naya pending nahi jodta.
- Secret/password founder chat mein de to bhi file mein `[REDACTED]`; scripts silent prompt se lein.
- Caddy (Edge + HTTP/3) kabhi nahi tootna: koi bhi badlav read-only check -> backup -> `caddy validate` -> reload.

### Rule 25 — Technology kahan lagti hai: LAW + Constitution + goal (locked 19 Oct 2026 06:34 PKT, founder)
Founder ka hukm (verbatim): "yeh technology jahan pe ani hai yeh rule hai law hai constitution hai aur goal hai ke ahista ahista puri website sql likhne advance level pe bun se shift kerna hai yeh technology pe ya is se bhi advance technology pe."
- **Ek jagah: `docs/cursor-work/TECH-MAP.md` section 0 ("LAW — kaun si technology KAHAN")** — Jagah -> Technology -> Kaam (sirf yehi). Is se bahar koi technology kisi kaam par nahi; naya tech pehle wahan likho.
- **Goal:** website + SQL likhna Bun se hata kar us table ki technology (ya usse advance) par — ahista ahista, har qadam differential test + live verify ke baad; website kabhi nahi tootti.
- **Version upgrades PRIORITY QUEUE** (TECH-MAP 0a: tokio -> axum 0.8 -> wtransport/quinn/rustls -> rustc/edition 2024 -> Bun): ek ek, scratch copy par `cargo check` + tests, `rust-safe-deploy.sh` restore-on-fail, live saboot. Upgrade se pehle official source se version dobara verify (Rule 20).
- Caddy (Edge + HTTP/3) aur Polar :3400 kabhi nahi tootne; mail (Postfix/Dovecot/OpenDKIM) founder ke "haan" ke baghair nahi.

### Rule 26 — Agent ki mindset: CEO + user ka dimaagh, Google Workspace aur Zoho se behtar (locked 20 Oct 2026 03:18 PKT, founder)
Founder (verbatim): "ab tumharay pass login hai tumhay human yani mere se better judgment hai ke user ko google workspace aur zoho se better anexomail workspace kya dai ga. Tum CEO ho aur yeh repo main likho takay claude ko apni mindset yaad ho jaye. … codes advance level likho website tootni nahi chaiye hai."
- **Main CEO hoon.** Test accounts se khud login karke (Basic `basic.test`, Pro `pro.buyer`, Business Pro `business_pro.test`/`bpro.test`; Business `business.test` banna baqi) har screen user ki nazar se dekhta hoon: kya ye Google Workspace / Zoho se behtar, aasaan aur tez hai? Jawab "nahi" ho to wo masla NOTES mein (`founder-commands.md`), apni baari par theek.
- **Behtar kya hoga (soch):** pehle 60 second mein apna address kaam karta dikhe; ek tap mein purani mail andar (Import mail) sealed receipt ke saath; organisation ke andar file dedup (ek file ek baar); har cheez phone par bhi poori; sach bolne wali screens (koi jhoota "live" nahi); latest technology (Rule 25) par tez aur mehfooz.
- **Kaam ka tareeqa:** tarteeb `founder-commands.md` "ABHI KA KAAM" se; ek waqt ek package + ek masla; code advance level ka, par **website kabhi nahi tootti** (backup, restore-on-fail, health check); har kaam ke baad technology ke hisab se alag pull command; founder se dobara wohi sawal nahi.
- **Live user-testing (founder 20 Oct 03:59, verbatim):** "tumne live website user ki tarah use kerni hai aur CEO ki tarah montor kerni hai … one by one dekho jab sab perfect ho jaye phir next package pe jana hai. awam ko honesty sale kerni hai imamndari aur duniya ke advance working wire features send kerna hai." Tarteeb (founder 04:03): Basic -> Pro -> Business -> Business Pro; ek package perfect, phir agla; masle NOTES mein.
- **Founder 20 Oct 04:37:** har jawab ke saath latest GitHub pull command (Web `pull.sh`) HAMESHA. Mila hua masla founder ko naya kaam bana kar nahi dena — CEO khud theek kare aur saboot ke saath "green" bataye.
- **Deploy PATTERN (founder 20 Oct 05:03, LOCKED):** har kaam ke baad founder ko teen command isi tarteeb se: (1) fix/install (technology ka, pm2 restart andar), (2) Web pull `pull.sh` (latest GitHub, pm2 restart + save), (3) live test. Live login (test accounts) bhoolna nahi.
- **Design (founder 20 Oct 06:07):** cinematic 3D (Three.js / GSAP / Framer Motion — Constitution mein maujood) jahan sach mein behtar lage wahan *thora* — har jagah nahi; mobile par halka (Rule 19), `prefers-reduced-motion` ka khayal.
- **Passwords:** founder chat mein deta hai; agent sirf usi chat mein test ke liye use karta hai; repo/memory/script mein KABHI nahi.

### Rule 29 — Loophole sab GREEN: founder ko loophole-list nahi, sirf fix ki summary (locked 20 Oct 2026 19:54 PKT, founder, "last warning")
Founder (verbatim): "tumhay bola tha ke mujhe loophole khatham ker ke do aur jab green ho jaye tab bolo lekin tum mujhe bolte ho ke loophole baki hai … agar baki hai phir tumhara kya faida hai live login use kerne ka?? last warning … repo main rule likh lo ke mujhe loophole sab green chaiye hain ek bhi blunder nahi bachay."
- **Loophole ki list founder ko kabhi nahi bhejni.** Jo loophole mile use usi turn mein khud band karo (code + test + repo + push), phir sirf "kya fix hua + pull command + saboot" batao. "Baqi hai" sirf tab, jab kaam sach mein founder ke bas ki cheez ho (server par un ka command chalana, Supabase paste) — woh bhi command ke saath, savaal ke taur par nahi.
- **Founder se password/login dobara nahi maangne.** Test accounts (`basic.test`, `pro.buyer`, `business.test`, `business_pro.test`) ke passwords sandbox file `/root/.anexo-test-creds` (chmod 600, repo ke bahar) mein hain — compact ke baad wahin se, kabhi repo/log/chat mein nahi. Live test ke liye khud test account banao (real signup flow, Rule 26 "business.test banna baqi"), password sirf ephemeral (env/process), repo/memory/log mein kabhi nahi. Account na ban sake to local real-stack test (Postgres + real crates + Playwright) karo aur likho kya live nahi ho saka aur kyun — phir bhi loophole nahi, "verified-local" ki halat ke saath.
- **"Green" ka matlab:** test chala, natija dekha. Nakli green nahi (Rule 5). Jo kaam promise (footer/policy) hai woh `PROMISES.md` mein sabut ke saath.
- **Har founder command ke BAAD repo update + push (compact ka khatra hamesha):** founder-commands.md (verbatim + halat), blueprint/PROMISES ki halat, DEPLOY-MANIFEST sync+verify (Rule 28), phir push. Claude compact ke baad wahin se continue kare.
- **Har technology ki alag pull command** (SQL / Rust / Brain / Web / timer) har kaam ke saath — mix block nahi.
- **DONE-LOG (founder 20 Oct 20:10, "bar bar same kaam repeat"):** `docs/cursor-work/DONE-DO-NOT-REPEAT.md` mein jo kaam ho chuka woh dobara nahi; har kaam ke baad wahan ek line + compact se pehle repo update. Latest technology (Rule 25) hi.
- **Hash policy (founder 20 Oct):** `docs/cursor-work/HASHING.md` — HMAC-SHA256 aur SHA-256 kab kaunsa; code wahi follow kare.

### Rule 30 — Jo kaam ho chuka dobara nahi: DONE ledger + sirf latest technology (locked 20 Oct 2026 20:09 PKT, founder)
Founder (verbatim): "mainay dekha hai ke bar bar same kaam repeat kaam ker rahay ho compact chat se pehle repo update kero aur likho ke yeh kaam already ho chuka phir se repeat nahi kerna hai … latest technology pe kaam kero sirf."
- **`docs/cursor-work/DONE-DO-NOT-REPEAT.md`**: har kaam ke baad ek line (kya DONE, kis saboot se). Compact ke baad Rule 24 ki file ke saath ise padho; jo wahan DONE hai use dobara na banao, na dobara audit karo.
- **Sirf latest technology** (Rule 25 / TECH-MAP section 0): naya backend Rust; purani/dead technology par naya kaam nahi.

---

## PENDING (founder action required)

| Item | Action |
|---|---|
| MAIL send+receive | **GREEN 27 Sep 2026** — founder confirmed send and receive both live. Do not reopen. |
| ANEXOMAIL blueprint (59 phases) | **Founder paste kare** → `docs/anexomail-blueprint.md` banegi |
| SQL phase60/61/62 | Supabase #4 SQL Editor mein paste karo (tarteeb se) |
| Server pull | `git pull && bun install && bun run build:bun && pm2 restart...` |

## Rule 31 — Compact ke baad padhna + repo update (3-command limit RADD: founder 21 Oct 2026 00:11 PKT verbatim: "is rule ko goli maaro")
- 3-command / browser-test ki had KHATAM (founder ne radd ki). Ab ek jawab mein jitna kaam zaroori ho, kaam poora karo; progress aakhir mein dikhao.
- Compact ke baad PEHLE: `docs/cursor-work/founder/founder-commands.md` + `docs/cursor-work/DONE-DO-NOT-REPEAT.md` + is file ke Rules. Jo "DONE" hai dobara nahi (Basic ka kaam hazaron bar ho chuka). Sirf "TODO" par kaam.
- Har kaam ke baad repo update + manifest 0 bad + push, compact se pehle bhi. Sandbox copy: /home/claude/FOUNDER-RULES.md.
- Tarteeb (founder): live test Basic->Pro->Business->Business Pro (1440/820/390) | G38 | G40 | G42 | Business Pro baqi | walid ka account | founder profile | AnexoChat. Ek green hone par agla.

## Rule 32 — CEO + user ka mindset + REPO == LIVE (founder 20 Oct 2026 23:57 PKT)
- Founder (verbatim ka matlab): "tum CEO ho; user ka mindset tumne likhna hai; pura repo green karna hai aur repo ke codes live website se match karne hain; jahan gap hai theek karo; BAHUT KAAM server par hai repo mein nahi — smartly socho."
- User ka mindset (har kaam se pehle): main us package ka asli customer hoon — pehle 10 minute mein kya karunga? Kya wada kiya gaya hai aur kya sach mein chalta hai? Kya phone par (390) bhi? Jo wada pura nahi, copy halki karo (jhoota nahi). Basic user = mail, people, calendar, work (CRM/chat/AI nahi). Pro/Business/Business Pro apni surface; "mix" nahi.
- Repo == live: server par jo hai (Brain files, SQL functions, Caddy/Postfix/systemd, pm2 env) wo PEHLE read-only audit se dekho (A1 in `MASTER-GAP-LEDGER.md`), phir repo mein laao; "repo mein nahi" ka matlab "server par nahi" NAHI. Kisi live cheez ko repo ke andaze se overwrite mat karo.
- Master hisaab: `docs/cursor-work/MASTER-GAP-LEDGER.md` (GREEN / CODE / TODO / CHECK / FOUNDER). Har kaam ke baad wahan ek line.

## Rule 33 — Kaam ka tareeqa: pehle khud, phir founder (founder 21 Oct 2026 00:26 PKT)
Masla mile to: (1) khud repo/code mein wajah dhoondho, (2) fix likho, (3) sandbox/local DB mein reproduce + test, (4) repo update + manifest 0 bad + push, (5) founder ko ek command (sirf wo jo server hi kar sakta hai), (6) Chrome mein live verify. Founder se diagnosis ke liye baar baar mat maango; Chrome ruk jaye to code se aage badho. Sandbox copy: /home/claude/FOUNDER-RULES.md.
(Rule 33 ka hissa, founder 21 Oct 00:42) Tareeqa: founder ke pull ke baad Chrome mein live dekho -> root se fix -> repo update -> live dobara test -> har technology ki alag command. Login founder khud karta hai; main uske logged-in session par test karta hoon.

## Rule 34 — MOBILE + TABLET sab se upar (founder 21 Oct 2026 01:31 PKT)
Mobile aur tablet ko SAB SE BARI PRIORITY. Website mein jab bhi koi edit ho, pull ke baad LIVE Chrome mein 390 (phone), 820 (tablet), 1200+ (laptop) — teeno par test, tabhi GREEN. Sandbox/repo mein har step ke saath likho. (Rule 34 ka hissa) G35 passkey 27 Oct deadline sirf REAL users ke liye; test accounts (basic.test etc.) par passkey nahi banana/force nahi karna. Graphics ON/OFF Settings -> Appearance (data-ax-fx) har plan ke liye universal.

## Rule 35 — Jo Rust/latest technology par MIGRATE ho chuka wo NO-TOUCH; aur login/passkey ka sach (founder 21 Oct 2026 03:07 PKT)
- Founder (verbatim ka matlab): pehle ke Claude ne bahut zyada kaam latest technology par migrate kar diya hai aur Rust ka latest version server par founder se install karwaya tha — **us ko touch mat karna**. Wohi dekho: `docs/cursor-work/TECH-MAP.md` 0c ("DONE live") + 0a (versions: tokio 1.53.3, axum 0.8.9, wtransport 0.7.2/quinn 0.11/rustls 0.23, rustc 1.99.1 edition 2024) + `DONE-DO-NOT-REPEAT.md`. Rust modules (attach, cal, device, dnsauth, export, locale, mig, people, security, team, deliver/inbound) aur unke live proc **mat badlo, mat dobara likho, version mat chhedo** — badlav sirf founder ke "haan" + `rust-engine-install.sh`/upgrade script (backup, restore-on-fail) se.
- Meri (21 Oct) ginti "Rust ~1/3" sirf naamon ki andaza thi, galat taur par kam dikha sakti hai — **asli sach TECH-MAP 0c hai**, ginti nahi.
- Maine 21 Oct ko sirf yeh badla: Bun ke andar `server/lib/auth-harden.ts`, `server/lib/supa.ts`, `server/routes/auth.ts` (userFrom 503), `routes/crm.ts` install, `auth-passkey` status exempt — Rust ko koi haath nahi.
- Test accounts ke email+password sandbox mein `/root/.anexo-test-creds` (chmod 600, repo ke bahar) — kabhi repo/chat/log mein nahi. Production site (anexomail.com) ke login form mein password type karna cloud agent ke liye mana hai; uski jagah server-side `docs/cursor-work/server/login-probe.sh` (founder silent prompt mein password deta hai) + Chrome mein founder ke apne logged-in session par dekhna.
- Kaam ka tareeqa (jo founder ko pasand hai): website ka dimaagh (code) -> sandbox/local test -> server par chal kar test -> har technology ki ALAG pull command -> live dekhna.

## Rule 36 — Chrome sirf FINAL LOOK ke liye (founder 21 Oct 2026 03:15 PKT)
Chrome ke baghair kaam karo (code -> sandbox test -> server par test -> technology-wise pull). Chrome tab SIRF jab founder pull kar chuka ho aur website user ko final kaisi nazar aati hai woh dekhni ho. Chrome se debugging/loop-chasing nahi. Founder ne Rule 35 par "haan" kaha: latest technology (Rust) par kaam ki ijazat — phir bhi har Rust badlav sirf surgical + `cargo check` + restore-on-fail script se.


## Rule 37 — UNIVERSAL UI (founder 21 Oct 2026, LOCKED)
Website/app ka har UI, copy, layout, calendar/mail/domains/dashboard badlav **sab packages par ek saath** lagta hai. Package ke hisab se alag code/alag edit nahi — warna kaam har package par dobara karna parta hai.
- Package ka farq SIRF: `plan-surface.ts` (kya khulta hai: capability), `plans.ts`/`personal-tiers.ts` (card, price), billing/checkout/onboarding. Component/route mein `billed === "pro"` jaisi tier-literal comparison NAHI; tier logic `plan-surface.ts` mein capability bana kar rakho, component sirf capability dekhe.
- Guard: `src/lib/tier-guard.test.ts` (+ `tier-guard.baseline.json`, ratchet: sirf ghat sakta hai; naya file 0). Test fail = tier-code galat jagah. Purane 18 comparisons (AppShell, Greeting, crm.index, integrations, FollowThrough) kabhi chhoo to capability mein nikalo aur baseline ghatao.
- Har UI badlav ke baad chaaron packages: `docs/cursor-work/server/tier-sweep.sh` (server) + live look 1440/820/390 sirf farq-wali jagah par.

## Rule 38 — SQL duniya ke ADVANCE level ka, har baar (founder 22 Oct 2026 04:43 PKT, STRICT)
Founder (verbatim): "kya sql duniya ka advance hai rule likho ke founder ke strict rule hai ke sql duniya ke advance hogay claude sql read karay ga tab tak read karay ga jab tak sql duniya ka advance level pe reach nahi ker jaye sql likho advance level"
- **Har SQL file (E-series) likhne ke baad agent use khud dobara PADHTA hai, aur tab tak padh kar sudharta hai jab tak woh duniya ke advance level par na pahunch jaye.** Pehli draft "theek hai" nahi maani jati.
- Advance level ki checklist (har file par): (1) idempotent, koi DROP TABLE/COLUMN nahi; (2) `lock_timeout` + `statement_timeout`; (3) bari/live table par constraint `NOT VALID` phir `VALIDATE` (lamba ACCESS EXCLUSIVE lock nahi); (4) shape DB khud check kare (CHECK + IMMUTABLE PARALLEL SAFE function, pinned `search_path`), Rust ke qaide ka mirror, kabhi Rust se sakht nahi; (5) RLS + revoke, sirf zaroori grant, trigger/function par bhi revoke; (6) FK ON DELETE ka faisla (privacy: account delete = data saaf); (7) zaroori index (partial/covering) — aur jo query abhi nahi us ka index nahi; (8) comments; (9) `CHECK_<NAME>.sql` jo sirf padhe AUR behaviour test kare (good accept, bad reject), sirf existence nahi; (10) local Postgres par SAAF DB par do baar chala kar (dobara chalana safe) test, real insert se reject/accept ka saboot; (11) server par SQL sirf `sql-run.sh` se (Supabase editor kabhi nahi).
- Sandbox copy: /home/claude/FOUNDER-RULES.md. Compact ke baad is Rule ko padho.

## Rule 39 — SIGN-IN BUTTON KA A: LOCKED, founder ke bolne tak KABHI nahi badlega (founder 22 Oct 2026 05:08 PKT, STRICT)
Founder (verbatim): "yessssss yeh hai woh kaamal kya bnaya hai waha love you cursor jata hai sign in pe toh logo kaise bahar ata hai forever yeh kero jab tak founder yani main nahi bolun tab tak nahi change kerna hai yeh puri website ke liye hain repo main rule likho codes ko save kero sirf signin ko touch kerna hai baki sab style intact hai no codes change hain"
- Kya: `/auth` ke **Sign in (submit) button** par cursor/focus jaye to asli A (BrandMark) button ke andar label ke left mein bahar aata hai aur halka sway karta hai; sign-in ho raha ho (busy) to A dhadakta hai (BrandSpinner). Reduced-motion / Graphics OFF / calm par A sirf dikhta hai, hilta nahi.
- Code: `src/routes/auth.tsx` (submit Button: class `ax-a-hover` + `<HoverA busy={busy} />`), `src/components/state/BrandLoader.tsx` (`HoverA`), `src/styles.css` (block "HoverA (founder lock 22 Oct 2026, Rule 39)": `.ax-a-hover`, `.ax-a-slot`, `ax-a-sway`). Backup: `docs/cursor-work/backups/signin-a-20261022/`.
- **LOCK:** founder ke "badlo" kahe baghair na badla jaye, na hataya jaye, na doosre buttons/pages par copy/extend kiya jaye (passkey-enrol button jaan-boojh kar original rakha). Baqi poori website ka style/code intact — sirf Sign in button chhua gaya.
- Radd hui cheez (dobara nahi): left-panel cursor tilt (d3d42fe, reverted 2dcefa8).

## Rule 40 — Family/lifetime accounts = UNLIMITED, real-buyer jaise (founder 22 Oct 2026 06:36 PKT, STRICT; Rule 37 ka wazahat)
Founder (verbatim): "subject to agar woh feature un ko required hai toh lekin family pe yeh rule apply nahi hota hai un ko unlimted access milti hai (jis main yeh lifetime package plan pe hai) family ki user real buyer ki tarah sab account/profile nazar ana rule hai".
- Rule 37 (har UI edit sab packages ko ek saath) **us hadd tak jahan feature us package ko chahiye** (capability `plan-surface.ts` se). Basic/Pro/Business/Business Pro apni capability tak.
- **Family accounts par package-gating lagu NAHI.** Unhein lifetime plan ke tahat UNLIMITED access milti hai (har feature, har surface, koi limit/upsell nahi) — aur woh **asli khareedar ki tarah poora account/profile (billing "Lifetime access", dashboard, har page)** dekhte hain. Koi family-only alag UI nahi banti; capability resolver family entitlement (`family_accounts` / org-membership) ko "sab kuch" deta hai.
- Naya feature likhte waqt: (1) capability gate sirf paid packages ke liye, (2) family/lifetime resolver `unlimited`, (3) live test mein ek family account (e.g. Hamza) se bhi dekho ke feature dikhta/chalta hai aur koi "Upgrade" nazar nahi aata, (4) kisi family account ke liye alag branch/tier-literal nahi.

## Rule 41 — Har naye commit ke saath server/pull commands (founder 22 Oct 2026 09:50 PKT, STRICT)
Founder: "pull commands new commits ke saath hamesha do". Har push ke baad jawab mein commit hash + us commit ke liye zaroori commands (SQL → Rust → Web, alag alag full commands, sirf jo badla). Sirf docs badle to "server command nahi chahiye" likho.

- **SQL file ki pehli line KHALI rakho (founder 22 Oct 09:55):** Supabase editor mein paste par pehla character kat sakta hai; blank line ho to comment salamat rehta hai. Har nayi E-series aur CHECK file par.

**Rust restart + health (founder 22 Oct 22:17, rule ka hissa):** jab Rust badla ho, Rust install ke BAAD yeh bhi command diya jaye (Rust ka third step):
`pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`  (200 chahiye). Brain badla ho to `brain-*-install.sh` khud anexomail-leo (+anexochat) restart karti hai.

## Rule 42 — SQL DONO jagah chalni chahiye: server (`sql-run.sh`/psql) AUR Supabase SQL editor (paste) (founder 22 Oct 2026 10:06 PKT, STRICT; Rule 38 ka hissa)
Founder: "sql ka rule hai ke server pe bhi run hogi aur supabase editor main bhi". Har nayi E-series aur CHECK file BARABAR dono tareeqon se chale:
1. **Pehli line KHALI** (editor paste pehla character kha sakta hai — 22 Oct: `- E63` error).
2. **Koi psql meta-command nahi** (`\set`, `\echo`, `\gset`, `\i`, `\if`…): editor mein syntax error. Variable chahiye to `do $$ ... $$` ya `set_config`.
3. **Woh cheezein nahi jo transaction mein nahi chalti:** `CREATE INDEX CONCURRENTLY`, `VACUUM`, `ALTER SYSTEM`, `CREATE DATABASE`. (Bari table par index chahiye to alag note ke saath founder ko batao, is rule se bahar.)
4. **Apna BEGIN/COMMIT nahi** (sirf `proofs/` sandbox files mein, jo server/editor par chalti hi nahi).
5. **CHECK_*.sql = ek hi SELECT** (editor sirf aakhri result dikhata hai; sql-run `t`/`f` ko OK/FAIL banata hai).
6. **Poori script khud-kifayati:** `set lock_timeout/statement_timeout` file ke andar; editor ke session mein bhi chale.
7. **Lint (push se PEHLE, har nayi SQL par):** `python3 docs/cursor-work/server/sql-editor-lint.py <files>` — exit 0 chahiye. Plus sandbox mein "pehla character gum" simulation: `tail -c +2 file.sql | psql -v ON_ERROR_STOP=1` — 0 error.
8. Server par `sql-run.sh` ab bhi tarjeehi raasta (ledger + sha), editor founder ke liye barabar maanya. Jawab mein dono tareeqe likho jab SQL ho (editor: "repo se file dobara copy karo, purani copy mat chalao").
Purani files (E61 aur pehle) jo chal chuki hain unhein badalna zaroori nahi; naya rule nayi files par.

## Rule 43 — Ab se har SQL RLS-ON wali (founder 22 Oct 2026 20:17 PKT, STRICT; Rule 38/42 ka hissa)
Founder: "ajj ke bad se sql rls on wali hogi … ek sql likho jis se warnings aur rls sab on ho jaye".
- Har nayi E-series jo table banaye: usi file mein `alter table … enable row level security`, `revoke all … from anon, authenticated`, aur ya to asli policy ya `service_role` policy (backend service_role hai). Naya view = `security_invoker = on`; naya function = `set search_path` pinned; SECURITY DEFINER = execute public/anon se wapas.
- `CHECK_<NAME>.sql` mein "RLS on" ka item. RLS kabhi wapas OFF nahi.
- Sweep + safety-net: `docs/cursor-work/sql/E65_rls_and_advisor_sweep.sql` (+ `CHECK_E65.sql`): purani sab tables RLS-on, bina-policy tables band, views/functions advisor-clean, aur event trigger `ax_rls_auto_enable` jo nayi public table par khud RLS ON karta hai. Extensions ko public se nahi hilata.

- **SQL server command — do shakalein (founder 22 Oct 2026 20:28–20:29 PKT):**
  (a) sab nayi SQL apne aap: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)` (bina naam = AUTO: repo ki nayi E-series E37+, ledger se, tarteeb se, phir unke CHECK_E<n>).
  (b) khaas file: naam aakhir mein, bina `.sql` ke: `… sql-run.sh) E65_rls_and_advisor_sweep CHECK_E65`.
  Founder ko SQL ke liye har baar in mein se sahi wali command do (Supabase editor zaroori nahi). Agent server par khud nahi chalata (Rule 15).

## Rule 44 — SQL server par chalti hai, editor par nahi (founder 22 Oct 2026 20:32 PKT, STRICT)
Founder: "yeh sql wali command pehle run hogi, yeh ab server pe run hogi; editor pe jo run hoti thi ab woh server pe … compact chat ke baad Claude yeh nahi bhoole; ab new sql run hogi isi tarah."
- Raasta: `docs/cursor-work/server/sql-run.sh` (ledger `/var/lib/anexomail/sql-applied.tsv`, ON_ERROR_STOP, CHECK_E<n> baad mein). Bina naam = AUTO (saari nayi E-series), ya naam de kar khaas file (command Rule 41 mein).
- Tarteeb: SQL -> Rust -> Web. SQL pehle, kyunke Rust/Web nayi SQL par tikte hain.
- Rule 42 (editor-compat: blank first line, no meta-commands, single-SELECT CHECK) NAYI files par ab bhi lagu — safety ke liye — par founder ko editor ka raasta nahi bataya jata.

- **Bare command ka test (founder 22 Oct 2026 20:34, sandbox mein saabit):** `… sql-run.sh)` bina naam: 0 nayi = "koi nayi SQL nahi"; ek nayi = wahi ek + CHECK; kai nayi = number ki tarteeb se sab + CHECK; fix hui (sha badli) SQL dobara chalti hai; sirf khali pehli line ka farq nahi chalta. Har run ke baad E65 sweep + CHECK_E65 khud. Isliye SQL ke liye founder ko HAMESHA yehi bare command do (naam wali sirf tab jab FORCE=1 ya khaas file chahiye).

## Rule 45 — Sign-in bhi latest technology (Rust) par; Bun hamesha emergency; vault ke qaide (founder 22 Oct 2026 20:50 PKT, STRICT)
Founder: sign-in/auth bhi Bun se latest technology par; Bun fallback hamesha; frontend latest; SQL super-advance; passkey data + device record vault mein; wrong activity => account blocked + vault mein safe hash; dobara signup par vault match, blacklisted = account nahi banega.
Poora plan + policy mel: `docs/cursor-work/AUTH-MIGRATION-PLAN.md` (phases A–D, vault requirements, privacy audit). Public privacy/footer copy founder ke "haan" ke baghair nahi badlti. Passkey id se returning banda pehchanna technically nahi hota — asli rokna device hash + email HMAC tombstone.

## Rule 46 — DEPLOY KA AEEN: tarteeb + technology ke hisab se command (founder 22 Oct 2026 22:19, CONSTITUTION)
Har push ke saath sirf WOH steps do jin technology ka code badla, hamesha isi tarteeb mein, har step alag poori command:
1. **SQL** (Postgres/Supabase) — `sql-run.sh` (bare = AUTO). Hamesha sab se pehle (Rule 44).
2. **Rust** (axum/tokio async, :3200) — `rust-engine-install.sh`.
3. **Rust restart + health** — `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health` (200).
4. **Brain / chat (Bun fallback, anexomail-leo :3100 + anexochat :3300)** — sirf agar `server/*.ts` badla: us change ka `brain-*-install.sh` (surgical, restore-on-fail). `pull.sh` Brain ko deploy NAHI karta.
5. **Web (frontend)** — `pull.sh` (build + pm2 anexomail-web) + Ctrl+Shift+R. Hamesha aakhir mein.
Har technology ka apna raasta: frontend=pull.sh, Rust=install+restart, Bun=brain installer, SQL=sql-run.sh; ek ka command doosri technology ko deploy nahi karta. Polar :3400, Caddy, mail stack ko founder "haan" ke bina haath nahi. Is rule ko Rule 41 ka commit-message/jawab format follow karna hai (commit hash + sirf zaroori steps). Naya technology aaye (jaise sign-in Rust par) to is list mein uska step jodna lazmi.

## Rule 47 — ZABAN: founder se HAMESHA Roman Urdu (Hinglish) mein baat, "aap" kehkar (founder 23 Oct 2026 02:01 PKT, STRICT)
**KHITAB (founder 23 Oct 2026 04:42): founder ko sirf "Nauman bhai" kaho — poora naam (Muhammad Nauman Sherwani) kabhi nahi: na jawab mein, na docs/commit ke khitab mein.**
Founder (verbatim): "yeh englishmain kya baqwas kerta hai mere saath". Founder se har jawab, summary, status aur final message Roman Urdu mein. English sirf code, file/proc ke naam, commands aur technical terms mein. Compact ke baad bhi yehi (compact summary English mein ho to bhi founder ko jawab Roman Urdu). Commit messages English reh sakte hain.

## Rule 48 — Founder ko SIRF repo ki likhi hui, aazmayi hui commands; apni taraf se command KABHI nahi gharni (founder 23 Oct 2026 03:01 PKT, STRICT)
Founder (verbatim): "tune yeh chawal nahi maarni hai yeh repo main note kero".
- **Server par chalne wali har command pehle repo mein maujood ho** (`founder/founder-commands.md`, Rule 41/44/46 ki shaklein, ya `docs/cursor-work/server/*.sh`). Jo command repo mein nahi, wo founder ko nahi di jati — "andaze se" ya "aam git tareeqa" wali command bhi nahi.
- **`/opt/anexomail-web` mein KABHI `git merge` / `pull` / `checkout` / `reset` / `stash` nahi.** Us folder ka working tree repo se alag hai; merge "Aborting" hota hai (23 Oct 03:00 ka hadsa). Sirf yeh shakal: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/<script>.sh)` — ye working tree ko chhuti nahi.
- "Sync" / "pull" ka matlab hamesha ek hi cheez: Rule 46 ki technology-wise command (sql-run.sh / rust-engine-install.sh / pull.sh). Docs-only push par jawab: "server command nahi chahiye".
- Naya qism ki command ki zaroorat ho to: pehle script repo mein likho, sandbox mein chalao, `founder-commands.md` mein daalo, phir founder ko do.
- Galti ho jaye to turant: ye rule + `DONE-DO-NOT-REPEAT.md` mein note, founder ko Roman Urdu mein sach.

## Rule 50 — Migration phase table saath ke saath update (founder 24 Oct 2026 17:18 PKT, STRICT)
Founder: poori website 8 phases (M1-M6, L, F, B8) mein latest technology par; "yeh saath ke saath update hoga". `docs/cursor-work/MIGRATION-PHASES-RUST-PRIMARY.md` ka phase table aur `docs/claude/MIGRATION-LEDGER-24OCT.md` (+CSV) har kaam ke saath usi turn mein update (halat + ginti). Ek code path sab account kinds (`resolve_plan`), founder routes alag batch F, shared helpers ek jagah, client sirf `rpcOrRest`, Bun hamesha emergency fallback. Phase GREEN = Basic-user test + Chrome 1440/820/390 live.

## Rule 52 — WASM kernel: browser mein builtin, version har feature ke saath update (founder 26 Oct 2026, STRICT)
Founder: "yeh mind main lock ker lo ke yeh WASM KERNEL browser main builtin hogay yeh version update hote rahay gay yeh rule hai feature ke saath."
- ANEXOMAIL ke browser-side mein ek general-purpose WASM KERNEL compute kernel (**Rust, async, tRPC, WebTransport, async, Tokio mein likhna hai -> WASM KERNEL**) **builtin** hota hai (founder ke apne alfaaz, 26 Oct 20:19 PKT: "yeh hai rule") — poori website ke liye, sirf ek feature ke liye nahi (docs/claude/ANEXOCHAT-CINEMATIC-VOICE-BLUEPRINT.md section A).
- **Standing rule:** jab bhi koi naya client-side-heavy feature banay (audio FFT, chunked upload, large-data processing), pehle yeh socho ke woh is WASM kernel ke andar ek module ban sakta hai ya nahi, aur kernel ka version us feature ke saath update hota hai (naya module add → version bump). Alag-alag, bikhri hui WASM files nahi — ek kernel, ander modules.
- **Implementation (26 Oct 2026, founder 07:49-07:58 PKT, SHAKHT):** kernel `web-wasm/` hai — **Rust, async, Tokio (LocalSet), WebTransport**. EK kernel, EK QUIC connection, EK generic RPC: naya feature = naya endpoint/page NAHI; har proc `/wt/rpc` se wohi server `dispatch()` (wahi gates) se guzarta hai, fallback plain fetch. Modules (v0.2.0): sha256, hmac (HMAC-SHA256), sniff, rank, live, rpc. App ka darwaza `src/lib/kernel/boot.ts`; `rpc.ts` aur `live.ts` pehle kernel, phir purana raasta. Pin: `public/kernel/anexo-kernel-<ver>.wasm` + SHA-256 `src/lib/kernel/pin.gen.ts` (`scripts/build-kernel.sh`; naya module = MODULES + version bump Cargo+lib.rs). **3 round test lazmi:** (1) `cargo test` (native), (2) real wasm in bun (`bun test src/lib/kernel`), (3) asli Chromium + asli QUIC Rust server. Bun sirf fallback.


(26 Oct 2026 10:30 PKT, REAL wiring) Request tag: kernel hmac@1 har WebTransport call par HMAC-SHA256(session_key, "<proc>.<ts>.<sha256hex(input)>") lagata hai (ticket kernel.ticket se, 15 min, key sirf memory). Rust wtrpc_glue session key SQL `kernel_session_key` (E91) se EK baar leta hai, cache karta hai, har tag Tokio mein LOCALLY verify. `ANEXO_TAG_MODE=observe` (default, sirf ginti) | `enforce` (bina sahi tag ke 401; client fetch par girta hai). Enforce tab, jab observe mein invalid=0 aur missing sirf purane tabs ka ho. Kernel `warmKernel()` AppShell mount par idle mein jaagta hai. `anexoKernel.stats` = kernel vs fetch calls ki asli ginti. Typed contract: `src/lib/rpc-contract.ts` + `rpc-contract.test.ts` (Rust gates se drift = test fail). Browser mein quinn nahi: browser ka apna WebTransport/QUIC; quinn server (wtransport) par hai.

## Rule 53 (STRICT, founder 26 Oct 2026 04:05 PKT) — har package ka feature-gate REPO mein likha ho
Har package (5 business + 3 personal + 3 AI) ko kaun sa feature milega, yeh `docs/cursor-work/PACKAGE-FEATURE-FORMULA.md` mein likha rahe ga (source of truth). Naya feature = pehle wahan gate likho, phir code (plan-surface.ts/plans.ts, Rule 37). Pricing/plans ka kaam `docs/claude/PRICING-AND-PLANS-PHASE-26OCT.md` ke phases PP0-PP7 mein. AI plans COMING SOON (July 2027 tak); Enterprise AI mein shamil nahi (human/workspace package). Technology: latest stack + WASM kernel (Rule 52) poori website + har subdomain ke liye common.

## Rule 54 (STRICT, founder 26 Oct 2026 04:20 PKT) — competitor-first: har policy/feature/price se pehle Google/Zoho (aur doosre competitors) dekho
Jab bhi koi policy, feature, price, limit ya package add/change karna ho: PEHLE competitors (Google Workspace, Zoho, Microsoft 365, Proton...) ka official page/pricing dekh kar likho woh kya karte hain (verified, source link), PHIR hamari offer unse behtar rakho (user ko better deal = user hamare saath chipka rahe). Doc mein "Competitor check" line ke baghair koi pricing/policy change commit nahi. Landing par competitor ke baare mein claim sirf verified aur safe wording mein.
Founding-member price-lock = 24 mahine (2 saal), pehli 150 companies.

UPDATE 26 Oct 2026 05:07 PKT: Enterprise price = £18,500/month (Rule 51/53 mein jahan £15,000 tha, ab £18,500). Enterprise Business Pro ke baad ALAG phase mein banega (poori website ka chehra, advanced tech, abhi zero).
UPDATE 26 Oct 2026 09:27 PKT (founder): Enterprise = £18,500/month (pehle £18,000), yearly CEO proposal £185,000 (x10). ENTERPRISE BUN SE DUR: Enterprise ka koi bhi endpoint/feature Bun fallback par nahi chalega -- sirf Rust :3200 + WebTransport + WASM kernel. Enterprise code likhte waqt server/routes/*.ts mein kuch nahi.

## Rule 55 (STRICT, founder 26 Oct 2026 05:20 PKT) — har package: PER MONTH + USER CAP zaroor likha ho
Har jagah jahan koi package dikhta hai (plans.ts card, plans.tsx, landing, billing/profile, Polar product description, SQL labels, emails) price "per month" (flat, per-user NAHI) likha ho AUR user cap saaf likha ho: Basic up to 5 users, Pro up to 20, Business up to 60, Business Pro up to 570, Enterprise unlimited. Cap ke baghair koi package card/page commit nahi.

UPDATE 26 Oct 2026 05:45 PKT: Business Basic storage = 15GB SHARED + 3 mailboxes (25GB / 5 mailboxes galat the). Basic = £40/month, £440/year, up to 5 users, 25MB attachment. SQL: E87_basic_v6.sql.

## Rule 56 (STRICT, founder 26 Oct 2026 19:52 PKT) — NAYE KAAM MEIN BUN KA KOI KAAM NAHI
Founder: "yahan bun ko goli maaro, naya kaam mein bun ka koi kaam nahi hai."
- Ab se har NAYA proc / feature / endpoint SIRF Rust (:3200, async Tokio) + WebTransport/WASM kernel (Rule 52) mein banta hai. `server/routes/*.ts` mein naya route, naya Bun fallback, naya `rpcOrRest` REST path NAHI likha jata.
- Naye proc ka `get(proc, "/api/...")` wala REST fallback bhi nahi; UI seedha `rpc()` use kare (jaise `crm-setup.ts`).
- Purana Bun code (jo abhi live fallback hai) TAB tak rehta hai jab tak uska Rust port live green na ho; phir Bun route hataya jata hai (ek ek, saboot ke baad). Bina Rust port + live saboot ke purana Bun route NAHI hatta (founder ka live chalta kaam na tootay).
- Port ki tarteeb: Pro ke pages jo abhi `kernel_status_404` dete hain (`crm.live`, `org.members`) PEHLE, phir baaqi fallbackProcs ki list (`window.anexoKernel.fallbackProcs`).
- Bun Brain (:3100 anexomail-leo) alag cheez hai: us par yeh rule nahi, woh sirf `brain-*-install.sh` se.

UPDATE Rule 52 (founder 26 Oct 2026 20:05 PKT): "ab se Rule 52 se browser ka shuru hoga, Supabase isko cement pakka karega; website Rule 52 ke mutabiq chalegi. yaad rakhna." => browser ka har call pehle WASM kernel se (browser -> kernel/QUIC -> Rust dispatch -> Supabase/Postgres); fetch sirf fallback; `anexoKernel.stats.fetch` ~0 aur `fallbackProcs` khali rakhna maqsad. Browser seedha Supabase se baat nahi karta. Guard: src/lib/kernel/rule52.test.ts; saboot: docs/cursor-work/RULE-52-PROOF.md. G1/G2 (ek QUIC session + ANEXOChat kernel mein) Business phase mein.

## Rule 57 (STRICT, founder 26 Oct 2026 22:14 PKT) — HAR ENDPOINT/GATE KA PACKAGE REPO MEIN LIKHA HOTA HAI (website mix na ho)
- Poori map: `docs/claude/ENDPOINT-PACKAGE-MAP-26OCT.md` + `ENDPOINT-PACKAGE-MAP.csv` (script `docs/claude/endpoint-package-map.py`; rules PP1-FULL-GATE-TABLE-26OCT.md + docs/packages/features.tsv). Har Bun endpoint aur har Rust proc ka `starts_at` (basic | pro | business | business_pro | founder | ai_soon | internal) likha hai; upar ke packages ko bhi milta hai. Enterprise = Business Pro ki har cheez + poori website Rust-only/Bun-free (alag endpoint nahi).
- NAYA endpoint/proc/gate likhne se PEHLE map mein uska package dekho. Map mein na ho => pehle rule/CSV mein jodo (founder confirm wali cheez "CEO guess" likho), phir code. Gate SERVER par (Rust `resolve_plan`), UI sirf aaina. Test: `src/lib/endpoint-map.test.ts` (koi UNCLASSIFIED nahi).
- Claude seedha isi map se implement kare; dobara feature->package ki behes nahi (PP1 table pehle se hai).

- **Rule 58 — Office suite (Writer/Sheet/Show, N-DOC-01) Business package ka hai** (Basic/Pro/CRM mein nahi). Detail: docs/packages/business/OFFICE-SUITE.md. Rust + WebTransport/WASM kernel par hi banega (Rule 52/56).

- **Rule 59 — Rust domain error status:** "nahi mila"/conflict jaisi business errors 409/422 hain, 404 SIRF "yeh proc Rust mein nahi" (client 404/501/502/503 par Bun par girta hai). Guard: rpc-contract.test.ts.

**HANDOFF #3:** docs/claude/CODES-WRITTEN-LEDGER-27OCT.md pehle padho.

- **Rule 60 — Cinematic/3D frontend stack (founder 27 Oct 2026 00:51):** three.js/R3F/WebGPU+TSL/GSAP ScrollTrigger+Lenis/Theatre.js/Rapier/GLSL Moon shaders/Web Audio+WASM Opus/OffscreenCanvas/KTX2+Draco/Rive/View Transitions/Spline-glTF aur **WebXR VR/AR (zaroori)** ab se implement hongi, jahan `docs/claude/CINEMATIC-FRONTEND-STACK-27OCT.md` section E mein likha hai. Kaam wale screens (mail/work/CRM/Office) cinematic nahi. Har 3D chunk lazy + fallback + measure.

## Rule 61 (STRICT, founder 28 Oct 2026 05:00 PKT) — FOUNDER ki CORE TECHNOLOGY (Bun nahi, Node nahi) — yehi banega
Founder ne plan manzoor kiya: "repo main likh lo ke yeh hai core Founder ki technology ... yehi bana hai". Detail + phases: `docs/claude/FOUNDER-BUILD-PLAN-28OCT.md`; protocol: `docs/claude/FOUNDER-PROTOCOL-28OCT.md`; inventory: `docs/claude/FOUNDER-CODE-INVENTORY-28OCT.md`.
- **Backend:** naya Rust binary `anexomail-founder` (crate `server/founder/`), alag service + alag Linux user; axum 0.8.9 + tokio; live = WebTransport/QUIC; data Supabase se; **passkey (WebAuthn) lazmi** (password + passkey dono); SHA-256 audit hash-chain + HMAC. Founder ke 53 Bun-only endpoint Rust par port; Bun route tabhi hatega jab Rust ka saboot aaye. **Founder mein Bun/Node runtime KABHI nahi.**
- **UI:** React 19.2, Vite 8.2, TanStack Router (static SPA), Tailwind 4.2, shadcn, Three.js WebGPU (lazy), Motion/GSAP, WASM kernel (audit chain browser mein verify). Server par sirf Rust binary.
- **Shakal:** command bridge — pehle 5 second mein paisa + "kya bigad raha hai" + awam ki awaaz; neeche People, Mail Desk, Release, Move-In, Systems, Control; har action do-tap + reason + audit. Privacy: metadata-only (content kabhi nahi).
- **Phases:** F0 design -> F1a security fix -> F1b foundation -> F2 Bridge -> F3 Money+Release -> F4 People -> F5 Mail Desk -> F6 Systems -> F7 3D -> F8 Control -> F9 cutover. Ek ke baad agla, har phase ka exit saboot plan mein.
- Nexatect (parent) ka alag login: anexomail.com puri website banne ke BAAD.
- **Security (founder 28 Oct 05:07):** founder mein Rule 52 kernel builtin + `ANEXO_TAG_MODE=enforce` hamesha; military-level hardening: `docs/claude/founder/FOUNDER-SECURITY-28OCT.md`. Founder ka sab kuch ek jagah: `docs/claude/founder/INDEX.md`.
- **Product lane (founder 28 Oct 05:13):** Docs+Sheets editor sab packages (Rule 58 supersede), HR+Accounting, 1-click Google/Microsoft migration => `docs/claude/OFFICE-HR-ACCOUNTING-MIGRATION-28OCT.md` (PLAN; founder phases F1a+ pehle).

## Rule 62 (STRICT, founder 28 Oct 2026 05:25 PKT) — TECHNOLOGY PEHLE, phir blueprint, phir code
Har blueprint/plan/phase ke SHURU mein technology likhi ho aur har section mein "yahan is technology par code" saaf ho. Pehle technology dekho (TECH-MAP + Rule 61 founder / Rule 52 kernel), phir blueprint mein daalo, phir code. Galat technology = founder bardasht nahi karega. Founder ka look: CINEMATIC (Elon-level), awam UI se ALAG design; awam-side kaam (Office/HR/Accounting/migration) founder se alag lane.

## Rule 63 (STRICT, founder 28 Oct 2026 05:26 PKT) — banane se PEHLE discuss, phir build; LIVE data, koi dummy/mock nahi
Har naye kaam ki technology + data ka raasta pehle founder ke saath discuss ho aur repo mein likha ho (founder ka locked raasta: FOUNDER-BUILD-PLAN §1z), phir hi build. Founder/production UI mein dummy ya mock data KABHI nahi: jo data abhi nahi, screen par saaf "abhi connect nahi" likha jaye. Test hamesha live (Chrome). Design mock sirf F0 design canvas mein jayez (production nahi).

## Rule 64 (STRICT, founder 28 Oct 2026 06:10 PKT) — EK PHASE: green, Chrome par LIVE dekha, phir agla
Founder ke kaam mein ek waqt mein ek phase. Phase tab GREEN jab (1) server par command chali, (2) saboot/CHECK sab OK, (3) Chrome par live dekha gaya. Us se pehle agle phase ka code/pull/command NAHI diya jata, na do phase ki commands mix ki jati hain. Code pehle likha ho to bhi uska pull tab tak nahi jab tak pichla phase green na ho.

## Rule 65 (STRICT, founder 28 Oct 2026 06:37 PKT) — Lovable codes + blueprint DONO samne, features tarteeb se; UI saaf, cluster nahi
Founder ka kaam: purane Lovable founder code (docs/claude/founder/CODES/01-FILES, 02-ENDPOINTS) aur blueprint (FOUNDER-BUILD-PLAN-28OCT, §6z FX list) DONO samne rakh kar, feature list ki tarteeb se, ek-ek phase. UI: cluster/bheed NAHI — aankhon ko aasaan, saaf, kam cheezein ek screen par; lekin Admin mein sab kuch maujood (kuch gum nahi hota, sirf sahi jagah/andar). Har purani feature ka naye mein ghar blueprint mein likha hona chahiye.

## Rule 66 (STRICT, founder 28 Oct 2026 06:57 PKT) — har phase ke saath TECHNOLOGY + pull command (blueprint mein likha)
Blueprint (docs/claude/FOUNDER-BUILD-PLAN-28OCT.md §11z) mein HAR phase ke agay likha hota hai: kaun si technology is phase mein, kaun se codes likhe jayenge, aur founder ko kaun si pull command. Pull command technology ke hisaab se: SQL=`sql-run.sh` (+CHECK), Rust+SPA=`founder-install.sh`, Caddy=`founder-host.sh`, awam web (sirf F9)=`pull.sh`. SERVER PAR `git pull` KABHI NAHI (working tree untracked) — sirf `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:<script>)`. Phase badle to table pehle update, phir code.

## Rule 67 (STRICT, founder 28 Oct 2026 06:58 PKT) — Founder UI ki zubaan ENGLISH
Founder/user ko dikhne wali HAR screen ka text English (jaisa pehle wala awam/founder UI tha: "Good morning", "Command center", "Sign in"). Roman Urdu sirf founder se chat mein, UI mein kabhi nahi. Purana jo achha tha (dark premium look, English copy) woh base; naya design usi ko behtar kare, bura/ajeeb nahi. Ab tak /f/ login mein Roman Urdu tha ("Sirf founder ka darwaza") — GALAT, F1c se pehle hi English kiya jaye.

## Rule 68 (STRICT, founder 28 Oct 2026 07:03 PKT) — founder ka EXISTING login (/auth, founderworkspace host) hi rahega
Founder ko maujooda login (/auth: cinema split, passkey, recovery codes — src/routes/auth.tsx) pasand hai: usay NA badlo NA hatao. Naya founder (/f/) ka apna password form final front door nahi — F1a mein /f/ is login ke peeche jaata hai (login -> /f/), aur /f/ founder token `/founder/v1/exchange` se leta hai (uid in founder_accounts + device/passkey, aud=anexo-founder, memory-only). Awam hosts (anexomail.com, www, ai.) par founder account ka login refuse (loophole band) — founder sirf founderworkspace se.
