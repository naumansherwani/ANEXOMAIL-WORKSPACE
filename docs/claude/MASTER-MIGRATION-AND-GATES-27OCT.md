# MASTER MIGRATION + GATES — ek jagah: sab series (P, G, B, R, M, T, C/D/E, F, L, K) + technology + kaun sa gate kis package ko (27 Oct 2026 04:11 PKT)
Founder hukm (27 Oct 04:08): "puri website latest technology pe migrate, saath mein kaun sa gate kis ko mile ga, sab series ek jagah, repo mein likho."
**Tarteeb sirf docs/claude/ONE-ORDER-27OCT.md ki chalti hai.** Yeh file nakshe/dictionary hai: har series ka matlab, halat, aur technology. Naya number yahan mat banao; ginti hamesha `python3 docs/cursor-work/server/count-endpoints.py` se.

## 1. "Latest technology" = ek raasta (Rule 52), alag alag stack nahi
Screen (React 19.2 + TanStack Router/Query + Tailwind 4 + Vite 8) -> WASM kernel web-wasm v0.2.0 (HMAC tag, rpc(), fallback) -> QUIC/WebTransport (/wt/rpc, /wt/events, chat) -> Rust axum 0.8 + Tokio :3200 (asli kaam + package gate resolve_plan) -> Supabase/Postgres (browser kabhi seedha nahi).
Bun :3100 = sirf emergency fallback (Rule 56). Rust domain errors 409/400/422, 404 sirf unknown_proc (Rule 59); client sirf 404/501/502/503/0 par Bun par girta hai. Gate server par, UI aaina (Rule 57). Cinematic/WebXR sirf Rule 60 ki jagah, Business+, K3 ke baad; kaam wali screens seedhi. "tRPC" = Rust ka apna typed proc contract (rpc-contract.ts), asli npm library nahi.
Migration ka matlab: har endpoint ko browser->REST->Bun->Supabase se hata kar browser->kernel->Rust->Supabase par laana.

## 2. Frontend technology (docs/claude/FRONTEND-TECHNOLOGY-PLAN-27OCT.md): rewrite nahi
F1 sab data kernel se (steps 2-7) | F2 23 polls -> WebTransport push (qadam 8, L) | F3 heavy compute kernel mein (search index, MIME sanitiser, dedup) | F4 React Compiler + virtualised lists + code split (naap pehle; G8/M11 vite.config no-touch ki chhoot) | F5 SSR host Bun se bahar (Enterprise) | F6 ANEXOChat media WebAudio/WebCodecs/WASM Opus, ek QUIC session K3 (Business+) | F7 Office suite CRDT (Business+) | F8 offline/PWA | F9 passkeys mandatory (27 Oct) | F10 View Transitions (aakhir).

## 3. Series ek jagah (har ek ka matlab, kahan likhi hai, halat)
| Series | Matlab | Detail kahan | Halat 27 Oct |
|---|---|---|---|
| **P1-P9** | Product pages: P1 Auth, P2 Dashboard, P3 Mail inbox, P4 Compose/send, P5 Thread view, P6 Contacts/People, P7 Calendar, P8 Founder workspace, P9 AI surface | docs/MASTER-BUILD-PLAN.md + docs/cursor-work/GREEN-BOARD/02-PLAN-P1-P9-vs-REPO.md (68 item) | Basic GREEN; Pro walk baaqi (qadam 5); P8 = F (qadam 9); P9 = ai_soon |
| **G1-G42** | Gap/audit list (attachments, passkey, billing, switch journey, plan-promise, ...) | docs/cursor-work/GREEN-BOARD/03-G-SERIES.md | G16 DONE; G9/G20-22 Business enforcement + plan-promise audit TODO (qadam 11-12); G41 Pro/Business live test TODO |
| **B1-B8** | Technology batches: B1 JWT, B2 passkey Rust, B3 mail.send, B4 event push, B5 19 Bun-only->Rust, B6 self-serve billing, B7 calendar, B8 Brain->Rust | docs/cursor-work/GREEN-BOARD/04-TECHNOLOGY.md | B1-B5 GREEN; B6 = C2 (qadam 6); B8 = yeh migration (ab ONE-ORDER ke qadam) |
| **R1-R5** | Rust-engine items: R1 send, R2 Stalwart, R3 typed contract, R4 direct pool, R5 push | T-SERIES-BLUEPRINT.md | R1/R5 GREEN; R2-R4 = T-series |
| **M1-M6 (migration)** | Endpoint migration milestones (M1/M2 done; M3 contacts/storage/support/workspace/billing; M4 auth+trial; M5 settings/integrations/security + org/crm/calendar; M6 Business 180) | ONE-ORDER "M-series ka nakshe se milan" | M3 done, M5 = qadam 3 (AGLA) |
| **M1-M7 (Outlook mail features)** | **ALAG cheez, naam takrata hai:** view/layout, favourites/flag/pin, signature/auto-reply, rules+sweep, schedule send+templates, Focused/Other, shared/delegate | docs/cursor-work/MAIL-OUTLOOK-MAP.md, MASTER-GAP-LEDGER M-SERIES | Naam: ab "MO1-MO7" kaho taake migration M se na milay; zyada hissa Pro/Basic mein live, baaqi Business |
| **T1-T12** | Technology track: T1 sqlx pool, T2 ts-rs types, T3 Bun/tokio upgrade, T4 speed, T5 Stalwart, T6 instant search, T7 instant mail, T8 delivery status, T9 collision guard live, T10 resumable upload, T11 never-down, T12 auto-update banner | docs/claude/T-SERIES-BLUEPRINT.md | qadam 12 ke baad (T9 Pro wada, T6 pehle) |
| **C1/C2, D, E (batches)** | C1 billing read (billx DONE), C2 billing paisa (intent/change-plan/sync) ; D = settings 7 + integrations 10 + security 7 ; E = account-deletion 3 + calendar export 1 | docs/claude/BATCH-PLAN-27OCT.md | C1 GREEN; D AGLA; E baad; C2 qadam 6 (founder ijazat + shadow) |
| **F** | Founder account (admin/perf/movein, 32 endpoints, Rust-only) | FOUNDER-WORKSPACE-PLAN.md | qadam 9 |
| **L** | 23 polls -> WebTransport live events | TECHNOLOGY-MAP section 2 | qadam 8 |
| **K3** | ANEXOChat ek QUIC session (rpc+events+chat), kernel 0.3.0 | docs/packages/business/ANEXOCHAT-K3-PLAN.md | Business phase |
| **N-DOC** | Office suite (Rule 58, Business) | docs/packages/business/OFFICE-SUITE.md | K3 ke baad |

## 4. Gate kis ko: endpoint registry ke asli number (count-endpoints.py, 04:08)
starts_at = woh sab se chhota package jis se endpoint kholta hai (ENDPOINT-PACKAGE-MAP.csv). Neeche Rust-first / baaqi.
| Package (starts_at) | Rust-first | Baaqi (Bun) | Matlab |
|---|---|---|---|
| basic (sab ko) | 72 | 72 | login 23, integrations 10, settings 7, security 7, trial 9, polar 7, billing-sync 5, deletion 3, calendar export 1 |
| pro | 51 | **0** | Pro-only endpoints sab Rust par |
| business | 5 | 183 | M6: v6 enforcement SQL, ANEXOChat, Office suite, org/CRM baaqi |
| business_pro | 0 | 5 | 570 users/10TB/60MB enforcement |
| founder | 31 | 44 | F qadam 9 |
| internal | 1 | 3 | |
| ai_soon | 27 | 29 | AI plan, baad mein |
| **Total** | **187** | **336** | 523 |
Package limits (pricing v6, flat per company, per-user fee nahi): Basic £40 (5 users, 15GB, 3 mailboxes, 25MB) | Pro £105 (20 users, 300GB, 35MB; 3 booking links, 4 trusted devices) | Business £360 (60 users, 1.5TB, 45MB, Office suite, ANEXOChat) | Business Pro £2,850 (570 users, 10TB, 60MB) | Enterprise £18,500 (Bun-free, baad mein). Basic/Pro enforcement SQL LIVE (E87/E88); **Business/Business Pro enforcement abhi code mein NAHI** (TODO-1).
Gate ka tareeqa: server par `resolve_plan` + `pro_gate`/`pro_only_proc` (Rust), SQL triggers/caps (team_seat_calc, storage_plans, booking_pages_cap, device_vault); UI sirf mirror (plan-surface.ts). Har package ki tafseel: docs/packages/<package>/GATES-AND-TECH.md, ENDPOINT-PACKAGE-MAP-26OCT.md.

## 5. Migration tarteeb (sirf ONE-ORDER): 1 wsx/billx GREEN | 2 Pro-only DONE | **3 Batch D (settings 7, integrations 10, security 7)** | 4 Batch E | 5 Pro Chrome walk | 6 login 23 + C2 | 7 PRO GREEN CLOSE | 8 L | 9 Founder | 10 Trial | 11 Business | 12 CRM P3-P6, Business Pro, T-series | 13 Enterprise (+Personal HOLD).
Naya kaam rule: registry dekho -> X_core.rs + X_glue.rs -> installer + probe + rpc-contract -> client rpcOrRest -> cargo check + dry-run -> founder deploy + probes -> Chrome -> tab GREEN.
