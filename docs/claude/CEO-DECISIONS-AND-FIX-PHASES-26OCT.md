# CEO decisions + mistake-fix phases (26 Oct 2026 04:00 PKT) — docs-only, koi code nahi

Founder ne sab faisle CEO ko delegate kiye ("tum ceo sab faislay kero jo zoho aur google ki buildings main hulchul paida karay"). Veto hamesha founder ka.

## A. CEO faisle
1. **Founding-member**: pehle **150 orgs**, price **24 mahine lock** (monthly price badle to bhi), "Founding" badge. Lifetime lock nahi (cost badle to phasna nahi).
2. **Waves**: pehle 4 hafte **25 orgs/hafta** (=100), phir **50/hafta**, aur server utilisation >70% par auto-pause. Signup kholna sirf Pro+Business+Business Pro GREEN + M3 ke baad.
3. **Move-In**: har trial ko **free pilot migration (3 mailboxes tak)**; full Move-In free **annual Business Pro/Enterprise** ko; baqi ko listed one-off **£568-3,350 -- PRICES INTACT (founder 04:05: price wahi rahe ga)**.
4. **[SUPERSEDED 04:05 -- founder: itne credits main nahi de sakta; AI plans 'COMING SOON' hain JULY 2027 tak, credits numbers abhi lock/propose nahi]** purani proposal: **AI credits inversion fix**: rule = *plan ka per-credit rate hamesha sab se sasta public top-up (£0.222) se kam*. Proposal: AI Pro 12,000 (£0.167), AI Business 35,000 (£0.143), AI Executive 200,000 (£0.125). **LOCK se pehle asal LLM cost per credit check zaroori** -- margin unknown.
5. **AI plan = base platform (founder 04:05 correction)**: AI Pro=Business, AI Business=Business Pro, AI Executive=**Business Pro (purani formula) -- Enterprise AI mein NAHI aata, Enterprise 'human' (workspace) package hai**.
6. **Bandwidth overage**: Business 10TB@£12, Business Pro 30TB@£11, Enterprise 50TB@£10 -- APPROVED. Basic/Pro fair-use throttle.
7. Annual rule AI: monthly x10 (2 months free) -- plans.ts ke locked rule se match.

## B. Mistakes jo repo mein mili (read-only audit, 26 Oct 04:00)
- `src/lib/plans.ts`: purani per-user qeematein/unit (£23/£46/£97 per user), line ~135 "15GB transfer per user / month" -- v6 flat-per-month ke khilaf.
- `src/lib/ai-packages.ts`: £400/£1,500/£4,000 + text "1,200 credits on the £400 plan" -- stale.
- `docs/cursor-work/PACKAGE-FEATURE-FORMULA.md` purane tables (storage 5/10/25GB etc.), `docs/ai-packages.md` section 1-2 -- HISTORY note laga diya, tables abhi stale.
- `src/lib/personal-tiers.ts` Personal £17/£83/£1,850 **per user/month** -- Personal axis hai (account=ek insaan) isliye per-user theek, lekin founder confirm kare "no per-user" Personal par lagu nahi.
- **Landing/routes abhi PADHE NAHI** (audit baqi): `src/routes/index.tsx, plans.tsx, pages.tsx, docs.tsx, anexochat.tsx, ai.tsx, app.storage.tsx`, `FeatureGate.tsx`, `plan-surface.ts`, `billing-platform.ts`, `revenue.ts` -- per-user wording, purani qeematein, Enterprise missing.

## C. Phases (har phase "ab likho" par; pehle docs, phir code, har technology ki alag deploy command)
- P0 Audit complete (landing+routes+plan-surface, feature inventory) -- read-only.
- P1 Feature-gate matrix founder approve -> `PACKAGE-FEATURE-FORMULA.md` rewrite (5 business + 3 personal + 3 AI).
- P2 Web: `plans.ts`, `ai-packages.ts`, landing/plans/ai pages -- v6 flat pricing, Enterprise card, per-user wording hatana, 3 claims copy. (pull.sh)
- P3 Polar: naye products/prices (Enterprise, AI new prices, overage meter) -- founder khud.
- P4 SQL: `resolve_plan` + enterprise, shared storage pool, user caps, overage ledger (sql-run.sh).
- P5 plan-surface.ts gates (CRDT Business+, ANEXOChat Business+/Personal PRO+) + server enforcement (rust-engine-install.sh).
- P6 Overage billing (usage -> bill line-item, hidden from landing).
- P7 Capacity: admission control, signup pause gate, SMTP rate limits, Hetzner port-25 verify, k6 load test.
- P8 Founding-member + waves go-live.

## D. Bandwidth: throttle-first + live meter (founder 28 Oct 2026 08:37) — USER-SIDE blueprint, docs only, nothing built (Rule 5)
Rates were already APPROVED above (A.6; PRICING-POSITIONING-26OCT §9b): Business 10TB@£12, Business Pro 30TB@£11, Enterprise 50TB@£10, Basic/Pro fair-use (throttle, no bill). Full competitor check (Google/Microsoft/Zoho limits read from their own pages, what is NOT verified) + the four promises: `docs/cursor-work/PACKAGE-FEATURE-FORMULA.md` section "Bandwidth: competitor check + honest-bandwidth promise".
Where it is built (user side, NOT the founder phases):
| Step | Phase | Technology |
|---|---|---|
| 1. Meter (real GB per org per month, inbound never blocked) | P4 | SQL (overage ledger, RLS on) + Rust :3200 counters (Tokio), WebTransport/kernel unchanged |
| 2. Throttle-first (slower, never stop sending; restore at once when overage is on) | P4 | Rust (rate limiter per org); no Bun |
| 3. Live meter (80% / 95% warning, real GB in billing) | P5/P6 | SPA billing page via `rpc()`; Rust proc |
| 4. Overage billing line-item (hidden from landing) | P6 | Rust -> Polar (founder creates the Polar products, P3); webhook untouched |
| 5. Enterprise written fair-use ceiling (CEO guess 100 TB/month) | P4 | founder confirms the number first |
Order is fixed: meter first, then throttle, then the rate on the bill.
