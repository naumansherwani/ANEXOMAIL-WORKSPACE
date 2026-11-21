# HOW EMPLOYEES GET ADMIN DESK ACCOUNTS (his 22 Nov 2026 01:13 PKT: "employees ko access kaise dun ga, duniya ki advance research, plan")
Fits SCALE-50K-DESIGN (S1 org, S2 relations, S4 SCIM, S5 passkeys) and WORLD-ADVANCE (W5 ZSP, W7 own keys). All in-house Rust + Postgres; no IdP vendor. Today only the owner exists; nothing below is built.

## Research findings
- Day-one risk: passwordless programmes still start with a temporary password/code. Fix = a tightly scoped ENROLLMENT TOKEN: few issuers, short life, one-time, not left in an inbox, passkey registered immediately.
- Synced passkeys are risky at work: corporate credential can sit in a personal iCloud/Google account the company cannot revoke; attackers also abuse help-desk recovery and downgrade to weaker methods ("weakest method defines real security"). Fix = device-bound hardware-backed keys, record attestation at registration, NO fallback methods, recovery only through high-assurance path.
- Device-bound makes device LOSS the hard problem: a recovery flow must be designed (who approves a new passkey).
- SCIM 2.0 (RFC 7642/7643/7644) is the standard way to create/update/disable accounts in bulk.

## Lifecycle (joiner / mover / leaver)
1. JOINER. A lead or admin with the right relation creates the staff record (name, work email, team, role relation) = status invited. Admin-level roles need a second person's approval (W5).
2. ENROLLMENT TOKEN. System shows a one-time code on the ISSUER's Desk screen (not emailed): 10-minute life, single use, bound to that staff record, stored only as an Argon2id hash. Issuer hands it over in person/phone call.
3. FIRST LOGIN at /enroll: code entered, then the new hire MUST register a passkey right then. No password ever exists for staff.
4. KEY POLICY (checked in Rust at registration): device-bound only (reject credentials whose authenticator data says backup-eligible/synced), store attestation + model, require 2 devices (laptop + phone or hardware key) so one loss is no lockout, reject unverifiable authenticators, no SMS/OTP/password fallback anywhere. Each staff gets own Rule 52 signing key and DBSC session.
5. MOVER. Team change = relation tuples change in one transaction; old access gone at the next check (consistency token); supervisor sign-off for higher roles; every change in the ledger.
6. LEAVER. One transaction: disable staff, kill sessions, revoke device keys + Rule 52 key, delete relations, reassign open cases through the queue, ledger line. Takes effect in under a second, no orphan access.
7. RECOVERY (lost both devices): no help-desk reset. Needs 2 supervisors' approval + enrollment token on a new device + cooling period (default 24 h) with alert to the staff member's other channels and the team; ledgered. Owner break-glass stays loud.
8. ACCESS REVIEW: every 90 days each lead attests their team's access; unattested access expires automatically (W5).
9. BULK at scale: own SCIM 2.0 endpoint (Users, Groups, Bulk) so 1,000s join/leave at once from an HR source; SCIM never carries credentials, enrollment still per person.

## Phases (each needs his haan; order after R3d + dashboard)
| Sub | Feature | Technology |
|---|---|---|
| ON1 | SQL: fadm_staff, fadm_enroll_token, fadm_device (credential id, BE flag, attestation), fadm_recovery; team key on every row (S8 rule) | Postgres, RLS, ledger |
| ON2 | Enrollment token issue + /enroll door + passkey registration with the key policy | Rust, webauthn-rs, Argon2id |
| ON3 | Own key + DBSC per staff, Rule 52 per staff | Ed25519, WASM kernel |
| ON4 | Mover/leaver transactions + instant revoke | Postgres, Rust |
| ON5 | Recovery flow (2 approvers + cooling) | Rust, ledger |
| ON6 | 90-day access review | Rust scheduler |
| ON7 | SCIM 2.0 endpoint | Rust, RFC 7644 |
| ON8 | Proof: my live Chrome look 390/820/1200+ with a real test staff, then offboard test | Playwright, Chrome |
## Questions for him (one word each)
1) Staff passkeys device-bound only + 2 devices: haan? 2) Recovery = 2 supervisors + 24 h cooling: haan? 3) Enrollment code handed over by the lead (not emailed): haan? 4) First hires: which team names first?
## Sources
- Day-one onboarding risk: https://nhimg.org/articles/passwordless-user-onboarding-still-hides-a-day-one-password-risk/
- Synced passkey attacks: https://thehackernews.com/2025/10/how-attackers-bypass-synced-passkeys.html
- Passkeys in enterprise: https://workos.com/blog/passkeys-consumer-advice-breaks-in-enterprise
- SCIM overview RFC 7642: https://datatracker.ietf.org/doc/rfc7642

## HIS ANSWERS (22 Nov 2026 01:25 PKT) and the final phase list (one line each)
DECIDED: (1) staff passkeys device-bound only, 2 devices = HAAN. (2) recovery = 2 supervisors + 24 h cooling = HAAN. (3) enrollment code handed over by the lead, never emailed = HAAN. (4) first hiring teams: support (live support + ticket resolution), migration (Move Your Business + onboarding, G30, DNS/DKIM), frontend_demo (UI/frontend editing + tech demos; EVERY UI change needs his approval first). His 4 extra zero-trust locks are ON9..ON12 below. New joiner starts as no_access (ON1).
ORDER (his word): R3d -> dashboard + bridge -> S1+S2 -> ON1.
| Line | Phase | Technology |
|---|---|---|
| ON1 | SQL: staff, enroll token (Argon2id hash), device (credential id, backup-eligible flag, AAGUID, attestation), recovery; joiner starts no_access; team key on every row | Postgres, RLS, hash-chained ledger |
| ON2 | Enrollment door: lead-issued one-time 10-minute code, then 2 device-bound passkeys at first login; synced (backup-eligible) credentials refused; no password ever | Rust axum, webauthn-rs, Argon2id |
| ON3 | Own Rule 52 key + DBSC session per staff | Ed25519, desk WASM kernel, DBSC |
| ON4 | Mover + leaver in one transaction, instant revoke, open cases back to the queue | Postgres, Rust |
| ON5 | Recovery: 2 supervisors + new-device code + 24 h cooling + alerts, all ledgered | Rust, ledger |
| ON6 | 90-day access review, unattested access auto-expires | Rust scheduler |
| ON7 | Own SCIM 2.0 endpoint (Users, Groups, Bulk), never carries credentials | Rust, RFC 7643/7644 |
| ON8 | Proof: my live Chrome look at 390/820/1200+ with a real test staff, then offboard test | Playwright, Chrome |
| ON9 | AAGUID hardware allow-list: only listed TPM / Secure Enclave / FIDO2 keys register; software emulators refused (see honest note) | webauthn-rs attestation, Postgres allow-list |
| ON10 | Office IP lock (lead-optional, our own CIDR list, no third-party geo vendor) + shift-hours gate (per-team window, team timezone), sessions dead outside both | Rust middleware, Postgres policy rows |
| ON11 | Anti-scraping circuit breaker: over N tickets opened or any export burst per minute (N set per team, start 50) freezes the session and raises a red alert on the Founder Bridge | Rust counters, ledger, signed alert |
| ON12 | Zero-privilege default + UI-change approval: new joiner = no_access until a queue is assigned; frontend_demo UI changes need his passkey-approved release | Relation tuples (S2), W5 approval |
HONEST NOTES (checked by research, not assumed): (a) Apple Secure Enclave passkeys normally SYNC through iCloud Keychain (backup-eligible), which conflicts with rule 1; on Apple, only a hardware security key counts as device-bound, so ON9 allow-list decides per model. (b) AAGUID is only trustworthy when the authenticator gives real attestation; platform authenticators often return none/anonymous, so ON9 starts with security keys + Windows Hello TPM and lists exactly what is accepted. (c) Geo by country needs an IP database from a vendor; we use only OUR office IP list.
