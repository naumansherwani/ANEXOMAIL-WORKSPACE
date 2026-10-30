# Founder Settings Center — port of the user Settings Center (28 Oct 2026, 11:50 PKT)

Founder 11:38: "User ko jo milta hai (Settings Center: Personal, Workspace, Appearance, Notifications, Privacy, AI, Time machine, Drift & schedule) us mein se jo mujhe dena hai woh LATEST technology par, founder protocol ke saath (endpoint + gates). Kab? Tarteeb mein likho." Decision 11:24: tarteeb same; **Settings page F2a ke saath** banegi.

## Rule of the port (FC18 / FC20 / FC22)
- Same feature set the user has, but: separate folder (`founder-web/src/Settings*.jsx`, `server/founder/src/settings.rs`), separate table, separate endpoints under `/founder/v1/settings/*`. The user app files are NOT edited and share no gates (FC1, Rule 35).
- Latest tech: Rust (axum/tokio) endpoints, SQL RPC with immutable history, React 19 `useActionState`/optimistic UI, signed envelope (HMAC now, Ed25519 in F2a, verified by the WASM kernel in F2b).
- Every write = `founder_audit` row (hash chain). Nothing mocked (FC26): a setting with no stored value shows its default and says "default".

## The user's tabs, one by one — what the founder gets, when
| User tab / feature | Founder version | Gate | Slot |
|---|---|---|---|
| Personal: Display name | Name on profile + greeting (profile photo already DONE, 28 Oct) | G1w* | **S1** (F2a) |
| Personal: Home city | City override for greeting/clock (default = device city, already DONE) | G1w* | **S1** |
| Personal: Undo send window, Send confidence check | Mail features -> Mail Desk | G2 | F5 |
| Workspace | Company defaults (name, domains, support address) | G2 | S2 (F6 Systems) |
| Appearance | Graphics on/off (DONE, browser-local), theme, density, motion, sidebar default; saved per founder, synced across approved devices | G1w* | **S1** |
| Notifications | Which alerts reach you and where: payment failed, unusual login, rejected webhook spike, Decide queue | G2 (external channel) | **S1** |
| Privacy | Session lifetime, device-approval strictness, audit visibility, export | G2 / G3 (export) | **S1** (G3 part after passkey proof) |
| AI settings | Leo/AI limits for the founder surface | G2 | S2 (F6 AI) |
| Time machine | Version history + one-click revert of any founder setting | G1 read / G2 revert | **S2 (after F2c: needs audit Merkle)** |
| Drift & schedule | Setting drift vs safe baseline, scheduled changes with auto-rollback | G1 / G2 | S2 |
| Per-setting "Explain / Blast radius / History" | Same trio on every founder setting | G1 | S2 (History after F2c) |
\* **G1w** = founder token + approved device + audit row, no reason box (low-risk own-profile/cosmetic values, same as the profile photo). Anything that can leak data, widen access or reach outside = G2 (two-tap + reason), money/export/impersonation = G3 (passkey). The danger level of a setting can only go UP (E103 ratchet).

## Endpoints (founder protocol only)
| Endpoint | Gate | Slot |
|---|---|---|
| `GET /founder/v1/settings/:scope` (personal, appearance, notifications, privacy) | G1 | S1 |
| `PUT /founder/v1/settings/:key` (G1w keys) | G1w + audit | S1 |
| `POST /founder/v1/action settings.save` (G2 keys) | G2 | S1 |
| `GET /founder/v1/settings/explain?key=` , `GET .../blast-radius?key=` | G1 | S2 |
| `GET /founder/v1/settings/history` , `POST /founder/v1/action settings.revert` | G1 / G2 | S2 (after F2c) |
| `GET /founder/v1/settings/drift` , `GET/POST .../scheduled` | G1 / G2 | S2 |
SQL: **E108_founder_settings.sql** (+ CHECK_E108): `founder_settings` (registry + value per founder), `founder_settings_history` append-only with trigger guard, RPC `founder_setting_set` (validates kind/range, writes history + `founder_audit_append` in one transaction, advisory lock), selftest in a rolled-back subtransaction (E104 standard, FC27).

## Order (this is the order; nothing else jumps ahead)
0. Server pending (E106 check, install, pull.sh, hostguard probe/login/enforce) — founder pastes outputs.
1. **F2a** Ed25519 + request HMAC/HKDF **+ Settings S1** (E108, `settings.rs`, SPA Settings Center: Personal, Appearance, Notifications, Privacy).
2. F2b WASM kernel verify (enforce + SRI).
3. F2c audit v1 + Merkle (E107).
4. **Settings S2**: Time machine, Drift & schedule, Explain/Blast radius (needs F2c chain).
5. Decide (N) button, Live Pulse.
6. F3-b Polar failed payments/churn, F4 People, F5 Mail Desk (+ undo-send/confidence settings), F6 Systems/AI (+ Workspace/AI settings), F8 Control, F9 cutover.
7. Founder desk (Docs/Sheets).

## What is already DONE from the user's feature set, in founder form (28 Oct)
Greeting (day-part, sunset evening, Karachi/city-adaptive), digital clock, cinematic glass sidebar with awam order + collapse, Account menu with profile photo (Facebook-style upload, shrink in browser, audit), graphics toggle + ambient edge, device approval, Polar billing pulse (webhook + metrics), finance/people/mail/systems/control decks (catalog, read parts as they ship), real logo.

## UPDATE 28 Oct 12:50 PKT — S1 BUILT (sandbox-proven, not yet on server) — and what changed vs. the table above (Rule 69: only REAL controls)
- **SQL E108_founder_settings.sql (+CHECK_E108, 6 checks):** `founder_settings` + append-only `founder_settings_history`, RPC `founder_setting_set` (validate, history, audit in one transaction) and `founder_settings_get`. Separate from the user app's `account_profiles` (found live: the founder account has NO profile row there, so the user-side photo could never save — founder settings are now independent, FC18).
- **Rust:** `settings.rs` registry (+12 tests), `GET /founder/v1/settings`, `PUT /founder/v1/settings {key,value}` (signed write, F2a). The old `/founder/v1/profile*` endpoints are gone.
- **SPA:** Settings -> Personal (home timezone: greeting/clock follow it) and Appearance (Graphics, Compact sidebar), both saved on the account and synced to every approved device; Profile page: photo + display name.
- **Real keys now:** personal.display_name, personal.avatar, personal.timezone, appearance.graphics, appearance.sidebar_slim.
- **NOT built, on purpose (no working-looking fakes):** Notifications — there is no delivery channel yet (comes with Mail Desk F5 / push). Privacy (session lifetime, approval strictness) — needs passkey/session controls after F2b. The Settings page says so in one honest line.

## ORDER of the three deferred Settings tabs (founder 28 Oct 12:08: "yeh teeno kab aayenge, tarteeb mein add karo")
Rule 69: a tab appears only when its backend is real. Each one is tied to the phase that creates that backend:
| # | Tab | Why it waits | Built in | After |
|---|---|---|---|---|
| 1 | **Time machine + Drift & schedule** (history, one-click revert, drift vs baseline, scheduled changes) | needs the audit chain with Merkle proof (F2c); history table already records every change since E108 | **Settings S2** | F2c |
| 2 | **Privacy** (session length, device-approval strictness, passkey-required for G3, export) | needs real passkey assertion for G3 (F2d, planned right after F2c; removes FOUNDER_PASSWORD only after proof) | **Settings S3** | F2d passkey |
| 3 | **Notifications** (which alerts, where) | needs a real delivery channel: browser push first (service worker + Rust web-push), email via Mail Desk (F5); the alert SOURCES are Decide (N) and Live Pulse | **Settings S4** = N1 push with Decide/Live Pulse; N2 email with F5 | Decide + Live Pulse (push); F5 (email) |
Full order: F2a (done) -> Settings S1 (built) -> F2b -> F2c -> **S2 Time machine/Drift** -> F2d passkey -> **S3 Privacy** -> Decide (N) + Live Pulse -> **S4 Notifications (push)** -> F3-b Polar -> F4 People -> F5 Mail Desk (+ email notifications, undo-send settings) -> F6 Systems/AI (+ Workspace/AI settings) -> F8 Control -> F9 cutover -> Founder desk.

## 30 Oct 20:30 PKT — founder: "meri settings same to same user wali cheezein honi chaiye"
Founder Settings ab user app ke jaise 8 tabs, wohi tarteeb, dikhate hain (src/routes/app.settings.tsx ki list): **Personal (LIVE), Workspace, Appearance (LIVE), Notifications, Privacy, AI settings, Time machine, Drift & schedule**. Jo tab abhi live nahi, Settings ki side list mein "COMING, IN ORDER" mein hai aur har ek ke saath wo phase likha hai jo uska asli backend banata hai (Rule 69: koi nakli control nahi).
| Tab | Status | Phase |
|---|---|---|
| Personal | LIVE | S1 |
| Workspace | coming | F6 Systems |
| Appearance | LIVE | S1 |
| Notifications | coming | S4 (Decide + Live Pulse push; email F5) |
| Privacy | coming | S3 (passkey F2d ke baad) |
| AI settings | coming | F6 AI deck |
| Time machine | coming | S2 (F2c Merkle ke baad) |
| Drift & schedule | coming | S2 (F2c ke baad) |
Har tab apne phase mein user wale ke barabar feature set ke saath latest technology par (Rust endpoint + signed envelope + kernel verify + audit row) banega.
