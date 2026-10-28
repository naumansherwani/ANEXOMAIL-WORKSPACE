# FOUNDER FEATURE MAP — existing + new, in order, with gates and endpoints (28 Oct 2026)

> Founder 08:56: "existing features + new features intact, tarteeb se, gates aur endpoints advance level par." Source of truth in code: `founder-web/src/catalog.js` (this file is generated from it). Rules: FC1 (founder/awam alag), FC10 (naye endpoint sirf `/founder/v1/*` Rust), FC12 (purani feature bina ghar ke nahi chhootegi), FC13 (cluster-free), FC14 (acha purana intact), FC18 (common features port, awam files no-touch), Rule 57 (naya proc ENDPOINT-PACKAGE-MAP mein pehle), Rule 63 (koi fake data nahi).

## Technology (locked, FOUNDER-CRYPTO-FINAL)
Supabase (RLS on) -> Rust `anexomail-founder` (axum 0.8, tokio; Ed25519 server->browser, HMAC-SHA256+HKDF browser->server, SHA-256 audit chain) -> fetch/WebTransport -> WASM kernel (enforce) -> React 19.2 / Vite 8.2 SPA. ES256 JWT aud=anexo-founder, 15 min, memory only. No Bun/Node in founder.

## The three gates (one rule for every endpoint)
- **G1 read** — GET, signed founder session (ES256 + founder_accounts). Nothing changes.
- **G2 two-tap + reason** — POST /founder/v1/action: tap 1 opens the reason sheet (>= 8 chars), tap 2 confirms. Audit row written even if the executor is off (409 until F8).
- **G3 passkey** — G2 plus WebAuthn passkey assertion. Money, impersonation, kill switch, release, rollback, export.
- Danger ratchet in DB (E103): a gate level can only go UP, never down. Every write = `founder_audit` hash-chain entry.

## Why "WORKSPACE" is written
It is part of the real logo lockup (ANEXOMAIL over WORKSPACE, same as BrandMark.tsx in the awam app) so it stays. The extra "Founder Workspace" chip and the top-right "Workspace" link were removed: chip now says "Founder", link says "Open app".

## Order of work (one phase at a time, Rule 64)
F1a device login -> F2a/b/c Bridge + kernel -> F3 Finance + Release + Move-In reads -> F4 People -> F5 Mail Desk -> F6 Systems + AI -> F8 Control + executor (all G2/G3 writes go live) -> F9 cutover (old Lovable pages removed only after the same feature is live in Chrome here).

## Finance (F3)
Revenue, billing, credits and pipeline in one place. Reading needs your signed session; anything that moves money needs a second tap, a reason, and for the strongest actions your passkey.

| Feature | Gate | Endpoint | Phase | Origin |
|---|---|---|---|---|
| Revenue overview | G1 read | `GET /founder/v1/finance/overview` | F3 | today's app (moves) |
| Pipeline | G1 read | `GET /founder/v1/finance/pipeline` | F3 | today's app (moves) |
| Billing health | G1 read | `GET /founder/v1/finance/billing` | F3 | today's app (moves) |
| Support replies | G1 read | `GET /founder/v1/finance/replies` | F3 | today's app (moves) |
| Mark reply sent | G2 two-tap+reason | `POST /founder/v1/finance/replies/:id/done` | F3 | today's app (moves) |
| AI credits | G1 read | `GET /founder/v1/finance/ai-credits` | F3 | today's app (moves) |
| Real-time MRR / ARR | G1 read | `GET /founder/v1/finance/mrr` | F3 | new |
| Failed payments & churn | G1 read | `GET /founder/v1/finance/failed` | F3 | new |
| Reconciliation | G1 read | `GET /founder/v1/finance/reconcile` | F3 | new |
| Forecast | G1 read | `GET /founder/v1/finance/forecast` | F3 | new |
| Biggest leak | G1 read | `GET /founder/v1/finance/leak` | F3 | new |
| Send payment reminder | G2 two-tap+reason | `POST /founder/v1/action finance.send_reminder` | F3 | new |
| Extend grace period | G2 two-tap+reason | `POST /founder/v1/action finance.extend_grace` | F3 | new |
| Comp / free plan | G3 passkey | `POST /founder/v1/action finance.comp_plan` | F4 | new |

## People (F4)
Organisations, users, devices and permissions. Metadata only: message content is never shown.

| Feature | Gate | Endpoint | Phase | Origin |
|---|---|---|---|---|
| Organisations | G1 read | `GET /founder/v1/people/orgs` | F4 | today's app (moves) |
| CRM state | G1 read | `GET /founder/v1/people/crm` | F4 | today's app (moves) |
| Team permissions | G1 read | `GET /founder/v1/people/permissions` | F4 | today's app (moves) |
| Members and teams | G1 read | `GET /founder/v1/people/members` | F4 | today's app (moves) |
| Security by tenant | G1 read | `GET /founder/v1/people/security` | F4 | today's app (moves) |
| Toggle CRM feature | G2 two-tap+reason | `POST /founder/v1/action people.crm_toggle` | F4 | today's app (moves) |
| Impersonate user | G3 passkey | `POST /founder/v1/action people.impersonate` | F4 | today's app (moves) |
| Account 360 | G1 read | `GET /founder/v1/people/account/:id` | F4 | new |
| Abuse review board | G1 read | `GET /founder/v1/people/abuse` | F4 | new |
| Appeals queue | G1 read | `GET /founder/v1/people/appeals` | F4 | new |
| Suspend / restore user | G2 two-tap+reason | `POST /founder/v1/action people.suspend_user` | F4 | new |
| Force sign-out / revoke device | G2 two-tap+reason | `POST /founder/v1/action people.revoke_device` | F4 | new |
| Extend trial | G2 two-tap+reason | `POST /founder/v1/action people.extend_trial` | F4 | new |

## Mail Desk (F5)
Company mailboxes, support replies and deliverability.

| Feature | Gate | Endpoint | Phase | Origin |
|---|---|---|---|---|
| Company mailboxes | G1 read | `GET /founder/v1/mail/mailboxes` | F5 | today's app (moves) |
| AI email addresses | G1 read | `GET /founder/v1/mail/ai-mail` | F5 | today's app (moves) |
| Support desk (Leo) | G1 read | `GET /founder/v1/mail/support` | F5 | today's app (moves) |
| Family accounts | G1 read | `GET /founder/v1/mail/family` | F5 | today's app (moves) |
| Delivery monitoring | G1 read | `GET /founder/v1/mail/delivery` | F5 | today's app (moves) |
| Provision mailbox | G2 two-tap+reason | `POST /founder/v1/action mail.provision` | F5 | today's app (moves) |
| Approve AI mail | G2 two-tap+reason | `POST /founder/v1/action mail.ai_approve` | F5 | today's app (moves) |
| Unified company inbox | G1 read | `GET /founder/v1/mail/inbox` | F5 | new |
| Deliverability | G1 read | `GET /founder/v1/mail/deliverability` | F5 | new |
| Requeue failed mail | G2 two-tap+reason | `POST /founder/v1/action mail_desk.requeue_failed` | F5 | new |
| Draft a reply (LEO) | G2 two-tap+reason | `POST /founder/v1/mail/draft` | F5 | new |
| 24-hour SLA clock | G1 read | `GET /founder/v1/mail/sla` | F5 | new |

## AI (F6)
Workflows, knowledge, prompts, spend and receipts for the AI features.

| Feature | Gate | Endpoint | Phase | Origin |
|---|---|---|---|---|
| AI overview | G1 read | `GET /founder/v1/ai/overview` | F6 | today's app (moves) |
| Workflows and automation | G1 read | `GET /founder/v1/ai/automation` | F6 | today's app (moves) |
| Knowledge | G1 read | `GET /founder/v1/ai/knowledge` | F6 | today's app (moves) |
| Memory | G1 read | `GET /founder/v1/ai/memory` | F6 | today's app (moves) |
| Prompts | G1 read | `GET /founder/v1/ai/prompts` | F6 | today's app (moves) |
| Studio recipes | G1 read | `GET /founder/v1/ai/studio` | F6 | today's app (moves) |
| Receipts | G1 read | `GET /founder/v1/ai/receipts` | F6 | today's app (moves) |
| Arena | G1 read | `GET /founder/v1/ai/arena` | F6 | today's app (moves) |
| Daily spend cap | G3 passkey | `POST /founder/v1/action ai.set_cap` | F6 | today's app (moves) |
| Delete knowledge document | G2 two-tap+reason | `POST /founder/v1/action ai.delete_doc` | F6 | today's app (moves) |
| Ask anything (metadata only) | G1 read | `POST /founder/v1/ai/ask` | F9 | new |

## Release (F3)
What is live, what changed, and one-click deploys with proof.

| Feature | Gate | Endpoint | Phase | Origin |
|---|---|---|---|---|
| Launch verdict | G1 read | `GET /founder/v1/release/overview` | F3 | today's app (moves) |
| Checklist | G1 read | `GET /founder/v1/release/checklist` | F3 | today's app (moves) |
| Deployments | G1 read | `GET /founder/v1/release/deployments` | F3 | today's app (moves) |
| QA runs | G1 read | `GET /founder/v1/release/qa` | F3 | today's app (moves) |
| Roadmap | G1 read | `GET /founder/v1/release/roadmap` | F3 | today's app (moves) |
| Diagnostics | G1 read | `GET /founder/v1/release/diagnostics` | F3 | today's app (moves) |
| Tick checklist item | G2 two-tap+reason | `POST /founder/v1/action release.checklist_item` | F8 | today's app (moves) |
| Run release step | G3 passkey | `POST /founder/v1/action release.run` | F8 | today's app (moves) |
| Lock v1.0 | G3 passkey | `POST /founder/v1/action release.lock` | F8 | today's app (moves) |
| Release gate | G1 read | `GET /founder/v1/release/gate` | F8 | new |
| Canary | G3 passkey | `POST /founder/v1/action release.canary` | F8 | new |
| Roll back last build | G3 passkey | `POST /founder/v1/action release.rollback` | F8 | new |

## Move-In (F3)
Customer onboarding cockpit: slots, cut-overs, mailbox and DNS checks.

| Feature | Gate | Endpoint | Phase | Origin |
|---|---|---|---|---|
| Move-in cockpit | G1 read | `GET /founder/v1/movein/cockpit` | F3 | today's app (moves) |
| Deal detail | G1 read | `GET /founder/v1/movein/deal/:id` | F3 | today's app (moves) |
| Move deal to next stage | G2 two-tap+reason | `POST /founder/v1/action movein.transition` | F8 | today's app (moves) |
| Schedule cut-over | G2 two-tap+reason | `POST /founder/v1/action movein.schedule` | F8 | today's app (moves) |
| Create mailbox / DNS / runbook | G2 two-tap+reason | `POST /founder/v1/action movein.setup` | F8 | today's app (moves) |
| Raise exception | G2 two-tap+reason | `POST /founder/v1/action movein.exception` | F8 | today's app (moves) |
| Create invoice | G3 passkey | `POST /founder/v1/action movein.invoice` | F8 | today's app (moves) |
| Roll back cut-over | G3 passkey | `POST /founder/v1/action movein.rollback` | F8 | today's app (moves) |

## Systems (F6)
Real health probes, capacity and speed across every tenant.

| Feature | Gate | Endpoint | Phase | Origin |
|---|---|---|---|---|
| Whole platform | G1 read | `GET /founder/v1/systems/overview` | F6 | today's app (moves) |
| Health and self-heal | G1 read | `GET /founder/v1/systems/health` | F6 | today's app (moves) |
| Logs | G1 read | `GET /founder/v1/systems/logs` | F6 | today's app (moves) |
| Storage | G1 read | `GET /founder/v1/systems/storage` | F6 | today's app (moves) |
| Speed | G1 read | `GET /founder/v1/systems/perf` | F6 | today's app (moves) |
| Call engine | G1 read | `GET /founder/v1/systems/calls` | F6 | today's app (moves) |
| Motion budgets | G1 read | `GET /founder/v1/systems/motion` | F6 | today's app (moves) |
| Integrations | G1 read | `GET /founder/v1/systems/integrations` | F6 | today's app (moves) |
| Platform analytics | G1 read | `GET /founder/v1/systems/analytics` | F6 | today's app (moves) |
| Reports | G1 read | `GET /founder/v1/systems/reports` | F6 | today's app (moves) |
| Data export | G3 passkey | `POST /founder/v1/action systems.export` | F6 | today's app (moves) |
| Recheck all health | G2 two-tap+reason | `POST /founder/v1/action systems.recheck_health` | F6 | new |
| Real probes | G1 read | `GET /founder/v1/systems/probes` | F6 | new |
| Capacity and cost | G1 read | `GET /founder/v1/systems/capacity` | F6 | new |
| DNS, certificate, backup | G1 read | `GET /founder/v1/systems/expiry` | F6 | new |
| Restart Rust engine | G3 passkey | `POST /founder/v1/action systems.restart_rust` | F8 | new |

## Control (F8)
Kill switches, flags and maintenance. Every change is audited and reversible where possible.

| Feature | Gate | Endpoint | Phase | Origin |
|---|---|---|---|---|
| Settings changes | G1 read | `GET /founder/v1/control/settings` | F8 | today's app (moves) |
| Kill switches | G1 read | `GET /founder/v1/control/kill-switches` | F8 | today's app (moves) |
| Set kill switch | G3 passkey | `POST /founder/v1/action control.kill_switch` | F8 | today's app (moves) |
| Revert a setting | G2 two-tap+reason | `POST /founder/v1/action control.revert` | F8 | today's app (moves) |
| Maintenance mode | G3 passkey | `POST /founder/v1/action control.maintenance_on` | F8 | new |
| Freeze new sign-ups | G3 passkey | `POST /founder/v1/action control.freeze_signups` | F8 | new |
| Feature flags per plan | G2 two-tap+reason | `POST /founder/v1/action control.flag` | F8 | new |
| Audit chain | G1 read | `GET /founder/v1/audit` | F2b | new |
| Break-glass log | G1 read | `GET /founder/v1/control/break-glass` | F8 | new |
| Incident replay | G1 read | `GET /founder/v1/control/replay` | F8 | new |

## Totals
96 features: 62 moved from today's app, 34 new. Gates: G1 62, G2 20, G3 14.

## Open decisions (need founder "haan" at the phase)
- Gate wiring: add the finance and ai decks plus the G2/G3 keys above to `founder_actions` (new E-SQL with CHECK, ratchet-safe) — at F3.
- Polar read-only API token (F3).
- Awam app reading feature flags touches no-touch code (F8).
- Lifting Rule 23 for LEO draft and ask-anything (F5/F9).


## Common features (same on user side) — rule FC22
Mail, Calendar, People, Work, CRM, Analytics, Org, Safety, ANEXOChat, Speed, Settings and the admin pages already exist on the user side in latest-technology code (Rust procs + React). Founder gets the same features, in this map's order, through the founder protocol only: reuse the pure logic (`#[path]` include or port into `server/founder`), never edit user files, never share design or gates with the user app. Before building any row above, write down where its user-side proc lives (ENDPOINT-PACKAGE-MAP.csv, count-endpoints.py), then port. Awam order (ONE-ORDER-27OCT.md) stays untouched and resumes after founder green (FC21).

## Live check 28 Oct 09:14 PKT (Chrome, read-only)
https://founderworkspace.anexomail.com/ shows the new shell: real logo, "Founder" chip, "Open app", sidebar Bridge / Finance / People / Mail Desk / AI / Release / Move-In / Systems / Control / Audit, Finance card (£ 0, no accounts recorded), What needs attention OK, Customer voice 1 new, updated 09:13:58 every 15 s. Not yet checked live: deck pages, "Activating → Activated" splash after a fresh sign-in.
