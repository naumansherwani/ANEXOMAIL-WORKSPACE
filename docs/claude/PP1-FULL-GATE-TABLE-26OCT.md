# PP1 — POORI WEBSITE FEATURE -> PACKAGE TABLE (CEO proposal 26 Oct 05:00 PKT; FOUNDER APPROVE BAQI)
Source: docs/claude/inventory/INV-1/2/3 (213 features, code-based). Legend: B=Basic, P=Pro, Bu=Business, BP=Business Pro, E=Enterprise | Personal: PB=Basic, PP+=Pro+, PPr=Premium. "all"=sab. Personal = ek insaan (Org/Domains/shared inbox nahi). Per-month flat + user cap (5/20/60/570/unlimited).

| # | Feature group | Gate (B / P / Bu / BP / E) | Personal (PB / PP+ / PPr) |
|---|---|---|---|
| 1 | CALENDAR core: grid month/week/day, meetings, repeat, reminders, RSVP+invites, guest local time, working hours/OOO, multi-calendars, ICS import, world clocks/globe, time bar, trip card, clock check, deep link, calendar history search, billing-deadline line | all | all |
| 2 | CalDAV phone/desktop sync + feed links + outside calendars | all | all |
| 3 | Smart scheduling: Find-a-time, Overlap Matrix, Focus Ring, Availability/focus windows, meeting goal, meeting cost | P+ | PP+, PPr |
| 4 | Public booking page + manage booking, files on a meeting | P+ | PP+, PPr |
| 5 | Meeting rooms/resources | Bu+ | no |
| 6 | MAIL core: folders, read thread, categories, labels, multi-mailbox, identity chips, archive/delete/star/move, outbox, inline reply, compose, undo send, signatures, attachments (25/35/45/60/100MB), draft autosave+versions | all | all |
| 7 | Pro mail tools: snooze, schedule send, templates, snippets, thread notes, inbox shortcuts, multiple identities | P+ | PP+, PPr |
| 8 | Pre-send confidence scan, follow-up reminders, thread analytics, word prediction, reading meter, cross-device draft handoff, thread rescue | P+ | PP+, PPr |
| 9 | AI compose (rewrite/tone/translate/coach/Jimmy) | NO (ai.anexomail.com only, coming soon July 2027) | no |
| 10 | PEOPLE: list+filters, auto-contacts, profile, tags, companies, timelines, CSV/vCard import | all | all |
| 11 | Universal search | all | all |
| 12 | Import old mail (IMAP), Move-In request | all | all |
| 13 | Company domains + DNS/mailboxes/aliases | all (business kind) | no |
| 14 | name@anexomail.com address | all | all |
| 15 | WORK: tasks board, notes, promise inbox, follow-through, promise recovery, goals+deadlines | P+ | all |
| 16 | Team report + team time | Bu+ | no |
| 17 | Dashboard, setup checklist, install hint, expiry watch, live updates | all | all |
| 18 | CRM base: overview, relationships, leads, pipeline, deal->work, attach thread, accounts, tasks, reports, memory/insights/health | P+ | PB: People only; PP+, PPr full |
| 19 | CRM collab: shared work, approvals, team permissions, audit, risk | Bu+ | PP+, PPr |
| 20 | CRM activity timeline+evidence, relationship graph, capture | BP+ | PP+, PPr |
| 21 | ANALYTICS: response debt, thread economics, deep work | P+ | PP+, PPr |
| 22 | Analytics: forecast, attention leaks, promise SLA, team analytics, report figures | Bu+ | PP+, PPr |
| 23 | ANEXOCHAT core: 1:1+group, ticks, live push, images, resumable big files, file context, pop-out, continuity, atmosphere/sound | Bu+ (file 2GB / 5GB / 7GB) | PP+ 2GB, PPr 4GB |
| 24 | Chat work-layer: decision ledger, outcome timeline, conversation health, receipts, handover pack, email<->chat bridge, work strip/chain, chat safety/report | Bu+ | PP+, PPr |
| 25 | ANEXOVIDEOCALL: 1:1 + adaptive quality (8K->480p), pre-warm, audio-only survival, connect report, telemetry | Bu+ (UNIFY: abhi 3 alag gates) | PP+, PPr |
| 26 | Group call (SFU): participants | Bu 8 / BP 40 / E 60 | PP+ 8, PPr 40 |
| 27 | Call business record | BP+ | PPr+PP+ |
| 28 | Screen share, recording, live captions | NOT BUILT -> "coming soon", gate baad mein | -- |
| 29 | ORG centre: members/invite, roles, departments, policies, hash-chained audit, compliance export, teams | Bu+ (business kind) | never |
| 30 | Org graph, org-wide device kill/break-glass | BP+ | never |
| 31 | SECURITY: overview, devices+trust, geo/velocity freeze, sessions kill-all, login history, encryption view, passkey+recovery codes, account-integrity warnings (email+push), appeals | all (device vault slots 2/4/10/50/100) | all (2 / 10 / 50) |
| 32 | DNS/TLS hashed proof export | Bu+ | no |
| 33 | SAFETY centre: review queue, sealed evidence, history | BP+ | PP+, PPr |
| 34 | STORAGE meter+quota states, BILLING (Polar), trial (2 days), data export ZIP, account/profile, settings (appearance, notifications, privacy, workspace, health, history), locales, devices+offline+PWA | all | all |
| 35 | Storage size (shared pool) / users cap | 25GB,5 / 300GB,20 / 1.5TB,60 / 10TB,570 / 15TB,unlimited | 5GB / 10GB / 1TB, 1 user |
| 36 | Bandwidth overage (hidden, bill-only) | fair-use / fair-use / 10TB@£12 / 30TB@£11 / 50TB@£10 | no |
| 37 | Priority Support (£790 add-on) | add-on / add-on / add-on / add-on / INCLUDED | no |
| 38 | CRDT collaborative docs (when built) | Bu+ | founder decide |
| 39 | Founder/Admin/Perf/Launch | founder host only | -- |

## Code ghaltiyan jo gate unify karte waqt theek hongi (P5)
Video: DB chat_video_allowed (founder+BP) vs UI Pro+ vs chat Bu+ -> sab Bu+. Analytics: gate hai hi nahi. Work header Basic ko TaskBoard kehta hai lekin route Pro se neeche block karta hai. Enterprise rank code mein nahi. Mail features #8 abhi ungated (formula Pro+ kehta hai).
## Landing mistakes (INV-3 mein 23, file:line): index.tsx:49 "From £23 per user"; plans.tsx old prices+no Enterprise column; plans.ts monthly 23/46/97 "/user/month", Business 30 users, BP "unlimited users", AI £400/1500/4000; billing-platform.ts+app.billing.tsx price_per_seat; enterprise.tsx = £790 Priority Support page (clash); plans.tsx:233 Premium 5GB (founder: 4GB).
