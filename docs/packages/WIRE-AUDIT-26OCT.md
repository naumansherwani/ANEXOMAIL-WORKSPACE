# WIRE AUDIT — 26 Oct 2026 (mechanical: `python3 scripts/wire-audit.py`)
Frontend ki har `/api/*` call (477 paths) ke liye server par handler dhoondta hai (Bun route, Rust route, ya Rust/Bun proc jiska REST sirf fallback hai).

| Natija | Ginti | Matlab |
|---|---|---|
| Handler maujood | 458 | wired |
| REST fallback only (Rust proc maujood) | 6 | Rust primary; REST sirf fallback |
| HELD | 13 | `/api/ai/billing/*`, `/api/knowledge/*` — AI plans COMING SOON (July 2027), jaan-boojh ke nahi bane |
| REAL GAP | 0 | script exit 0 |

Is round mein wire kiye: analytics x7 + founder overview (Rust `analytics_glue`, Bun fallback), `billing.revenueTruth` (SQL E90 `founder_revenue_truth`, Rust + Bun `/api/founder/billing/revenue`), MFA enroll/confirm/verify/disable + magic-link verify (`server/routes/auth.ts`), meeting cost (Rust), kernel.ticket / kernel.report (E90).
Qaida: koi naya frontend call bina server handler ke merge nahi hota — script CI/pre-commit mein chalao.
