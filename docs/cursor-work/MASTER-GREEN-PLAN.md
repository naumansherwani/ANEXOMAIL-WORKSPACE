> **SUPERSEDED (27 Oct 2026): tarteeb ke liye sirf docs/claude/ONE-ORDER-27OCT.md.** Yeh file reference/history hai; isse naya kaam shuru na karein.

# MASTER GREEN PLAN — puri website, har gate, har endpoint, har package (founder hukm 26 Oct 2026 21:53 PKT) — PEHLE YEH PADHO
Founder (verbatim ma'na): "puri website ka ek bhi corner nahi chodna; sab gates green; sab end points latest technology (Rust + WebTransport/WASM kernel) par migrate aur green; basic, pro, aur in ke ilawa SAB packages green; repo mein tarteeb dekho aur tarteeb se chalo."
Qaida: GREEN = LIVE saboot (founder server output + Chrome). Naya kaam sirf Rust + WASM kernel (Rule 52/56). Bun sirf emergency fallback; route tab hatao jab Rust==Bun saabit ho.

## A. DEPLOYED / GREEN — DOBARA CODE NAHI LIKHNA (server par pull ho chuka, founder output saboot)
| Cheez | Commit | Saboot |
|---|---|---|
| Pro CRM P1+P2, crm.live, org.members Rust (livex) | d6d9240 etc. | Chrome Bun==Rust |
| Rule 52 early-boot, REST audit hook, guard tests | 288346f..cb20531 | kernel 9/fetch 0 |
| kernel-check retry 8x5s | 91d55ef | KERNEL CHECK ALL PASS |
| calendar.availability/focus 502 fix (focus_windows org_id only) | 4bd9dbc | ALL PASS (pro) 20:56 |
| "-£0" money() fix, pre-send scan English | d59d059 | deployed 21:36, ALL PASS |
| Availability working hours + local tz (tz_offset, work_hours) | 6a1d91e | deployed 21:48: ALL PASS basic+pro+KERNEL; Chrome Avail. = 16 slots, 9:00 AM se (09-17) |
Server abhi 55eafce par hai (docs-only baad ka commit). `src differ=1` = routeTree.gen.ts (benign).

## B. CEO FAISLA (26 Oct 22:05 PKT, founder: "yeh faisla tumne kerna hai, tum CEO ho; pehle ke sab kaam isi mein dalo") — FINAL TARTEEB, isi se chalna
Har qadam: ek ek GREEN (founder output + Chrome saboot), phir agla. Naya kaam sirf Rust + kernel; Bun sirf fallback.
| # | Qadam | Kya | Kyun yeh jagah |
|---|---|---|---|
| 1 | PRO WALK poora | public booking links(3), Overlap Matrix, shared inbox collision guard, snooze UI, hourly-rate/Focus UI, 4 trusted devices — Chrome mein dikhana; jo na dikhe woh theek karna | Pro package aaj customer ko bik raha hai; jo card par likha woh account mein nazar aana chahiye |
| 2 | RULE 52 top REST: `trial.state`, `auth.session` (read-only) | har page par 66 REST calls kam | sab se bada fetch; kam risk (sirf padhna) |
| 3 | M3: contacts+companies, storage state, workspace, dashboard, billing-sync, support (polar NO-TOUCH) | 51 endpoints | Pro ke daily features (People, Storage, Billing card) |
| 4 | M4: auth (login/logout/MFA/recovery/sessions) + trial baaqi | 33 | login-critical => differential test, ek ek |
| 5 | M5: org, settings, security, integrations, analytics, calendar leftovers, crm leftovers | 91 | Business ke liye zaroori + Pro settings |
| 6 | PRO GREEN CLOSE: ANEXO_TAG_MODE=enforce (founder env), saari Pro-relevant routes kernel 100%, PRO-GREEN-TRACKER sab GREEN | | Pro = "green" tab |
| 7 | BASIC package poora (har gate/endpoint probe + Chrome walk) | | Basic sab se zyada users |
| 8 | L: 23 polls -> WebTransport live events | | live feel, kam load |
| 9 | BUSINESS: M6 chat/ai/files + ANEXOChat + K3 (ONE QUIC, kernel 0.3.0) + N-DOC-01 + Business caps | 180 | Business phase |
| 10 | CRM P3-P6 (Blueprint P4) | | Business ke baad |
| 11 | BUSINESS PRO | | |
| 12 | F: founder/admin/perf/movein/glitch (alag batch) | 32 | internal |
| 13 | ENTERPRISE (Rust-only, Bun-free) + toolchain (sqlx pool, mimalloc, moka, tracing) | | akhir |
Pehle ke sab kaam (Pro tracker items, ANEXOChat K3 plan, CRM P3-P6, tag enforce, passkey Oct 27, Rule 52 G1/G2) ISI table ke qadam mein hain — alag list nahi.
Har port ka tareeqa: X_core (std-only tests) + X_glue + installer CFG/probe + rpc-contract + probe + Chrome Bun-vs-Rust proof; phir Bun route hatana.
Master Pro list: docs/packages/pro/PRO-GREEN-TRACKER.md. Halat/ginti: docs/cursor-work/MIGRATION-STATUS-26OCT.md.

## C. HAR ENDPOINT KA PACKAGE (Rule 57, 22:14) — docs/claude/ENDPOINT-PACKAGE-MAP-26OCT.md
Bun endpoints 523: Basic 141 | Pro 51 | Business 191 | Business Pro 5 | Founder 75 | AI (July 2027) 56 | Internal 4. Baaqi Bun-only: Basic 107, Pro 19, Business 189, BP 5, Founder 45, AI 29, Internal 4. Rust procs 341 (Basic 108, Pro 54, Business 161, Founder 18). Business Premium = Business Pro + poori website Rust-only. Qadam 3-6 (Pro green close) ke liye Pro ke 19 + Basic ke 107 baaqi endpoints pehle; Business 189 Business phase mein.

- [ ] SCRATCH CRATE: cargo check ke liye rustls+webpki-roots Cargo.toml [dependencies] mein judte hain (cargo --offline, ~/.cargo cache) — kabhi stub/skip nahi.

## 27 Oct 2026 03:55 — authx + contx + basx LIVE GREEN (founder deploy 01:49)
Founder output: Rust par ab '... trialx authx contx basx wtrpc'; Rust restart 190; Web pull OK; ALL PASS (basic) + ALL PASS (pro) + KERNEL CHECK ALL PASS. 15 purane FAIL ka sabab: us waqt installer ruk gaya tha (ai-usage clash) — fix 452dd4e; Basic storage 500 fix 4065cd0 — dono deployed, ab 0 FAIL. GREEN (code dobara NAHI likhna): auth.session; contacts.list/tags/get/update/tag/timeline; companies.list/get/timeline; search.universal; storage.state/preflight/reserve/commit/release; support.sla(public)/drafts/draftDiscard; workspace.setActive. Chrome proof Pro: people+storage kernel se, REST gayab. Endpoint ginti: Rust-first 161, baaqi 362. AGLA: Batch B2 workspace.personal/organisations/invitations, phir C billing-sync 12.

## 27 Oct 2026 01:59 PKT — COMPACT-SAFE STATE (sab se latest; PEHLE YEH PADHO)
TIME NOTE: aaj ki entries mein 02:20/02:40/02:55/03:05/03:30/03:50/03:55/04:20 wale stamps meri galti hain (session clock); asli waqt abhi 01:59 PKT. Entries ki TARTEEB hi sahi tarteeb hai.
LIVE GREEN (founder output + Chrome): authx (auth.session), contx (contacts x6, companies x3, search.universal), basx (storage x5, support.sla/drafts/draftDiscard, workspace.setActive), pehle ke: crmd (12 CRM), trialx (6), security.devices limit. Basic+Pro ALL PASS, KERNEL ALL PASS (01:49).
CODE LIKHA, DEPLOY PENDING: Batch B2 wsx (workspace.personal + workspace.organisations) commit 13df117/1513354 — founder ko 6 commands diye (founder-commands.md). Installer ab: authx contx basx wsx.
AGLA (tarteeb): C billing-sync 12 (Polar :3400 NO-TOUCH) -> D settings7+integrations10+security7 -> E account-deletion3+mail2+calendar1+locale1+trial9 -> Pro-only 4 (handoff delete, devices/seen, follow-up delete, analytics/:report) -> F auth login 24 (aakhir, fallback) -> tag enforce (founder env) + shared-inbox test (2nd Pro user).
RULES: har naye module pe PEHLE docs/cursor-work/server/installer-dryrun.sh + full crate cargo check (rustls+ring+webpki scratch /tmp/axchk), phir founder ko 6 commands; clash scan; Basic account se bhi probe (Basic ke paas chat workspace nahi — chat_ensure_workspace error deta hai). Founder ghussa: tabahi nahi, safe-stop tha; credit zaya na ho — code dobara mat likhna, batch-wise.
GINTI: 523 endpoints, Rust-first 163 (after wsx 2 = ~163), baaqi ~360. Gate/UI plan: docs/claude/BATCH-PLAN-27OCT.md. Pro baaqi ~8 deploy: docs/packages/pro/PRO-GREEN-TRACKER.md.
TECH: browser React19/TanStack/Vite8/Tailwind4 -> WASM kernel 0.2.0 -> QUIC/WebTransport (/wt/rpc) ya /rpc -> Rust axum/Tokio -> Supabase PostgREST; Bun sirf fallback; cinematic (three/R3F/GSAP/WebGPU/Theatre/Rapier/WebXR) sirf Rule 60 jagah, kaam wale screens nahi.

## 27 Oct 2026 02:08 PKT — wsx (workspace.personal/organisations) LIVE: probes ALL PASS
Founder deploy 02:08: Rust par ab '... trialx authx contx basx wsx wtrpc', Rust restart 193, Web pull OK, ALL PASS (basic) + ALL PASS (pro) + KERNEL CHECK ALL PASS. Probe saboot: bad name/anexomail domain/bad domain => 400; existing workspace => existing:true (koi naya workspace nahi bana). KHULA ITEM (loophole): NAYA-USER creation path (organisations->org_members->account_*->mail_accounts->profile stamp) LIVE nahi aazmaya — asli workspace banta, isliye probe mein nahi; sirf unit tests (slug/domain) + Bun fallback. Isay saaf test account (naya signup, zz.*) se Chrome mein aazmana hai PEHLE pro ko awam ke liye green kehne se. PRO GREEN STATUS: koi bhi item chhoot'na nahi — baaqi list GREEN-LEDGER/PRO-GREEN-TRACKER mein.
