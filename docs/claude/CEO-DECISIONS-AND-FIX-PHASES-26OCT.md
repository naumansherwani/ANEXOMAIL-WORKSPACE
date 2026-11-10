> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# CEO decisions + mistake-fix phases (26 Oct 2026 04:00 PKT) — docs-only, koi code nahi

Founder ne sab faisle CEO ko delegate kiye ("tum ceo sab faislay kero jo zoho aur google ki buildings main hulchul paida karay"). Veto hamesha founder ka.

## A. CEO faisle
1. **Founding-member**: pehle **150 orgs**, price **24 mahine lock** (monthly price badle to bhi), "Founding" badge. Lifetime lock nahi (cost badle to phasna nahi).
2. **Waves**: pehle 4 hafte **25 orgs/hafta** (=100), phir **50/hafta**, aur server utilisation >70% par auto-pause. Signup kholna sirf Pro+Business+Business Pro GREEN + M3 ke baad.
3. **Move-In**: har trial ko **free pilot migration (3 mailboxes tak)**; full Move-In free **annual Business Pro/Business Premium** ko; baqi ko listed one-off **£568-3,350 -- PRICES INTACT (founder 04:05: price wahi rahe ga)**.
4. **[SUPERSEDED 04:05 -- founder: itne credits main nahi de sakta; AI plans 'COMING SOON' hain JULY 2027 tak, credits numbers abhi lock/propose nahi]** purani proposal: **AI credits inversion fix**: rule = *plan ka per-credit rate hamesha sab se sasta public top-up (£0.222) se kam*. Proposal: AI Pro 12,000 (£0.167), AI Business 35,000 (£0.143), AI Executive 200,000 (£0.125). **LOCK se pehle asal LLM cost per credit check zaroori** -- margin unknown.
5. **AI plan = base platform (founder 04:05 correction)**: AI Pro=Business, AI Business=Business Pro, AI Executive=**Business Pro (purani formula) -- Business Premium AI mein NAHI aata, Business Premium 'human' (workspace) package hai**.
6. **Bandwidth overage**: Business 10TB@£12, Business Pro 30TB@£11, Business Premium 50TB@£10 -- APPROVED. Basic/Pro fair-use throttle.
7. Annual rule AI: monthly x10 (2 months free) -- plans.ts ke locked rule se match.

## B. Mistakes jo repo mein mili (read-only audit, 26 Oct 04:00)
- `src/lib/plans.ts`: purani per-user qeematein/unit (£23/£46/£97 per user), line ~135 "15GB transfer per user / month" -- v6 flat-per-month ke khilaf.
- `src/lib/ai-packages.ts`: £400/£1,500/£4,000 + text "1,200 credits on the £400 plan" -- stale.
- `docs/cursor-work/PACKAGE-FEATURE-FORMULA.md` purane tables (storage 5/10/25GB etc.), `docs/ai-packages.md` section 1-2 -- HISTORY note laga diya, tables abhi stale.
- `src/lib/personal-tiers.ts` Personal £17/£83/£1,850 **per user/month** -- Personal axis hai (account=ek insaan) isliye per-user theek, lekin founder confirm kare "no per-user" Personal par lagu nahi.
- **Landing/routes abhi PADHE NAHI** (audit baqi): `src/routes/index.tsx, plans.tsx, pages.tsx, docs.tsx, anexochat.tsx, ai.tsx, app.storage.tsx`, `FeatureGate.tsx`, `plan-surface.ts`, `billing-platform.ts`, `revenue.ts` -- per-user wording, purani qeematein, Business Premium missing.

## C. Phases (har phase "ab likho" par; pehle docs, phir code, har technology ki alag deploy command)
- P0 Audit complete (landing+routes+plan-surface, feature inventory) -- read-only.
- P1 Feature-gate matrix founder approve -> `PACKAGE-FEATURE-FORMULA.md` rewrite (5 business + 3 personal + 3 AI).
- P2 Web: `plans.ts`, `ai-packages.ts`, landing/plans/ai pages -- v6 flat pricing, Business Premium card, per-user wording hatana, 3 claims copy. (pull.sh)
- P3 Polar: naye products/prices (Business Premium, AI new prices, overage meter) -- founder khud.
- P4 SQL: `resolve_plan` + enterprise, shared storage pool, user caps, overage ledger (sql-run.sh).
- P5 plan-surface.ts gates (CRDT Business+, ANEXOChat Business+/Personal PRO+) + server enforcement (rust-engine-install.sh).
- P6 Overage billing (usage -> bill line-item, hidden from landing).
- P7 Capacity: admission control, signup pause gate, SMTP rate limits, Hetzner port-25 verify, k6 load test.
- P8 Founding-member + waves go-live.

## D. Bandwidth: throttle-first + live meter (founder 28 Oct 2026 08:37) — USER-SIDE blueprint, docs only, nothing built (Rule 5)
Rates were already APPROVED above (A.6; PRICING-POSITIONING-26OCT §9b): Business 10TB@£12, Business Pro 30TB@£11, Business Premium 50TB@£10, Basic/Pro fair-use (throttle, no bill). Full competitor check (Google/Microsoft/Zoho limits read from their own pages, what is NOT verified) + the four promises: `docs/cursor-work/PACKAGE-FEATURE-FORMULA.md` section "Bandwidth: competitor check + honest-bandwidth promise".
Where it is built (user side, NOT the founder phases):
| Step | Phase | Technology |
|---|---|---|
| 1. Meter (real GB per org per month, inbound never blocked) | P4 (SQL overage ledger) + P5 (Rust counters) | SQL (RLS on) + Rust :3200 (Tokio), WebTransport/kernel unchanged |
| 2. Throttle-first (slower, never stop sending; restore at once when overage is on) | P5 | Rust (rate limiter per org); no Bun |
| 3. Live meter (80% / 95% warning, real GB in billing) | P6 | SPA billing page via `rpc()`; Rust proc |
| 4. Overage billing line-item (hidden from landing) | P6 | Rust -> Polar (founder creates the Polar products, P3); webhook untouched |
| 5. Business Premium written fair-use ceiling (CEO guess 100 TB/month) | P4 | founder confirms the number first |
Order is fixed: meter first, then throttle, then the rate on the bill.
