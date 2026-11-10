# G-MIX D2b-5 PLAN - changing the session policy needs a FRESH passkey touch (11 Nov 2026 01:50 PKT)
Founder order 11 Nov 01:36: research the advanced way BEFORE the passkey code, then code, ZERO loopholes. Plan is written first (RULE: plan at repo top). Awam gets the same later, moulded (RULE 9, line AP9b in docs/claude/AWAM-PASSKEY-ONLY-PLAN-10NOV.md; awam = own tables/SQL numbers/customer words/no 2FA, GREEN stamp blank).

## Technology (what and why)
* WebAuthn L3 assertion (passkey.rs, J3) whose CHALLENGE = SHA-256 of the exact action ("transaction confirmation": the signature covers WHAT is approved, not just WHO; same idea as W3C WebAuthn "transaction authorization", NIST 800-63B reauthentication, OWASP ASVS V3/V4 step-up for sensitive changes). Reused: founder_action_hash (E118), founder_stepup_issue, _fp_consume_action, ceremony table (single use, expiring).
* NEW: payload lives ONLY on the server. Browser calls begin {fields}; Rust validates, adds server-measured facts (sid_hash, current country), stores them in the ceremony state, returns a plain-words SUMMARY of what will be signed. Finish takes {ceremony, credential} ONLY - the browser cannot change the payload between touch and apply. The grant never leaves the server (issued and consumed in one request).
* SQL E157: action `session.policy` (tier 2) + door `founder_session_policy_apply` = set_v2 then consume in ONE transaction (consume failure rolls the change back; bad shape never burns a grant).
* UI: Policy card becomes editable (React/TS, same build 390/820/1200+), shows the summary, then the browser touch prompt.

## Loopholes closed (each has a test)
P1 replay: ceremony single use + grant single use + server nonce. P2 payload swap after touch: payload server-held, hash bound in challenge AND re-derived in SQL. P3 other session/device: sid_hash in the digest, device must match ceremony, SQL requires that sid LIVE for that user. P4 lock-out: country is server-measured (never browser), enforce refused unless current country allowed (set_v2). P5 weak key: protocol t2_hardware_only honoured (issue door). P6 generic path abuse: /passkey/options refuses any `session.*` action, only this endpoint pair builds it. P7 no reason: reason 8-200 chars, written to the ledger. P8 hammering: max 5 policy changes per hour (SQL) + open ceremony cap. P9 no-op: identical policy refused (no noise, no grant burn). P10 ordering: set first, consume second, atomic. P11 session killed between begin and finish: SQL live check. P12 DB down: 503, nothing changes. P13 stale cache: session cache cleared after a change. P14 body can never choose uid/device (token only).
Honest limits: a VPN inside an allowed country passes; passkey touch proves possession of the key, not intent of the person holding it.

## Order of work
1 this plan + awam AP9b (done) -> 2 SQL E157 + CHECK_E157 (local PG) -> 3 Rust begin/finish + tests -> 4 UI editable card + tests + 390/820/1280 -> 5 records, push, ONE install line -> 6 D4 his live proof.
## Next phases research (for the record)
L (Thu 12 Nov) cinematic motion: Framer Motion + GSAP, Three.js WebGPU lazy, prefers-reduced-motion honoured (WCAG 2.3.3), 60fps budget, same build on all sizes. After L: M..V,X per FOUNDER-RED-ZONE-PLAN-10NOV.md. Every D-series file (E155-E157, sessions.rs, sessions_pure.ts, Devices.tsx) is PRESERVED for awam: moulded later (awam tables awam_session_*, customer wording, no 2FA).
## Status
PLAN WRITTEN 01:50. CODE WRITTEN 02:10: E157 (+CHECK, local selftest PASS), policy_step.rs (291 Rust tests), PolicyEditor/policy_change/policy_flow (176 bun tests, 390/820/1280 sandbox clean). Waits: his sql-run + founder-install + a real key-touched change (D4). GREEN: NO.
