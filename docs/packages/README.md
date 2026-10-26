# docs/packages — HAR PACKAGE KA ALAG FOLDER (founder hukm, mix nahi hoga)

Ek package = ek folder. Ek folder ki baat doosre mein NAHI likhi jaati.

| Folder | Package | Qeemat (flat, per month) | Users cap | Status |
|---|---|---|---|---|
| basic/ | Basic | £40 (yearly £440) | 5 | APPROVED + code v6 (E87) |
| pro/ | Pro | £105 (yearly £1,155) | 20 | DRAFT — founder approve baqi, E88 likha |
| business/ | Business | £360 | 60 | agla |
| business-pro/ | Business Pro | £2,850 | 570 | uske baad |
| enterprise/ | Enterprise | £18,000 | unlimited | alag phase, abhi ZERO |
| personal/ | Personal | HOLD | 1 | founder ki alag meeting |

Har package folder mein 3 file:
1. `FEATURES.md` — founder-approved features (landing card ka sach).
2. `GATES-AND-TECH.md` — har feature: haalat (REAL / SIRF-SCREEN / NAHI-BANA), gate kahan, technology, file.
3. `NOT-BUILT.md` — jo bana nahi + latest technology par kaise banega.

Technology qaida (founder: "technology GOD ke baad hai"): Rust engine (axum/tokio/wtransport :3200), WebTransport live, WASM kernel builtin, Postgres SECURITY DEFINER functions (server-side gate — UI gate kabhi akela nahi). Naya gate hamesha server par; screen par chhupana kaafi nahi.
Source of truth cross-ref: `docs/cursor-work/PACKAGE-FEATURE-FORMULA.md` (Rule 53), `docs/claude/PP1-FULL-GATE-TABLE-26OCT.md`.
