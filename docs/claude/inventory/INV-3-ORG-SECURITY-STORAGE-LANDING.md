# INV-3 — ORG / SECURITY / STORAGE / BILLING / SETTINGS / PUBLIC pages (read-only audit, 26 Oct 2026)

Status = what the code says. 'not wired' = UI shows honest fallback if the endpoint is missing (NO MOCK rule). Gate = function in `src/lib/plan-surface.ts` (none = all plans).

## Features (59 rows)

| # | Area | Feature | What it does | Evidence | Status | Plan gate today |
|---|---|---|---|---|---|---|
| 1 | Org | Org overview | Seats, role mix, health summary of the company | routes/app.org.index.tsx, lib/org.ts | works | showOrg (business kind + Business+) |
| 2 | Org | Members & invitations | List members, invite by link, change role, revoke access | app.org.members.tsx, lib/team.ts | works; blast-radius + revoke show 'not wired' if endpoint missing | showOrg |
| 3 | Org | Roles & capability matrix | owner/admin/manager/member/viewer, who can do what | app.org.roles.tsx, org.ts | works | showOrg |
| 4 | Org | Departments | Group members into departments | app.org.departments.tsx | works | showOrg |
| 5 | Org | Policies + policy simulator | Toggle company policies, simulate effect first | app.org.policies.tsx | works; simulator/toggle 'not wired' fallback | showOrg |
| 6 | Org | Audit ledger | Hash-chained log of org actions | app.org.audit.tsx, components/org/LedgerPanel | works | showOrg |
| 7 | Org | Compliance + one-click data export | Owner-only JSON export (members, mail, calendar, tasks, CRM) | app.org.compliance.tsx, lib/org-export.ts | works | showOrg (owner only server-side) |
| 8 | Org | Live org graph | Who-works-with-whom graph | app.org.graph.tsx | works | showOrg |
| 9 | Org | Org security (kill device, break-glass) | Org-wide device kill and break-glass access | app.org.security.tsx | works; kill/break-glass 'not wired' fallback | showOrg |
| 10 | Org | Teams | Create teams, join by invitation link | lib/team.ts, Rust team.* | works | none (Org-adjacent) |
| 11 | Org | Company domains & addresses | Connect own domain, mailboxes, aliases, DNS ownership | app.domains.tsx (2046 lines), lib/domains.ts | works | showDomains (business kind, any plan) |
| 12 | Org | Workspace address @anexomail.com | Claim name@anexomail.com working address | lib/anexomail-address.ts | works | none |
| 13 | Org | Org export (Admin → Export) | Same export bundle for admin | lib/org-export.ts | works | founder host only (admin) |
| 14 | Security | Security home | Overview of device trust, sessions, proof, encryption | app.security.index.tsx | works | none (all plans) |
| 15 | Security | Device trust list + one-click revoke | Trusted/pending/blocked devices, trust score, kill | app.security.devices.tsx, security-platform.ts | works; 'not wired' fallback | none (device-vault slot count per plan) |
| 16 | Security | Impossible-travel detection | Geo/velocity anomaly freeze | security-platform.ts, Rust | works (server-side) | none |
| 17 | Security | Ownership proof (DKIM/SPF/DMARC/TLS) | Hashed exportable DNS/TLS proof | app.security.proof.tsx | works; 'not wired' fallback | none |
| 18 | Security | Encryption ledger | At-rest/in-transit per surface | app.security.encryption.tsx | works | none |
| 19 | Security | Login history / replay | Risk story per login + 'not me' revoke | app.security.history.tsx | works | none |
| 20 | Security | Sessions + blast-radius kill | See sessions; kill all sessions+devices in one click | app.security.sessions.tsx | works; kill 'not wired' fallback | none |
| 21 | Security | Device Safety Vault | Sealed non-biometric device identity (SHA-256 of 5 trait groups, ECDSA device key) | app.security.vault.tsx, device-fingerprint.ts, device-key.ts | works | none |
| 22 | Security | Passkey (mandatory) + recovery codes | Password + passkey, recovery codes if phone lost | lib/passkey.ts, RecoveryCodesPanel, PasskeyGate | works | none |
| 23 | Security | Account integrity: one person one account | Suspicious-device detection (3+ accounts / 3 signups in 24h) | lib/account-integrity.ts, IntegrityGate | works | none |
| 24 | Security | Final-warning ladder before block | Warnings before an account block (email + push to verify) | AccountIntegrityPanel.tsx | works (channels to verify) | none |
| 25 | Security | Appeal with evidence | Upload evidence for device/account appeal | lib/appeal-evidence.ts, AppealForm, DeviceAppealPanel | works | none (user side) |
| 26 | Security | Pre-launch site lock | Whole site locked to public by key | lib/site-lock.ts | works (internal) | internal |
| 27 | Safety | Safety centre / review queue | new→under review→action→resolved | app.safety.tsx, SafetyPanels.tsx | works | showSafety (Business Pro power) |
| 28 | Safety | Sealed report evidence | Opening evidence is logged with a reason | SafetyPanels.tsx | works | showSafety |
| 29 | Safety | Enforcement history + device ban list | Past actions and bans | SafetyPanels.tsx | works | showSafety |
| 30 | Safety | Report message/person/file/conversation | User-side report | components/app/safety | works | none (listed under Business on plans.ts) |
| 31 | Devices | Devices & offline | List devices, offline read cache, PWA install | app.devices.tsx, lib/offline.ts, lib/pwa.ts | works | none |
| 32 | Storage | Mailbox storage & quota | Used/quota per mailbox, 80/90/100% states, days-until-full | app.storage.tsx, lib/storage-client.ts | works | none (quota differs by plan; DB phase48) |
| 33 | Billing | Billing & Plans page | Plan cards, upgrade/downgrade, manage via Polar | app.billing.tsx (755), ManageBilling.tsx | works | none |
| 34 | Billing | Billing state | Subscription state, seats, invoices | app.billing.state.tsx, billing-platform.ts | works; shows price_per_seat/seats (v6 mismatch) | none |
| 35 | Billing | Checkout done | Post-Polar checkout confirmation | checkout.done.tsx | works | none |
| 36 | Billing | Trial lifecycle (2 days) | 2-day free trial, read-only after, no card | lib/trial.ts, TrialStrip, trial-ended.tsx | works | none |
| 37 | Billing | Family/lifetime access | Free lifetime account via same resolver | billing-platform.ts (lifetime) | works | none (Rule 40/37) |
| 38 | Billing | Move-In migration (IMAP import) | Copy old mailbox via IMAP+app password; fixed-price bands | lib/migration.ts, lib/movein.ts, routes/migration | works | none |
| 39 | Account | Account & sessions | Profile, sessions, sign-out, recovery | app.account.tsx (680) | works | none |
| 40 | Account | Full data export (ZIP) | Streaming ZIP mail+attachments+contacts+calendar; 72h window if blocked | lib/account-export.ts | works | none |
| 41 | Settings | Settings: Appearance | Theme, density, text size, zoom | app.settings.appearance.tsx, text-size.ts, zoom-prefs.ts | works | none |
| 42 | Settings | Settings: Notifications | Notification prefs | app.settings.notifications.tsx (30 lines, thin) | thin/stub-like | none |
| 43 | Settings | Settings: Privacy | Privacy prefs | app.settings.privacy.tsx (30 lines) | thin/stub-like | none |
| 44 | Settings | Settings: Workspace | Workspace prefs | app.settings.workspace.tsx (27 lines) | thin/stub-like | none |
| 45 | Settings | Settings: Health | Workspace health checks | app.settings.health.tsx | works | none |
| 46 | Settings | Settings: History | Settings change history/versions | app.settings.history.tsx, settings.ts | works | none |
| 47 | Settings | Settings: AI | AI settings (AI host only) | app.settings.ai.tsx | works on ai host | AI host only (denied elsewhere) |
| 48 | Settings | 28 languages (locale overlay) | Awam locales, missing row stays English | lib/locale-sync.ts, public-locale.ts, i18n/ | works | none |
| 49 | Settings | Home place / world clock | Home location, world-clock card | settings/HomePlace.tsx | works | none |
| 50 | Settings | Toast system | Single voice for transient messages | lib/notify.ts | works | none |
| 51 | Public | Landing page | Hero, how-it-works, trust claims, managed move CTA | routes/index.tsx (586) | works; price copy stale | none |
| 52 | Public | Plans & Pricing page | Business compare table + Personal table + FAQ + add-ons | routes/plans.tsx (733) | works; STALE prices | none |
| 53 | Public | Page directory (/pages) | Internal index of all pages with phase notes | routes/pages.tsx (901) | works; stale notes | none |
| 54 | Public | Docs / get-started guide | Setup steps, migration help | routes/docs.tsx, get-started.tsx | works; stale price | none |
| 55 | Public | Enterprise support page | Priority Support £790/mo: named contact, 2-day response, quarterly review | routes/enterprise.tsx | works; NOT an Enterprise package page | none |
| 56 | Public | About / Partners / Status / Privacy / Billing policy | Info pages; partners has fee-quote calculator | about, partners, status, privacy, billing-policy .tsx | works; partners uses PLAN_PRICE (old) | none |
| 57 | Public | Priority Support add-on £790/mo | Named founder contact, 2 business-day response, quarterly review | plans.tsx:143, enterprise.tsx | works (display) | add-on, all workspace plans |
| 58 | Public | Managed Move-In bands £568/1,670/2,210/3,350 | Fixed price migration by mailbox count | plans.tsx:363, index.tsx:480 | works | paid one-off |
| 59 | Public | Booking pages (/book/$handle) | Public booking link (calendar) | routes/book.* | works | (INV-calendar scope) |

## LANDING MISTAKES (v6 flat per-month £40/£105/£360/£2,850/£18,500; Personal £17/£83/£1,850; no per-user)

| # | file:line | What it shows today | Should be |
|---|---|---|---|
| 1 | src/routes/index.tsx:49 | Landing meta/hero: 'From £23 per user.' | Business v6 flat £40/month; per-user pricing is banned (Rule 51) |
| 2 | src/routes/plans.tsx:23,29 | SEO/meta: 'from £23 a month… Basic £23, Pro £46, Business £97' | Prices stale; v6 = £40/£105/£360/£2,850/£18,500 |
| 3 | src/routes/plans.tsx:46-49 | Compare row: '£23 / user', '£46 / user', '£97 / user', '£2,850 / company' | per-user wording + old prices; no Business Premium column |
| 4 | src/routes/plans.tsx:51-57 | Mailboxes included 3/5/On request; Business Pro 'Unlimited internal users' | v6 caps: 5/20/60/570 users; Business Premium unlimited (Business Pro is NOT unlimited) |
| 5 | src/routes/plans.tsx:60-63 | Storage '5GB/10GB/25GB per mailbox', Business Pro '1TB pooled' | v6 shared pools: 25GB/300GB/1.5TB/10TB/15TB |
| 6 | src/routes/plans.tsx:160,172 | FAQ: '£23, £46, £97 and £2,850 are prices before tax'; 'Storage is per mailbox 5/10/25GB' | stale numbers + per-mailbox storage model |
| 7 | src/routes/plans.tsx:233 | Personal 'Largest file you can send: 25 MB / 25 MB / 5 GB' | founder: Personal Pro+ ANEXOChat 2GB, Premium 4GB (5GB stale) |
| 8 | src/routes/plans.tsx:692 | Compare table heads 'Basic · £23 / Pro · £46 / Business · £97 / Business Pro · £2,850' | old prices; Business Premium missing |
| 9 | src/routes/plans.tsx:187,284 | FAQ 'Is there AI in these plans?' (x2) — check wording vs 'AI coming soon July 2027' | AI is separate product ai.anexomail.com, £2,000/£5,000/£25,000, coming soon |
| 10 | src/routes/pages.tsx:47 | Directory note: 'Basic £23 · Pro £46 · Business £97' | stale prices |
| 11 | src/routes/pages.tsx:85 | '5GB resumable transfer' | stale: chat file sizes are per-plan 2/5/7GB |
| 12 | src/routes/docs.tsx:36 | Docs: 'pick the plan (Basic £23 · Pro £46 · Business £97)' | stale prices |
| 13 | src/routes/partners.tsx:113-115,127 | Partner quote uses PLAN_PRICE basic/pro/business ('Basic — £23…') and % of £ | per-user era prices; v6 flat |
| 14 | src/routes/get-started.tsx:88,92 | FAQ: 'Choose Basic, Pro or Business' | Business Pro/Business Premium omitted; fine but stale |
| 15 | src/lib/plans.ts:79-81,97-101,118-122 | monthly 23/46/97, yearly 253/506/970, unit '/ user / month' | v6 flat £40/£105/£360, unit '/ month', yearly Basic/Pro x11, Business/BP x10 |
| 16 | src/lib/plans.ts:127,135-136 | Business: 'Up to 30 users', '15GB transfer per user / month', '2GB max file sending' | v6: 60 users; per-user transfer wording banned; 2GB is ANEXOChat (not email 45MB) |
| 17 | src/lib/plans.ts:188-201 | Business Pro £2,850: 'Unlimited internal users', '1TB pooled', '5GB max file' | v6: 570 users, 10TB, email 60MB, chat 5GB |
| 18 | src/lib/plans.ts:260-262,310-312,349-351 | AI Pro £400 / AI Business £1,500 / AI Executive £4,000 (yearly 4000/15000/40000) | founder 26 Oct: £2,000/£5,000/£25,000 (yearly x10); AI coming soon July 2027 |
| 19 | src/lib/plans.ts (whole) | No Business Premium plan object / card | Business Premium £18,500 unlimited users 15TB 100MB missing |
| 20 | src/lib/billing-platform.ts:4 + Subscription.price_per_seat/seats | Header 'Basic £23 · Pro £46 · Business £97'; fields price_per_seat, seats | per-seat model vs flat per-month + user cap |
| 21 | src/routes/app.billing.tsx:4,530-544 | 'Shows all 4 Polar plans'; renders price_per_seat / interval and seats used | needs 5th plan, flat price wording |
| 22 | src/routes/enterprise.tsx:16-22,111 | Page titled 'Enterprise support' = £790 add-on; no Business Premium package page | clash with new Business Premium £18,500 tier; rename/clarify |
| 23 | src/routes/index.tsx:486 | 'Priority Support — £790 / month' add-on | fine as add-on but Business Premium package will INCLUDE it (CEO proposal) |

## Notes
- Personal prices on plans.tsx:230 (£17/£83/£1,850) and 666 are CORRECT.
- Settings Notifications/Privacy/Workspace pages are 27-30 lines — likely thin; verify before claiming features.
- Analytics routes (/app/analytics*) have no plan gate (other inventory).
