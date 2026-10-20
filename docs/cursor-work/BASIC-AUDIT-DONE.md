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
