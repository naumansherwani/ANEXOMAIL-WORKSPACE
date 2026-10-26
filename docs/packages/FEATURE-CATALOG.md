# FEATURE CATALOG — poori website, har feature EK package par (auto-generated; EDIT NAHI: features.tsv badlo phir build-views.py chalao)

Qaida: feature sirf **starts_at** wale package par likha hai; upar ke packages ko inherit milta hai. Mix/duplicate nahi. CODE = gate code mein enforce; PROPOSED = CEO assignment (founder approve baqi); TODO-VERIFY = code gate check baqi.

## Matrix

| ID | Area | Feature | Basic | Pro | Business | Biz Pro | Enterprise | Status |
|---|---|---|---|---|---|---|---|---|
| MAIL-01 | Mail | Inbox, folders, threads, search, labels, move, flag | Y | Y | Y | Y | Y | CODE |
| MAIL-02 | Mail | Compose + draft save + version history | Y | Y | Y | Y | Y | CODE |
| MAIL-03 | Mail | Signatures | Y | Y | Y | Y | Y | CODE |
| MAIL-04 | Mail | Outbox + undo send (30s) | Y | Y | Y | Y | Y | CODE |
| MAIL-05 | Mail | Attachments (limit package ke hisaab se, neeche LIMITS) | Y | Y | Y | Y | Y | CODE |
| MAIL-06 | Mail | Snooze | - | Y | Y | Y | Y | CODE |
| MAIL-07 | Mail | Schedule send | - | Y | Y | Y | Y | CODE |
| MAIL-08 | Mail | Email templates | - | Y | Y | Y | Y | CODE |
| MAIL-09 | Mail | Snippets | - | Y | Y | Y | Y | CODE |
| MAIL-10 | Mail | Follow-up reminders | - | Y | Y | Y | Y | CODE |
| MAIL-11 | Mail | Pre-send scan (confidence) | - | Y | Y | Y | Y | CODE |
| MAIL-12 | Mail | Draft handoff between devices | - | Y | Y | Y | Y | CODE |
| MAIL-13 | Mail | Shared inbox + collision guard + assign | - | Y | Y | Y | Y | CODE |
| MAIL-14 | Mail | Multiple identities | - | Y | Y | Y | Y | CODE |
| MAIL-15 | Mail | Thread notes | - | Y | Y | Y | Y | CODE |
| MAIL-16 | Mail | Shared drafts, mentions, approvals | - | - | Y | Y | Y | CODE |
| CAL-01 | Calendar | Events, invites, RSVP, guests, history, busy | Y | Y | Y | Y | Y | CODE |
| CAL-02 | Calendar | Find-a-time | Y | Y | Y | Y | Y | CODE |
| CAL-03 | Calendar | Public booking links (count LIMITS mein) | Y | Y | Y | Y | Y | CODE |
| CAL-04 | Calendar | Overlap Matrix + Focus Ring | - | Y | Y | Y | Y | CODE |
| CAL-05 | Calendar | Meeting cost (£) | - | Y | Y | Y | Y | CODE |
| CAL-06 | Calendar | ICS subscriptions | Y | Y | Y | Y | Y | TODO-VERIFY |
| CAL-07 | Calendar | Event files attach | Y | Y | Y | Y | Y | TODO-VERIFY |
| CAL-08 | Calendar | Meeting rooms (book/schedule/release) | - | - | Y | Y | Y | PROPOSED |
| CAL-09 | Calendar | CalDAV feeds + app passwords | - | Y | Y | Y | Y | PROPOSED |
| PPL-01 | People | Contacts, import, aliases, notes | Y | Y | Y | Y | Y | CODE |
| PPL-02 | People | Leads suggest/import/move to People | - | Y | Y | Y | Y | CODE |
| WRK-01 | Work | Boards, notes, tasks | - | Y | Y | Y | Y | CODE |
| WRK-02 | Work | Work business ledgers (files, calls, recovery) | - | - | Y | Y | Y | CODE |
| CRM-01 | CRM | Accounts, leads, pipeline (1), tasks, reports | - | Y | Y | Y | Y | CODE |
| CRM-02 | CRM | Relationship health, timeline, next-action, promises | - | Y | Y | Y | Y | CODE |
| CRM-03 | CRM | Collab: shared inbox view, mentions, approvals | - | - | Y | Y | Y | CODE |
| CRM-04 | CRM | Revenue risk radar | - | - | Y | Y | Y | CODE |
| CRM-05 | CRM | Activity ledger | - | - | - | Y | Y | CODE |
| CRM-06 | CRM | Intelligence graph | - | - | - | Y | Y | CODE |
| CRM-07 | CRM | Multiple pipelines + custom fields (Pro 1 pipeline/5 fields, Business 5/25, Biz Pro unlimited) | - | Y | Y | Y | Y | PROPOSED |
| CRM-08 | CRM | Duplicate detect + merge | - | Y | Y | Y | Y | PROPOSED |
| CRM-09 | CRM | Web form to lead (Pro 1 form, Business 10, Biz Pro unlimited) | - | Y | Y | Y | Y | PROPOSED |
| CRM-10 | CRM | Lead scoring + assignment rules (round-robin) | - | - | Y | Y | Y | PROPOSED |
| CRM-11 | CRM | Workflow automation / Blueprint (Business 10 rules, Biz Pro unlimited) | - | - | Y | Y | Y | PROPOSED |
| CRM-12 | CRM | Quotes / CPQ (product list, quote, invoice) | - | - | Y | Y | Y | PROPOSED |
| CRM-13 | CRM | Deal approval process (discount limits) | - | - | - | Y | Y | PROPOSED |
| CRM-14 | CRM | Sales cadences (mail/call/task series) | - | - | Y | Y | Y | PROPOSED |
| CRM-15 | CRM | Forecast + quotas (target vs actual) | - | - | Y | Y | Y | PROPOSED |
| CRM-16 | CRM | Territory management | - | - | - | Y | Y | PROPOSED |
| CRM-17 | CRM | Custom CRM dashboards | - | - | Y | Y | Y | PROPOSED |
| ANA-01 | Analytics | Response debt | Y | Y | Y | Y | Y | CODE |
| ANA-02 | Analytics | Thread economics, Deep work | - | Y | Y | Y | Y | CODE |
| ANA-03 | Analytics | Attention leaks, Promise SLA, Forecast | - | - | Y | Y | Y | CODE |
| ANA-04 | Analytics | Team load report (owner/admin) | - | - | Y | Y | Y | CODE |
| CHT-01 | Chat | ANEXOChat (file send 2GB/5GB/7GB) | - | - | Y | Y | Y | CODE |
| CHT-02 | Chat | Video call 1:1 | - | Y | Y | Y | Y | CODE |
| CHT-03 | Chat | Group video (size LIMITS) | - | - | Y | Y | Y | PROPOSED |
| DOC-01 | Docs | CRDT collaborative docs | - | - | Y | Y | Y | PROPOSED |
| ORG-01 | Org | Members, roles, departments, teams, invites | - | - | Y | Y | Y | CODE |
| ORG-02 | Org | Policies, audit log, compliance | - | - | Y | Y | Y | CODE |
| ORG-03 | Org | Org graph + security centre | - | - | Y | Y | Y | CODE |
| DOM-01 | Domains | Company domains + DNS verify (count LIMITS) | Y | Y | Y | Y | Y | CODE |
| SAF-01 | Safety | Safety centre (review queue, sealed evidence, appeals) | - | - | - | Y | Y | CODE |
| SEC-01 | Security | Passkey / two-step sign-in, sessions, history | Y | Y | Y | Y | Y | CODE |
| SEC-02 | Security | Trusted devices + vault (count LIMITS) | Y | Y | Y | Y | Y | CODE |
| SEC-03 | Security | Kill switch, rotate, disown, encryption proof | Y | Y | Y | Y | Y | CODE |
| DAT-01 | Data | Import + Move-In + one-click export | Y | Y | Y | Y | Y | CODE |
| DAT-02 | Data | Account delete / integrity appeal | Y | Y | Y | Y | Y | CODE |
| SET-01 | Settings | Appearance, notifications, privacy, locale, workspace | Y | Y | Y | Y | Y | CODE |
| BIL-01 | Billing | Plan, usage, portal, invoices | Y | Y | Y | Y | Y | CODE |
| PRT-01 | Partners | Partner program (client companies, 20/25/30%) | Y | Y | Y | Y | Y | CODE |
| PRF-01 | Speed | Performance centre (budgets, prefetch, regressions) | Y | Y | Y | Y | Y | TODO-VERIFY |
| SUP-01 | Support | Human support (response time LIMITS) | Y | Y | Y | Y | Y | CODE |
| SUP-02 | Support | Priority Support (included) | - | - | - | - | Y | CODE |
| ENT-01 | Enterprise | Unlimited users, bandwidth cap, Rust-only (NO Bun) | - | - | - | - | Y | PROPOSED |
| AI-01 | AI | LEO AI workspace | ai_soon |  |  |  |  | CODE |
| FND-01 | Founder | Founder/Admin/Release/Perf centres | founder |  |  |  |  | CODE |

## LIMITS (har package ka apna number)

| Limit | Basic | Pro | Business | Biz Pro | Enterprise |
|---|---|---|---|---|---|
| Users cap | 5 | 20 | 60 (founder 26 Oct 09:41) | 570 | unlimited |
| Mailboxes | 3 | 10 | - | - | - |
| Shared storage | 15GB | 300GB | 1.5TB | 15TB (founder paste 09:41; Enterprise number confirm) | 15TB+ (confirm) |
| Attachment | 25MB | 35MB | 45MB | 60MB (founder 09:41) | 100MB |
| Company domains | 1 | 3 | - | - | - |
| Booking links | 1 | 3 | 20 | unlimited | unlimited |
| Trusted devices | 2 | 4 | 10 | 50 | 100 |
| Support response | 72h | 48h | - | - | priority |
| Pipelines (PROPOSED) | - | 1 | 5 | unlimited | unlimited |
| Custom fields (PROPOSED) | - | 5 | 25 | unlimited | unlimited |
| Web forms (PROPOSED) | - | 1 | 10 | unlimited | unlimited |
| Workflow rules (PROPOSED) | - | - | 10 | unlimited | unlimited |
| Group video (PROPOSED) | - | 1:1 | 8 | 40 | 60 |
| ANEXOChat file | - | - | 2GB | 5GB | 7GB |
