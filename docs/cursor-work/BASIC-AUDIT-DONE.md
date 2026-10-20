# Basic-plan live audit — KYA HO CHUKA (duplicate mat banao)

> **Claude, compact ke baad PEHLE yeh file padho**, phir `founder/founder-commands.md` aur `TECH-MAP.md` (section 0 = LAW).
> Jo cheez neeche "DONE" hai woh dobara mat banao, mat likho. Pehle `git log --oneline` aur code dekho.
> Founder ka hukm (20 Oct 2026): tum CEO ho — khud live test karo, jo mismatch ho seedha fix karo, user complete (Basic -> Pro -> Business -> Business Pro) phir founder/AnexoChat. Founder ko sirf "fix ki list + green" do. Ek waqt mein ek package.
> Qaide: passwords sirf chat mein, kabhi repo/script/memory mein nahi. Never touch: polar-rust-payment :3400, Caddy (validate pehle), landing/logo/existing UI, vite.config.ts/package.json/bunfig.toml/.env.

## Batches (commit -> kya, kis technology mein)

| # | Commit | Masla (live par) | Hal | Technology |
|---|--------|------------------|-----|------------|
| 1 | c28d31f, 124eaa6 | `/sw.js` hamesha 404; offline kuch nahi; sign-out ke baad offline mail reh jati; Basic dashboard par Pro features ka jhoota text | Asli `public/sw.js` (VitePWA ka output production mein serve nahi hota), `lastSession` offline fallback, sign-out `clearOffline()` + cache wipe, Greeting.tsx plan ke hisab se | Web |
| 1b | 19dc155 | WebTransport: firewall + certificate hostname mismatch | Ek jagah `src/lib/wt-url.ts` -> `anexochat.anexomail.com:3443`; live server facts `server/live-facts-2026-10-20.md`. **Founder ko `ufw allow 3443/udp` chalana hai** | Web + server |
| 2 | f46987d, b38e1c2 | Security page murda tables padhta tha (sessions 0, Kill kuch nahi, Rotate keys jhoota) | SQL `E39_security_truth.sql`, Rust `security_core.rs`+`security_glue.rs` (10 `security.*` procs, live TLS 443/993/587/25), UI honest; rotate hata (provider-managed keys) | SQL + Rust + Web |
| 3 | 2d09c94 | Billing: Basic business account ko Business price (£97/25GB); yearly par monthly amount | SQL `E40_billing_price_truth.sql` (`get_billing_subscription`) | SQL |
| 4 | 2850733 | Settings toggle "false" string truthy => band toggle kabhi ON nahi; read receipts jhooti; tracking setting ignore | `isOn()`, optimistic update, Read receipts = "Never sent", `useBlockRemoteImages()` | Web |
| 5 | ffe9131 | Integrations "Connect" hamesha 501 | Jhoota button hata; "Copy my mail" -> `/app/import` (asli IMAP copy, Rust `mig_*`) | Web |
| 6 | 3e5a8d5 | **Calendar events kabhi load nahi hote the** (`calendar.events/event/load` na Rust na Bun) | `cal_glue.rs` mein teeno + `cal_core.rs` (`mark_conflicts`, `minutes_in`, `overloaded`), 22 unit test | Rust |

| 7 | (09:5x) | Mail ke address chips + folder + category tabs (All/Primary/Updates/People/Promotions) sirf patli scrollbar se scroll hote the; baqi icons nazar nahi aate | `src/lib/use-drag-scroll.ts` (mouse drag + wheel, click bachta hai) teeno rows par; profile menu mein **Settings** (-> `/app/settings`). Browser test: drag 0->154px->0, click chalta, menu mein Settings | Web |

| 8 | (10:1x) | (a) drag sirf mail list ki do patti par tha, mail kholne wali side par nahi chalta tha; (b) **Basic mein "AI settings" tab + Integrations "Leo Actions" tab** — qaida: workspace plans ko AI ZERO (PACKAGE-FEATURE-FORMULA rule 5) | (a) `installDragScroll()` AppShell se poori app mein har left-right patti par (thread header, settings/integrations tabs sab); purane per-row hooks hata diye. (b) AI tab/Leo tab sirf `isAiHost()`; `/app/settings/ai` seedha kholo to `surfaceDenial` lock deta hai | Web |

| 9 | (10:5x) | Server pull OK, AI tab gaya, par mail list ki patti par drag phir bhi "nahi chalta" (asli reason mere test mein reproduce nahi hua — test-browser mein drag chalta hai) | `HScroll.tsx`: jahan cheezein chhupi hon wahan kinare par saaf ‹ › button (click se scroll — kisi bhi mouse/touchpad par pakka), grab cursor, scrollbar par pakadna drag se alag; mail ke 3 rows + settings tabs par. Drag (`installDragScroll`) bhi qaim. **Ab bhi na chale to founder se: kis rows par, kaunsa browser/mouse — ek screenshot** | Web |

| 10 | (11:0x) | Drag phir bhi nahi: **asli sabab** = Chrome pakad kar khinchne par native drag-and-drop (`dragstart`) shuru karta hai => `pointercancel` => category row 9px hil kar ruk jati thi (mere pehle test mein nahi dikha, kyunki woh sirf kuch jagah se shuru hone par hota hai). Aur meri galti: "Leo Actions" tab **sab** plans se hata diya tha, jabke locked plans table mein Business/Business Pro mein Included hai | `installDragScroll`: row ke andar `dragstart`/`selectstart` preventDefault; HScroll rows `select-none`. Leo Actions tab wapas Business + Business Pro ko (Basic/Pro ko nahi; AI SETTINGS sab se gaya). Test: local, category row 9->90px | Web |

## BUSINESS PRO live audit (20 Oct 2026 18:5x, humzasherwani@anexomail.com — lifetime free, baqi sab real buyer jaisa; password KABHI repo mein nahi)
DB sahi: family_accounts + entitlement_state + trial_accounts teeno `business_pro`. Session/menu "Business Pro" dikhata hai.
**Green (live dekha):** 37 pages render, koi JS error nahi; plan-gating sahi (Admin lock, Settings/AI lock "AI settings are not on this workspace", AI-center rail mein nahi); Leo Actions tab Business Pro ko hai; Settings tabs mein AI nahi; Domains "unlimited domains · unlimited mailboxes · aliases free"; Billing "Business Pro £2850/month" + current plan; CRM overview asli data; Work: task banta + reload ke baad bhi rehta hai; Org members/Compliance/Audit ledger tabs; Chat; Safety; **Mail bhejna: 30s hold -> Sent mein -> Inbox mein deliver (poora chala)**; category row ‹ › arrow aate hain.
**Rust RPC 404 (CHAAL, kharabi nahi):** work.tasks/promises, crm.*, org.audit/compliance/proof, integrations.connections/providers, settings.list/history, call.record* — Rust mein nahi, `rpcOrRest` Bun par girta hai, Bun 200 deta hai (page theek). Speed-rule ke mutabiq asal mein inhe Rust par aana hai (baad ka kaam).
**BAQI / 100% green NAHI:**
1. **Compose mein attachments bheji nahi ja saktin** ("Attachments — coming soon", ComposeStudio.tsx ~597) — sab plans par. Parhna/download (inbound) maujood hai; bhejna (upload -> storage -> MIME -> Rust send) bana nahi. BADA kaam (ek technology = Rust MIME + storage + UI).
2. Compose: "Version history" band.
3. Settings > Workspace: "Retention window" ki value sirf "0" (matlab/unit nahi) — copy/value theek karni hai.
4. Billing: Hamza lifetime-free hai par billing "£2850/month" dikhata hai (family accounts ke liye "Lifetime access" label chahiye).
5. Mobile (390) Business Pro abhi test nahi hua; Business (non-Pro) aur Personal Pro+ (father) account alag test.

## 3D GRAPHICS — kahan ana hai (CEO faisla 20 Oct 2026; abhi bana NAHI, sirf naksha)
Halat: asli Three.js sirf AnexoChat `chat/cinema/Scene.tsx` mein hai. Baqi "cinematic" 2D canvas/CSS hai. Qaida: jahan 3D madad kare, jahan kaam ke raste mein aaye wahan NAHI (inbox/compose/settings = tez + saaf, 3D nahi).
| Jagah | 3D kya | Plan | Mobile |
|---|---|---|---|
| Landing hero | Dak ke packets ek 3D mailbox mein girte hain (ConvergenceCanvas ka 3D version) | sab | halka (kam particles) |
| Login / pehla workspace loader | BrandMark ka ghoomta 3D logo (WorkspaceLoader) | sab | halka |
| Dashboard hero (Greeting ke upar) | Plan ke rang ka chhota 3D badge/orb: Basic neela, Pro jamuni, Business sunehri | sab, 1 canvas | band (CSS gradient) |
| Empty states (khali inbox, khali calendar) | Chhoti 3D tasveer, sirf jab list khali ho | sab | band |
| Upgrade/plans page | Plan cards par halka 3D tilt | Basic ko dikhane ke liye | band |
| AnexoChat | Cinema scene (pehle se) | Pro+ | halka |
| **NAHI**: inbox list, thread, compose, settings, security, billing | — | — | — |
Har jagah: `prefers-reduced-motion` par band, lazy-load (pehle page chale, phir 3D), 1 page = 1 canvas. Founder ka hukm milne par ek ek karke banega; pehle landing hero.

## Pull / SQL status (founder ne chalana hai — aakhri maloom halat)
- Batch 1, dnsauth: LIVE green (founder output 09:25).
- Batch 2: Web pull + SQL E39 + `MODULES=security` Rust — founder ka output ka intezar.
- Batch 3: SQL E40 — founder ka output ka intezar.
- Batch 1b: `ufw allow 3443/udp` — founder confirm kare.
- Batch 5: Web pull. Batch 6: Rust `rust-calendar-install.sh` + Web pull — live test baqi.

## Abhi BAQI (Basic audit)
- Compose + Undo send live test (mera Playwright script selector par ruka — script ka masla, app ka nahi; dobara chalao).
- Contacts add, Calendar meeting banana (batch 6 deploy ke baad), aliases (Domains page "aliases are free" dikhta hai — asli kaam check karo).
- Account page: "SMS recovery is not wired yet" message.
- Work/CRM/Org gates: sirf nazar se check hue, functionally nahi.
- Uske baad: Pro -> Business -> Business Pro (Business/BP ke passwords founder se EK baar maango).

## Jaane-pehchane future kaam (abhi nahi)
- Bun fallback `/api/billing/subscription` mein purana bug (`workspace_subscriptions.storage_per_mailbox_gb` column nahi) — Rust primary hai isliye user ko nazar nahi aata.
- Caddy cert renewal (12 Nov 2026 se pehle): Rust engine restart chahiye cert uthane ko — script nahi bana.
- Domains "beat Zoho/Google" list: D3, Domain Connect, catch-all/forwarding/vacation, domain health guard, DMARC report reader, BIMI — Basic ke baad.

## Tareeqa jo kaam kar chuka (dobara mat banao)
- Local test: Postgres 16 `/var/tmp/anexo-pg`, mock Supabase, Rust type-check harness `rustmock/app` (asli crates sandbox mein blocked), Playwright `/opt/pw-browsers/chromium-1194`, npm ke liye `--proxy "$HTTPS_PROXY"`.
- Deploy: fix -> `manifest-sync.py <files>` -> commit/push `main` -> founder per-technology pull command (Web `pull.sh`, SQL, Rust installer) -> live test.
- Frontend pattern: `rpcOrRest()` pehle Rust, 404/501 par Bun. Naya read-proc Rust mein `owns()` + `dispatch()` + test.


## BUSINESS PRO — tablet (820) + mobile (390) live audit (20 Oct 2026 19:2x, Humza)
- 38 pages har ek size par. **Koi OVERFLOW nahi** (na 820, na 390). AI settings / LEO center ka lock page 820 par theek (screenshot dekha).
- Console mein sirf do tarah ki cheezen: (a) `/rpc/work.*, crm.*, org.*, integrations.*, settings.*` 404 — Rust mein nahi, Bun fallback chalta hai, page chalte hain (G40 speed ka kaam); (b) WebTransport `:3443/wt/mail` ERR_TUNNEL_CONNECTION_FAILED — sirf is test sandbox mein (UDP band), founder ke browser mein `ufw allow 3443/udp` ke baad dekhna hai.
- Rule 19 (mobile+tablet+computer saath) ab har package par lazmi.
