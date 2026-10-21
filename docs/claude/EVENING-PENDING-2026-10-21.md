# SHAAM KA KAAM — 21 Oct 2026 (Wed), baad 08:33 PKT — yahan se continue
> Founder ka hukm: B5 tak kaam complete + GREEN. Baqi sab shaam ko isi din (21 Oct 2026). Naya session/compact: PEHLE `CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md` + yeh file. Koi code dobara mat likho (DONE-DO-NOT-REPEAT.md).

## Halat (08:33)
- **B1, B2, B2b, B3, B4, B5 = GREEN** (server output ke saath). B5: founder output 08:27 (public Rust procs live, founder procs 401, daam 790/46 Rust, 23/46/97/790 Brain, ConfirmButton + BrandMark web par).
- Repo HEAD aaj ka: 4036963+ (origin/main). Server par jo abhi nahi: `founder.brain.command` (Rust, b5 module) — agla Web pull + `MODULES=b5` rust-engine-install.sh se aayega (koi jaldi nahi, React center hata diya).
- Web pull ka sahi form: `bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh)`.

## SHAAM KI TARTEEB
1. **B6 (G16) = POLAR CONTROL PLANE** (founder 21:41; plan `POLAR-CONTROL-PLANE-PLAN.md`; B6a security+portal+prewarm -> B6b intents -> B6c alarms/kill-switch). Purani line: Polar :3400 payments/prices/landing = **NO TOUCH**. Rust-first `billing.*` procs (plan view, usage, invoices list, cancel/resume request, seats change request — jo Polar webhook se confirm hon), Bun `/api/billing/subscription` bug theek, frontend `app.billing` rpcOrRest, sandbox proof (mock Supabase + asli Bun routes vs Rust), installer (rust-engine-install.sh mein naya module), pull commands. Frontend 390/820/1440 combo audit.
2. **B7 (G26/G27): calendar** — status PARTIAL (live Chrome check 08:4x, c0df9e4). Maujood: Month/Week/Day, time-grid + drag/resize, new-meeting form (agenda gate), Find a time, Avail. (availability API link), .ics import/export, RSVP lookup/respond. **Banana hai (shaam):**
   1. **G26 iMIP reply** — guest Gmail/Outlook se Accept/Decline kare to ANEXOMAIL event mein khud aaye (anexopipe hook; production mail path => founder ki "haan" chahiye pehle).
   2. **G27 recurrence** — har din/hafta/mahina/saal, INTERVAL/COUNT/UNTIL/EXDATE, "is event / sab events" edit (ics.ts parser pehle se hai, UI + Rust expand banao).
   3. **G27 scheduling link (booking page)** — public page jahan mehmaan khali slot chun kar book kare (Avail. API buniyad hai).
   4. **G27 2-way sync** + **CalDAV** server.
   Frontend 390/820/1440 combo audit saath. Pro/Business account par kal shaam wala "naya calendar" demo — founder switch kare to dekhna (Basic tab mein naya kuch nahi mila).
3. **B8: Brain ~38 route files / ~504 endpoints -> Rust** incl. AI chat (Leo memory + OpenRouter stream), Bun 1.4.3, tokio 1.54, axum 0.8 (`axum-upgrade.sh`), beast-mode list `TECH-STACK-BEAST.md` §A2.
4. **Migration testing — SAB B-batches ke END par** (founder ka order).
5. **Live package tests** Pro -> Business -> Business Pro, 1440/820/390, NAYE Chrome tab: WebTransport push (B4) asli browser mein, Humza lifetime label, version history, Security page, Domains page, outbound attachment send.
6. **Founder side — B-series GREEN ke BAAD** (`FOUNDER-WORKSPACE-PLAN.md`, stack = sulah, privacy = metadata only, "Founder view"): F0 design -> F1 foundation... F9.
7. **10 email addresses build + working wire** (`src/lib/founder-plan.ts`) + founder ka alag email system + Nexatect addresses — founder-side ke saath/baad.

## Chhote pending (jab mauqa ho)
- **30 Oct 2026 se pehle:** Supabase #4 — naye tables ko explicit GRANT. `E55_grants_heal.sql` (idempotent; sab maujooda public tables par service_role/authenticated grants ka sach likhna, anon nahi) + har naye SQL mein grants (rule DONE-DO-NOT-REPEAT 21 Oct 21:24). Supabase dashboard mein dekhna: project ke Data API settings.
- GREEN-BOARD: B5 row GREEN (karna: 04-TECHNOLOGY, 01-GREEN, 03-G-SERIES G40, P8) — aaj update hua.
- D11 ops: Caddy cert renewal **12 Nov se pehle**; Bun `/api/billing/subscription` bug (B6 mein); E24 email_hash HMAC migrate; E52 alias fair-use SQL; **A5 `FOUNDER_PASSWORD` plain compare `auth.ts:631`**; `/terms` page draft; Caddy read-only check script; Domains ke 7 baqi features; chat audit; branch switch `/opt/ANEXOMAIL-WORKSPACE`.
- Server par `BrandMark.tsx.bak` hata di jaye (agar abhi nahi hui): `rm -f /opt/anexomail-web/src/components/site/BrandMark.tsx.bak`.
- Founder se pending jawab: `FINAL-FOUNDER-BLUEPRINT.md` poora merge ya index (summary) — abhi index.
- Sandbox: crates/wasm ke liye `NO_PROXY= no_proxy=` karo; web `tsc` type-check abhi nahi chalta (npm/bun DNS flaky) — dobara try karo.

## Har batch ka usool (dobara likhna nahi parega)
memory pehle update -> advanced code -> sandbox proof -> poore pull commands -> "green" sirf founder ke server output ke baad -> frontend+backend combo audit (390/820/1440) -> manifest-sync + verify -> commit/push + `/home/claude/sandbox-state/` copies.

## STATUS 22:05 — B6a code likha ja chuka (0a32282). Ab sirf SERVER INSTALL + founder output + GREEN. Phir B6b (checkout prewarm, founder ijazat) / B6c. Phir B7 (calendar), B8. Code dobara mat likho — DONE-DO-NOT-REPEAT.md dekho.

## 23:55 — BILLING PORTAL (billingportal.anexomail.com): blueprint repo mein, P1 (Caddy+placeholder) bana. Agla: P2 core read (portal.summary/invoices Rust, plan card, invoices, Polar handshake). Ye B6 install (steps 2-5) ke saath chalega. B7/B8 abhi baad mein.


## 22 Oct 2026 00:50 — B6a server progress (founder ka output dekha)
- Founder order: B6 poora GREEN pehle, phir portal/B7/B8. Discount kabhi nahi. Grace 3 din = countdown -> read-only + sending pause; inbound hamesha qabool; 421 nahi.
- GREEN: step 2 (polar-control-plane, muhar+kill switch+signed Polar probe) aur step 3 (Rust b6 billing.portal, nakli token 401). BAQI: step 4 brain-portal-install, step 5 caddy-polar-lockdown (plan->apply), step 6 asli Manage billing click.
- Loader: asli BrandMark A hero (generic silver 3D A hata diya, bc59368); WORKSPACE lockup Option 1/2 jawab baqi; favicon ek-source demo baqi.
- billingportal.anexomail.com Caddy par live (placeholder). Portal build B6 green ke BAAD.
- Yaad: pull.sh sirf manifest files; Rust sources git objects se; pkill -x; kabhi poori Caddyfile overwrite nahi.
