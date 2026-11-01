# Founder Settings Center — decision, tab by tab (1 Nov 2026 10:20 PKT)

**Founder order 1 Nov 10:13 (verbatim gist):** "mainay awam side ka business account login kiya hai, settings center mein dekho ke kaise yeh tarteeb hai; mujhe yehi founder side pe sab chaiye hain, latest technology pe, aur in ek ke andar features kya hongay, woh sab tum ne decide karna hai, repo mein update karna hai."

**What was read:** the live awam Business-account Settings Center (anexomail.com/app/settings, every tab opened, 1 Nov 10:15). Nothing was changed there. Awam tab order is the founder tab order; this is now locked. Awam shows 7 tabs: Personal, Workspace, Appearance, Notifications, Privacy, Time machine, Drift & schedule. (An AI settings page exists in the awam code but is not a tab on this account; founder gets it with F6 AI.) Every awam row carries three buttons: **Explain · Blast radius · History**. The awam Drift page showed 100/100 with 13 aligned items.

## Rules of this port (all existing rules, restated)
1. Same tab order, same row pattern (title, one plain sentence, current value, Explain / Blast radius / History), same calm wording — in English (Rule 67).
2. Founder tech, not awam tech: Rust axum + signed envelope (HMAC write, Ed25519 answers), Postgres RPC `founder_setting_set` (history + audit in one transaction), WASM kernel proof in the browser, React 19 + TS + TanStack + Tailwind 4 + shadcn, Cinematic look. No Bun, no pm2, no Node on the server.
3. A tab or row appears only when its backend is real (Rule 69). Until then the side list says which phase brings it (as today).
4. **Every new setting key ships with its three things in the same phase:** info row (Explain/Blast text), baseline row (Drift), and it is schedulable unless marked not. This is what keeps Drift honest as the count grows.
5. Danger ratchet (E103): a key's gate can only go up. G1w = cosmetic/own-profile, G2 = two-tap + reason, G3 = passkey.
6. Awam tenant policies (members, retention for customers, customer 2FA) are NOT founder settings. They are solved in **Admin** (Systems, step 12). The founder tab only holds the founder's own choices.

## Tab by tab
| # | Tab (awam rows seen) | Founder version — what it contains | Gate | Technology | Phase |
|---|---|---|---|---|---|
| 1 | **Personal** — Display name, Undo send window (30), Send confidence check (On), Home city (detect / search) | Display name ✔ LIVE, Home city ✔ LIVE (device-detect + search, exact position never saved), Profile photo ✔ LIVE. **Undo send window** and **Send confidence check** move to the Mail Desk keys `mail.undo_send_seconds`, `mail.send_confidence` | G1w / G2 | SQL E108 + Rust `settings.rs` (live); mail keys: Rust delay queue | live; mail keys = step 11 (Mail Desk, last) |
| 2 | **Workspace** — Retention window, Require two-factor for everyone, Flag external recipients | Founder company defaults: company name, domains, support address (Systems). **Founder retention window** for his own mailbox. **Require passkey for every sign-in** (the founder form of "2FA for everyone"; one person, so it is the account rule + device approval). **Flag external recipients** in Mail Desk | G2 / G3 | SQL registry keys + Rust; passkey = webauthn-rs | passkey rule = step 7 (S3); rest = step 12 (Systems) and 11 |
| 3 | **Appearance** — THIS DEVICE: Text size (90/Default/115/130/150), Animations (Full/Reduced/None), Transitions (Fast/Normal/Slow), Graphics & visual effects, Celebration, High-contrast focus ring. ACCOUNT: Density (comfortable…), Reduce motion | All 8 + the two already live (Graphics, Compact sidebar). Device-local values apply instantly and are also saved on the account so every approved device matches. The OS reduced-motion setting always wins. Cinematic look stays (aurora, glass sidebar); Graphics off gives the flat fast look | G1w | SQL E114 (registry extension: `appearance.text_scale`, `animations`, `transitions`, `celebration`, `focus_ring`, `density`, `reduce_motion`), React-TS, CSS variables | **S1b, right after S2 (step 6)**, Chrome-checked before step 7 |
| 4 | **Notifications** — Quiet hours (On, escalations pass), Only VIPs interrupt (Off) | Quiet hours with the "escalations always pass" rule; **per-alert routing** for the real sources: Decide queue, Live Pulse, payment failed, unusual login, rejected-webhook spike, ledger seal lag. Channels: browser push first, email through Mail Desk. VIP list = founder-chosen senders | G2 (external channel) | Rust web-push + service worker; SQL registry | S4 (step 8: Decide + Live Pulse); email = step 11 |
| 5 | **Privacy** — Read receipts (never sent, informational), Block tracking pixels (On) | Both kept: read receipts shown as "Never sent — nothing to switch on"; tracking pixels blocked in Mail Desk render. Founder additions: session lifetime, device-approval strictness, passkey-required for G3, audit visibility, **export** of own data (G3) | G2 / G3 | SQL + Rust + passkey (F2d) + kernel | S3 (step 7); pixels = step 11 |
| 6 | **Time machine** — "Every setting change, reversible" | ✔ SQL **E113**: every version, who/when/from/to, one-click undo (each version once), point-in-time view, diff, merged feed, history-vs-live replay check. Founder extra: each version shows its audit entry number and is **proven in this browser** with the kernel Merkle check | G1 read / G2 undo | SQL E113 (done locally), Rust `settings_s2.rs`, kernel `merkle@1`, React-TS | step 6: SQL written, Rust + UI next |
| 7 | **Drift & schedule** — score 100/100, aligned/looser/risky; scheduled changes with auto-rollback | ✔ SQL **E113**: score from real baselines (name, home city, ledger seal policy, unsealed lag) which grows with each new key; scheduled changes with "keep it or it rolls back", never overwrites a newer value | G1 / G2 | SQL E113, Rust tick every minute, React-TS | step 6 |
| — | **AI settings** (awam page, not a tab on Business) | Leo/AI limits for the founder surface | G2 | Rust + SQL | step 12 (F6 AI) |

## Features inside each tab — the final founder list (keys)
Personal: `personal.display_name`, `personal.home`, `personal.avatar` (live), `mail.undo_send_seconds`, `mail.send_confidence`.
Workspace: `workspace.company_name`, `workspace.domains`, `workspace.support_address`, `workspace.retention_days`, `workspace.require_passkey`, `workspace.flag_external`.
Appearance: `appearance.graphics`, `appearance.sidebar_slim` (live), `appearance.text_scale`, `appearance.animations`, `appearance.transitions`, `appearance.celebration`, `appearance.focus_ring`, `appearance.density`, `appearance.reduce_motion`.
Notifications: `notify.quiet_hours`, `notify.vip_only`, `notify.route.*` (one per real alert source).
Privacy: `privacy.session_hours`, `privacy.device_strictness`, `privacy.passkey_for_g3`, `privacy.block_pixels`, `privacy.audit_visible`.
Total target: about 30 keys, each with Explain, Blast radius, History, Drift baseline and schedulable flag. Today 5 are live; E113 adds the Time machine, Drift and schedule machinery on top of them.

## Order inside the master order (no tarteeb broken)
Step 6 = S2 (E113 SQL → Rust → UI). Right after it, **S1b** (E114 Appearance keys + UI) because it is the same Settings page and needs no new backend. Then step 7 (passkey + S3 Privacy), step 8 (S4 Notifications), step 11 (mail keys), step 12 (Workspace + AI + Admin). Nothing jumps ahead.

## What I did NOT copy
Tenant-level controls for awam customers (they live in Admin). Anything that would be a button with no engine behind it.
