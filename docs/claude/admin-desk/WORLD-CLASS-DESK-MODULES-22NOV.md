# WHAT A WORLD-CLASS COMPANY ADMIN DESK HOLDS, AND WHERE EACH PART LIVES (his 22 Nov 2026 02:49 order)
Method: the common ground of enterprise help-desk and contact-centre suites (omnichannel inbox, case management, SLA, routing, macros, knowledge base, CRM view, QA scoring, workforce management, analytics, audit), see [Hiver enterprise helpdesk](https://hiverhq.com/blog/enterprise-help-desk-software), [Featurebase enterprise help desk 2026](https://www.featurebase.app/blog/enterprise-help-desk-software), [Freshdesk Omni admin](https://www.freshworks.com/freshdesk/omni/streamline-admin), [Deskpro features](https://www.deskpro.com/features); then made ANEXOMAIL-specific: post-quantum mail, hash-chained audit, zero-trust staff, plan-based lanes, Rule 52 signed calls. Only Finance and Polar stay in the founder app.
Code: founder-web/src/desk/modules/<group>/<key>/{meta.ts,README.md}, one list in modules/registry.ts (the rail reads it). Every module starts `planned` and turns `live` only when WIRED + REAL with proof.
| Group | Module | What | Technology | Phase | Moves from founder |
|---|---|---|---|---|---|
| Anexomail Workspace | Inboxes | Company mailboxes: hello, moveyourbusiness, resolved; billing restricted folder; leo automation; noreply send-only; support@ banned | Rust axum, Postgres RLS fadm_mailbox, WASM kernel, ML-KEM mail | R4-2 | Mail Desk |
| Anexomail Workspace | Cases | Every user problem as a case: owner, status, priority, history, one-click assign, close with root cause | Rust, Postgres RLS + relation tuples (AD2), kernel signed calls | R3b | new |
| Anexomail Workspace | Replies | Saved replies and snippets with variables, per team, versioned | Tiptap 3, Postgres, Rust | R4-4 | new |
| Anexomail Workspace | Routing | Rules that put a case in the right queue by plan, language, topic and skill; load balancing | Rust rules engine, Postgres policy tables | R3b | new |
| Anexomail Workspace | SLA clocks | Plan-based first-response and resolution clocks, breach warnings, pause rules | Rust scheduler, Postgres, plan rows (R3p) | R3f | new |
| Anexomail Workspace | Automations | Auto-acknowledge (RFC 3834), triggers, escalation timers, follow-up reminders | Rust, RFC 3834, Postgres | R3c | new |
| Admin Desk | Managed Move-In | Customer onboarding cockpit: slots, cut-overs, mailbox and DNS checks | Rust, DNS probes, Postgres, kernel | R4-11 | Managed Move-In |
| Admin Desk | People | Organisations, users, devices and permissions: metadata only, never message content | Rust, Postgres RLS, signed read doors | R5a | People |
| Admin Desk | CRM | Leads, accounts, pipeline and a 360 view per company, company-style (his 22 Nov word) | Postgres, Rust, kernel | R-CRM | New customers card |
| Admin Desk | Plans | Which plan a company is on and what it entitles (support lane, response hours, priority) | Signed Polar webhook receiver (HMAC), Postgres fadm_plans | R3p | new |
| Admin Desk | Knowledge | Help articles, suggested article per case, gaps report | Postgres full-text search, Rust | R6 | new |
| Admin Desk | View as user | Look at a user's account with his consent, time-boxed, read-only, loud in the ledger | Relation tuples (JIT), two-person rule, hash ledger | R5c | new |
| Admin Desk | Data requests | Export and delete requests with deadline clock and proof of completion | Rust jobs, Postgres, ledger | R5d | new |
| Admin Desk | Abuse and safety | Spam and abuse reports, blocks, review queue | Rust, Postgres, ClamAV for files | R5e | new |
| Admin Desk | Deliverability | Bounces, complaints, DKIM/SPF/DMARC, MTA-STS and DANE health per company | Rust, DNS, Postgres | R4-10 | Mail Desk |
| Admin Desk | Incidents | Notice to affected companies, status messages, timeline | Rust, Postgres, signed notices | R5f | new |
| Admin Desk | Escalations | Hand a case to engineering with context and an owner; on-call roster | Rust, Postgres | R5g | new |
| Admin Desk | Quality | CSAT and review scoring of replies, coaching notes | Postgres, Rust | R6b | new |
| Company | Team | Staff accounts, joiner, mover, leaver, recovery, access review | Rust, webauthn-rs, AD2 SQL (live) | ON1-ON8 | new |
| Company | Shifts | Shift hours, capacity, leave; office IP list | Postgres (AD2 fadm_shift, fadm_ip_allow), Rust | ON10 | new |
| Company | Analytics | Real KPIs only: first response, resolution time, backlog, reopen rate, per team | Postgres views, Rust, Three.js light charts | R3g | new |
| Company | Bridge | The Desk's own bridge: mail lanes, queue flow, alerts, in the Desk's needs | Three.js, kernel, Rust | R4-1b | Bridge |
| Company | Alerts | Circuit-breaker freezes, SLA breaches, key events (Desk's own bridge, never the Founder Bridge) | Postgres fadm_alert, Rust | ON11 | new |
| Company | Policy | Who may do what: permits, forbids, AAGUID hardware list, break-glass | Postgres policy engine (AD2), Rust | ON9 | new |
| Company | Systems | Per-tenant health, capacity and speed | Rust probes, Postgres | R5b | Systems |
| Company | Audit | The append-only hash-chained ledger, verify, export | Postgres ledger (AD1), transparent log later, Rust | R3g | new |
