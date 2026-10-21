# ANEXOMAIL — BLUEPRINT (EK hi)

**Yeh woh ek file hai.** Baqi blueprint/plan files iski *detail* hain — unka status yahan se parho, wahan se nahi.
Founder: Muhammad Nauman Sherwani · bani: 21 Oct 2026 · halat ka asli saboot: `docs/cursor-work/GREEN-BOARD/` (README ginti + NOT-GREEN/).
Qaida: is file mein sirf **sach** hai (live ya repo mein saabit). Naya faisla → yahan ek line + detail wali file mein; purani file delete nahi hoti, sirf is par point karti hai.

---

## 1. Kya hai (identity + teen surface)
- **Product:** ANEXOMAIL Workspace — AI-native email workspace (Google Workspace / Zoho Mail ka replacement). Cinematic, mobile-pehle.
- **Ek codebase, teen surface** (`src/lib/host.ts`): `anexomail.com` awam (Mail + Chat + People + Calendar + Work) · `ai.anexomail.com` (LEO AI) · `founderworkspace.anexomail.com` (sirf Nauman, "Founder View").
- **Account kinds:** Personal, Business, **Family (asli buyer jaisa — E41)**. Technology plan se nahi, **org-membership se** chalti hai (family + future accounts apne aap).
- Detail: `docs/anexomail-blueprint.md` (identity, design system, host map, phases, G29–G42), `docs/ai-parallel-build.md`.

## 2. Packages (price/features ka sach)
- Source of truth: `src/lib/plans.ts` + `src/lib/ai-packages.ts` (UI sirf yahan se). Detail docs: `docs/ai-packages.md`, `docs/package-feature-map.md`, `docs/polar-products.md`.
- Basic £23 · Pro £46 · Business £97 · Business Pro £2,850/company (yearly: Basic/Pro 1 mahina free, Business/BP 2 mahine free). **Polar payments, prices, landing = NO TOUCH.**
- Rule 37: package-wise alag edit nahi; farq sirf `src/lib/plan-surface.ts` capability se. Plan card ka har wada asli product se milna chahiye.

## 3. Technology (sach, 21 Oct)
| Layer | Kya | Halat |
|---|---|---|
| Web | React 19 + TanStack Start + Vite 8 + Tailwind 4, Bun SSR :3000, Caddy | live |
| **Rust :3200 PRIMARY** | tokio 1.53.3, axum 0.8.9, wtransport 0.7.2 (QUIC/quinn), `/rpc/*` tRPC-style | **live (poori website)** |
| Bun Brain :3100 | fallback + abhi 38 route files / ~504 endpoints | B8 mein Rust par |
| Data | Supabase/PostgreSQL = truth; SQL sirf `sql-run.sh` se | live |
| Mail | Postfix/Dovecot/OpenDKIM; inbound anexopipe -> Rust; outbound Rust SMTP + queue worker | live |
| Realtime | B4 event hub (per-org broadcast, publish layer, reconcile) over WebTransport | **GREEN 21 Oct 06:50** |
| Payments | Polar Rust :3400 | **NO TOUCH** |
Detail: `docs/cursor-work/TECH-MAP.md`.

## 4. Migration (B-series) — founder tarteeb
B1 JWT/refresh ✅ · B2/B2b passkey-recovery Rust ✅ · B3 mail.send/undo/queue ✅ · **B4 event-driven push ✅** · B5 G40 (19 Bun-only founder routes) · B6 G16 self-serve billing · B7 G26/G27 calendar (iMIP, recurrence, scheduling link, CalDAV) · B8 Brain->Rust + Bun 1.4.3 + tokio 1.54. **Testing sab ke baad (end par); pehle poori website secure.** Phir packages: Basic ✅ -> Pro -> Business -> Business Pro (1440/820/390).

## 5. Security
- Founder original: `docs/anexomail-security-blueprint.md` (**DO NOT MODIFY**, S1–S10 jab founder bole).
- Live: JWT local verify + real revocation, passkey lazmi (27 Oct deadline; test accounts exempt), device HMAC, integrity gate (warn/block/72h export/purge), attachments + clamd, tenant isolation (CRM), 4-gate rules in `AGENTS.md`.
- Khule: A5 `FOUNDER_PASSWORD` plain compare; G21/G22 authz audit; MTA-STS/TLSA (founder).

## 6. Product modules (halat ka khulasa)
Mail ✅ Basic live · Compose/Undo/Schedule ✅ · Attachments (inbound ✅, outbound live test baqi) · Calendar ✅ (create/drag) · Contacts/People code live · Work/CRM code (Brain isolation live) · Founder View code (founder-login live test baqi) · AI/LEO code (AI account live test baqi) · ANEXOChat (audit baqi). Har item ka status: `GREEN-BOARD/02` aur `03`.

## 7. Kaam ke qaide
Rule 30 (jo ho chuka dobara nahi) · Rule 35 (Rust live sirf surgical script) · Rule 37 (universal UI) · pull commands poori copy-paste · memory repo + sandbox har step · Chrome sirf NAYE tab mein.

## 8. Document map (kaun si file kya hai)
| File | Role |
|---|---|
| **docs/BLUEPRINT.md** | **EK blueprint (yeh)** |
| docs/cursor-work/GREEN-BOARD/ | green / not-green ka asli board (status yahan) |
| docs/cursor-work/MASTER-GAP-LEDGER.md | gap hisaab (A–F) |
| docs/cursor-work/DONE-DO-NOT-REPEAT.md | jo ho chuka |
| docs/cursor-work/TECH-MAP.md | technology detail |
| docs/anexomail-blueprint.md | detail/append-only history (G29–G42 etc.) |
| docs/MASTER-BUILD-PLAN.md | P1–P9 build plan + B-series board (P-status purana) |
| docs/anexomail-security-blueprint.md | founder original security |
| docs/ai-packages.md, package-feature-map.md, polar-*.md | packages/payments detail |
| docs/wire/*, IMPLEMENTATION-MASTER.md, BLUEPRINT-SUPERSEDE-PLAN.md | PURANA (Sep) — history, status ke liye mat parho |
