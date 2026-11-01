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

---
# 7-0 Chairman protocol (founder 1 Nov 13:00: "mujhe duniya se OTP khatam kerna hai, mobile sirf backup hai; founder protocol alag hai; chairman level tumhari nazar mein kya hona chahiye")
**Decision recorded:** the founder protocol has **no OTP and no SMS as a way in or as an approval**. Mobile is a **backup channel only**: it can warn and it can cancel; on its own it can never approve anything. (This replaces the "mobile OTP opens a recovery" idea of section 3 above; E117's recovery table keeps the 24 h cooling-off and the `mobile` channel as a *trigger that needs a second proof*, see R3.)

## A. What the strongest practice looks like today (my recommendation, for the founder to accept or change)
1. **Phishing-resistant keys only.** WebAuthn passkeys are origin-bound: a fake site cannot get an assertion. Nothing a person can read out or type (OTP, SMS, TOTP) is accepted for the founder.
2. **Two different kinds of key, at least two keys.** (a) the platform passkey of the founder's own laptop/phone, (b) a **FIDO2 hardware security key** kept physically separate (office safe). User verification required (PIN/biometric on the key). Attestation `direct` with an **AAGUID allow-list** so only genuine hardware models can be enrolled (the E117 table needs one extra column; webauthn-rs supports attestation CA lists).
3. **Action-bound signing ("what you see is what you sign").** The WebAuthn challenge is the SHA-256 of a canonical description of the action (what, target, amount, nonce, time). A grant cannot be replayed for a different action, and the ledger stores the action hash next to the assertion. E117's generic `g3` grant is the first step; the action hash is the planned E118 delta (grant carries `action_hash`; `founder_stepup_consume` must present the same hash).
4. **Tiers instead of one gate** (Rule: every action is G-gated, server enforces):
   | Tier | Examples | Proof |
   |---|---|---|
   | T0 view | dashboards, read pages | approved device + live session |
   | T1 change | settings, labels | session + passkey (user verification) at sign-in |
   | T2 dangerous | retention, require-passkey, revoke a device or passkey, new recovery codes, refunds | fresh passkey assertion bound to the action hash (5 min, single use) |
   | T3 catastrophic | kill switch, key rotation, delete data, remove the last passkey | **two different keys** (platform + hardware) on two assertions, a **10-minute delay with a cancel window**, ledger entry first |
5. **Session bound to the device (DBSC, Chrome 146 Windows)**, 15-minute idle, no bearer cookie that can be copied; **hybrid post-quantum TLS** (X25519MLKEM768) on the founder listener. Both are phase 7b; neither needs a new idea, only the library.
6. **Everything proven in the browser**: step-ups and recoveries are ledger entries, sealed by the Merkle tree and checked by the Rust WASM kernel in the Worker (already live).

## B. Recovery without OTP
- **R1 recovery codes** (10, offline, one time): E117 already; opens a ready recovery at once, ledger + alert.
- **R2 second hardware key**: the normal answer. Losing one key is not an incident because the other one signs.
- **R3 mobile backup (never alone):** a registered mobile can *start* a recovery request, which stays **pending 24 h** (E117's DB constraint), every approved device is alerted and can cancel, and it only completes together with **a recovery code or a hardware key**. The mobile never approves; it is a flare. No SMS OTP is used to *prove* identity; the number is used to *notify* (and, optionally, as a cancel channel: a reply that says STOP cancels the pending request).
- **R4 sealed share (optional, for a chairman):** a Shamir 2-of-3 split of an offline recovery secret (founder, safe, a trusted person); reconstruction is T3-style (delay + cancel). Server stores no secret.

## C. Decisions only the founder can make
1. Buy **two FIDO2 hardware keys** (one for the safe)? Without them the founder protocol cannot reach T3 honestly.
2. Enforce the **hardware-only allow-list** now, or accept platform passkeys first and tighten later?
3. T3 = two keys + 10 minute delay: accepted?
4. Does a mobile number still get registered at all (only for alerts / cancel)?

## D. Effect on the phases
7-1 (E117) stays as is and is green. New order: **7-1b E118** (tiers, action-hash binding, AAGUID column, T3 delay table) → 7-2 Rust webauthn-rs → 7-3 UI → 7-4 enforce + remove `FOUNDER_PASSWORD` → 7-5 becomes "mobile backup flare + cancel channel" (no OTP, provider needed only for notifications).
