# Awam Settings Center — the REAL list, read live in Chrome (1 Nov 2026, ~11:15 PKT)
Source: founder's logged-in Business account, https://anexomail.com/app/settings/* , every tab opened and its text read (not remembered, not guessed). This is the pattern the founder side copies tab for tab (same order, same wording style, same instant behaviour). Founder side stays separate from awam (Rule 35); nothing here is awam code.

Order of tabs in the nav (7): **Personal · Workspace · Appearance · Notifications · Privacy · Time machine · Drift & schedule**. (No AI tab in awam's nav.) Every row of the "account" kind has three links: **Explain · Blast radius · History**, and a Turn on/off button for toggles.

## 1. Personal — "Your own workspace — name, signature, defaults. Nothing here leaks to anyone else."
| Row | Text | Value seen |
|---|---|---|
| Display name | The name recipients see next to your address. | — (unset) |
| Undo send window | How long a sent mail is held before it really leaves. | 30 |
| Send confidence check | Warn before sending when tone, recipients or attachments look wrong. | On (Turn off) |
| Home city | Your greeting follows this city's sunset and your clock is named after it. | "Not set · device says Karachi"; **Detect my city** (browser asked once, nearest city chosen on the device, exact position never sent or saved); **Or search your city** |

## 2. Workspace — "Company-wide behaviour. Every change shows its blast radius before you save."
| Row | Text | Value seen |
|---|---|---|
| Retention window | How long mail is kept before permanent deletion. | Keep forever — nothing is deleted automatically |
| Require two-factor for everyone | Members without a second factor cannot sign in. | On (Turn off) |
| Flag external recipients | Show a clear warning when a thread leaves the company. | On (Turn off) |

## 3. Appearance — TWO blocks on one page
**Block A — THIS DEVICE · "Motion & delight"** — "Applies the moment you tap it — no save button, no reload. Your operating system's reduced-motion setting always wins on top of this." (device-local, no Explain/History links)
| Control | Text | Options |
|---|---|---|
| Text size | Makes all text bigger or smaller on this device — your phone, tablet or laptop remembers it. You can also pinch to zoom any time. | 90% · Default · 115% · 130% · 150% |
| Animations | Full keeps the whole motion language · Reduced fades only, nothing travels · None is complete stillness (calm mode). | Full · Reduced · None |
| Transitions | The tempo of every panel, hover and reveal. Fast is 0.6× the standard clock, slow is 1.5×. | Fast · Normal · Slow |
| Graphics & visual effects | Glows, aurora backgrounds and floating cards (and future 3D scenes). Turn off for a flat, fast, battery-friendly look. Same on every plan. | switch |
| Celebration (earned delight) | On by default. Fires only when work is genuinely finished — inbox zero, a promise kept, your domain proven green. | switch |
| High-contrast focus ring | Makes the keyboard position unmistakable — useful on projectors and for accessibility reviews. | switch |
Footer line: "Operating system reduced-motion: off · motion currently allowed" (live read of the OS setting).

**Block B — ACCOUNT · "Appearance"** — "Density and theme, stored on your account. Instant, no reload, no layout jump."
| Row | Text | Value seen |
|---|---|---|
| Density | How tight the three-panel layout packs information. | comfortable — Explain · Blast radius · History |
| Reduce motion | Honour the system setting and drop all non-essential animation. | Off — Explain · Blast radius · History · Turn on |

## 4. Notifications — "Who is allowed to interrupt you, and when silence is enforced."
| Row | Text | Value seen |
|---|---|---|
| Quiet hours | Silence everything outside working hours, except escalations. | On (Turn off) |
| Only VIPs interrupt | Everything else waits for the next inbox check. | Off (Turn on) |

## 5. Privacy — "Tracking, read receipts, retention and who can see what. Off by default."
| Row | Text | Value seen |
|---|---|---|
| Read receipts | ANEXOMAIL never tells a sender when you open their mail — there is nothing to switch on. | Off · "Never sent" |
| Block tracking pixels | Strip trackers from incoming mail before it renders. | On (Turn off) |

## 6. Time machine — "Every setting change, reversible. Who changed what, when, and why — and one click to put it back exactly as it was."
Empty-state seen on a fresh account: "Nothing has been changed yet."

## 7. Drift & schedule
- DRIFT VS BASELINE — "How far you are from the safe defaults": Score 100/100 · Aligned 13 · Looser 0 · Risky 0.
- SCHEDULED CHANGES — "Apply later, roll back automatically": "A risky change can land out of hours and undo itself if delivery or sign-in breaks." Empty state "Nothing scheduled."

## Founder side: what goes where (same tabs, same order; features decided by CEO-agent)
| Tab | Founder rows (every one gets Explain · Blast radius · History + a Drift baseline) | State |
|---|---|---|
| Personal | Display name, Profile photo, Home city (detect/search) LIVE; Undo send window + Send confidence check → Mail Desk keys (step 11) | 3 live |
| Workspace | Retention window, Require passkey for every sign-in (founder form of "2FA for everyone"), Flag external recipients; company name/domains/support address (Systems, step 12) | step 7 / 11 / 12 |
| Appearance | **THIS DEVICE block:** Text size, Animations, Transitions, Graphics, Celebration, High-contrast focus ring + OS reduced-motion footer line. **ACCOUNT block:** Density, Reduce motion, Compact sidebar. **Founder extra:** AMBIENT STUDIO (car-style ambient looks, >1M, computed from table sizes) + Favourites | **S1b = E114 (SQL written 1 Nov, not yet run on server) → Rust → UI** |
| Notifications | Quiet hours, Only VIPs interrupt, + per-alert routing | S4, step 8 |
| Privacy | Read receipts ("Never sent"), Block tracking pixels, + session lifetime, device strictness, passkey for G3 | S3, step 7 / 11 |
| Time machine | LIVE (E113, 18 versions, each proven in the browser) | GREEN |
| Drift & schedule | LIVE (E113, score from real baselines, scheduled changes with rollback) | GREEN |
| AI | founder only, built last (step 16, Rule 71) | later |

Correction recorded: the Appearance device block (6 controls) and account block (Density, Reduce motion) both belong INSIDE the Appearance tab, with the same wording as above. An earlier note of mine listed them only as keys; this file is the exact reference. Awam AI code: untouched.

## What opens inside every account row (opened live on Personal → Display name, 1 Nov ~11:12)
- **Explain** — the row's plain-words sentence (one panel open at a time per row).
- **Blast radius** — a count line "0 members · 0 mailboxes · 0 automations" and a second line "Severity low · reversible in one click". Founder version: real counts from the info registry (E113 `founder_setting_blast`), e.g. approved devices, scheduled changes.
- **History** — "No change recorded yet." or the list of past values for that one key. Founder version: the same plus the ledger entry number and a browser-side "proven" tick.
- Row controls seen: Turn on / Turn off for toggles; Detect my city / search box for Home city.

## GAP: awam row -> founder state (1 Nov 12:00, founder order "awam walay features founder ko milen")
| Awam tab | Awam row | Founder today | Plan (S1c = one phase: SQL E115 registry keys + Rust REGISTRY + UI rows) |
|---|---|---|---|
| Personal | Display name, Home city | LIVE | - |
| Personal | Profile photo (founder extra) | LIVE | - |
| Personal | Undo send window | S1c written 1 Nov (E115 local green, Rust 117 tests, UI) — server install pending | - |
| Personal | Send confidence check | S1c written (same) | - |
| Workspace | Retention window | S1c written (tab live) | key `retention_days` (0 = keep forever) |
| Workspace | Require two-factor for everyone | S1c written | founder form: `require_passkey` (bool); enforced by step 7 passkey |
| Workspace | Flag external recipients | S1c written | key `flag_external` (bool, on) |
| Appearance | THIS DEVICE (6) + footer, ACCOUNT Density/Reduce motion | LIVE in code; polish SPA installed but live site still serves old index (diagnosis pending) | - |
| Notifications | Quiet hours | S1c written (tab live) | key `quiet_hours` (bool, on; escalations excepted) |
| Notifications | Only VIPs interrupt | S1c written | key `only_vips` (bool, off) |
| Privacy | Read receipts | S1c written (tab live) | read-only row "Never sent" (no key: nothing to switch on) |
| Privacy | Block tracking pixels | S1c written | key `block_tracking_pixels` (bool, on) |
| Time machine, Drift & schedule | - | LIVE (E113) | new keys join automatically via registry |
Honest rule: each new row stores real values in the registry with history/blast/drift/schedule like the rest; rows whose effect belongs to a later step say so in their Explain text (no fake "enforced"). Order: (1) fix live SPA, (2) S1c.
