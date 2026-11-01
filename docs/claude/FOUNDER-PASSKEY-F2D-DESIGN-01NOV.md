# Step 7 — F2d passkey (G3 step-up) + S3 Privacy: design note (1 Nov 2026, founder order 12:45 "yeh sab kaam kero shuru")
Technology (Rules 52, 61, 62, 66; founder: "technology rule ko strictly follow kerna hai"): **Rust `webauthn-rs`** on the existing axum 0.8 + tokio founder binary; **browser WebAuthn** in the React-TS SPA (Privacy tab); **SQL** on Supabase Postgres (RLS on, service_role through security-definer doors only); every answer is still Ed25519-signed by the server and verified by the **Rust WASM kernel in the Worker**. **No Bun/Node on the server, nothing awam-side touched.**

## 1. What a passkey is for here
1. **G3 step-up**: dangerous founder actions (money, kill switch, retention, "require passkey", removing a device) need a fresh passkey assertion. The server turns one assertion into a **step-up grant**: single-use, 5 minutes, bound to (founder, approved device, scope). No grant = 403, enforced in Rust and by a DB door, never by the UI.
2. **Require passkey for every sign-in** (Settings → Workspace, the key stored since S1c): once the founder has ≥2 active passkeys the token exchange also asks for an assertion. Until then the key stays a stored value and says so.
3. `FOUNDER_PASSWORD` path removed **only after** a passkey sign-in is proven in the founder's Chrome (Rule 69: green before the next).

## 2. Passkey rules (webauthn-rs)
Platform or roaming key, **user verification required**, resident key preferred, attestation `none`, RP id = the founder host. Counter / clone detection: a lower counter revokes that credential and writes a ledger entry. Max 5 passkeys, each with a label; a passkey is never deleted, only revoked (history kept). Registering or revoking a passkey is itself G3 (except the very first registration, which needs the approved device only).

## 3. Recovery (founder answer 12:45: by mobile number) — and the honest risks
Recovery = a **state machine in SQL, provider-agnostic**, so the SMS provider is a later, replaceable piece:
- **Primary break-glass: 10 one-time recovery codes** (shown once, stored only as SHA-256; this is already the line in FOUNDER-SECURITY-28OCT.md §2).
- **Mobile recovery** (the founder's request): the founder's verified mobile number receives an OTP; success opens a **recovery request** that is **not instant**: a **24-hour cooling-off**, an alert on every approved device and in the ledger, **cancellable from any approved device**, and one-time. After the cooling-off the founder can register a new passkey. Reason for the delay: SMS alone is weak (SIM-swap); the delay is what makes mobile recovery safe enough for a chairman account.
- **Open decision for the founder (needed only for phase 7-5):** which SMS provider, and the founder's mobile number (E.164). Until then no OTP is sent and nothing pretends to.

## 4. Phases (one at a time, green on the server + Chrome before the next)
| Phase | Layer | What | State |
|---|---|---|---|
| 7-1 | SQL E117 + CHECK_E117 | tables: passkeys, ceremonies, step-up grants, recovery codes, recovery requests; doors; selftests on a populated account | this commit |
| 7-2 | Rust `webauthn-rs` | register / authenticate ceremonies, step-up grant, clone detection, routes + tests | next |
| 7-3 | React-TS | Privacy tab (S3): passkey list, add, revoke, recovery codes; the step-up prompt component | after 7-2 |
| 7-4 | Rust + SQL | enforce G3 on dangerous actions; passkey for sign-in; remove `FOUNDER_PASSWORD` | after his Chrome proof of 7-3 |
| 7-5 | Rust + SQL | mobile OTP recovery with the 24 h cooling-off | after the SMS provider decision |

## 5. Awam side (separate; written, NOT built — Rule 35: founder side never mixes with awam)
See `docs/claude/AWAM-MOBILE-LOGIN-COUNTRY-REQUIREMENT-01NOV.md`.
