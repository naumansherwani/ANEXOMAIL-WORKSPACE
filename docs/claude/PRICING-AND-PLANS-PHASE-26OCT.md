# PRICING & PLANS PHASE (alag phase, founder 26 Oct 04:05 PKT -- AAJ ka kaam)

Founder: "package plans update karna hai aur polar main update karna hai aur price se related jitni baatein hain un ka ek alag phase bana lo. polar main prices main update karun ga. packages plan jahan jahan hon woh update hon, enterprise new card aaye aur uska sab bane."

## Zimmedari
- **Founder**: Polar mein prices/products khud (Enterprise £18,500; AI £2,000/£5,000/£25,000 -- AI abhi COMING SOON, July 2027 tak live nahi; overage meter).
- **CEO/Claude**: repo -- plans/cards/landing/gates/docs. Code sirf founder ke "ab likho" par, har technology ki alag deploy command.

## Qaida (STRICT): pehle puri website ka feature inventory, phir gate
Jab tak puri website (landing + routes + app) ke features ki list nahi, package ko kya milega yeh final nahi. Is liye tarteeb:
1. **PP0** read-only inventory: har route/feature (src/routes/*, plan-surface.ts, FeatureGate.tsx) -> ek list.
2. **PP1** feature -> package matrix (Basic/Pro/Business/Business Pro/Enterprise + Personal Basic/PRO+/Premium) -> founder approve -> `PACKAGE-FEATURE-FORMULA.md` (yeh REPO MEIN har package ka gate ka rule hai; naya feature = pehle is file mein gate likho).
3. **PP2** `plans.ts` v6 (flat per-month, user caps, shared storage), Enterprise card (features PP1 se), per-user wording hatana.
4. **PP3** landing/plans/pages/docs/anexochat routes ki qeematein+copy sync (3 claims, competitor claim nahi).
5. **PP4** AI pages/`ai-packages.ts`: nayi qeematein + 'Coming soon (July 2027)' badge, credits numbers placeholder.
6. **PP5** Polar IDs/env mapping founder ke update ke baad (polar.ts/ no-touch rule, sirf product-id env).
7. **PP6** SQL resolve_plan enterprise, shared pool, user caps, overage ledger; **PP7** server enforcement (Rust) + plan-surface gates.
8. Har step: tier-guard.test + manifest 0 bad + deploy commands per technology.

## Technology rule (founder dohraya)
Latest tech (Rust/Tokio/WebTransport) + **WASM KERNEL browser mein builtin, poori website ke liye common -- ANEXOChat, har subdomain (ai., chat, founder) sab** -- AGENTS.md Rule 52 + Rule 53.

## Founding-member -- aasan alfaaz
Pehle 150 companies ko hum wada dete hain: "aaj jo monthly price hai, woh 2 saal (24 mahine) tak nahi barhe gi, chahe baad mein hum sab ke liye price barha dein." 24 mahine ke baad normal price lagti hai. 'Lifetime' (hamesha) wada isliye nahi kiya ke kal Hetzner/costs barh jayen to hum phans jate hain. Badle mein unhein 'Founding' badge milta hai aur hamare pehle gawah (testimonial) ban jate hain.
