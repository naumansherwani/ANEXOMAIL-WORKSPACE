# PP1 — POORI WEBSITE FEATURE -> PACKAGE TABLE (CEO proposal 26 Oct 05:00 PKT; FOUNDER APPROVE BAQI)
Source: docs/claude/inventory/INV-1/2/3 (213 features, code-based). Legend: B=Basic, P=Pro, Bu=Business, BP=Business Pro, E=Enterprise | Personal: PB=Basic, PP+=Pro+, PPr=Premium. "all"=sab. Personal = ek insaan (Org/Domains/shared inbox nahi). Per-month flat + user cap (5/20/60/570/unlimited).

| # | Feature group | Gate (B / P / Bu / BP / E) | Personal (PB / PP+ / PPr) |
|---|---|---|---|
| 1 | CALENDAR core: grid month/week/day, meetings, repeat, reminders, RSVP+invites, guest local time, working hours/OOO, multi-calendars, ICS import, world clocks/globe, time bar, trip card, clock check, deep link, calendar history search, billing-deadline line | all | all |
| 2 | CalDAV phone/desktop sync + feed links + outside calendars | all | all |
| 3a | CALENDAR generous (founder 04:39: Basic ko achay features): Find-a-time + 1 public booking link + manage booking | all (Basic bhi) | all |
| 3b | CALENDAR Pro: unlimited booking links, Overlap Matrix, Focus Ring, Availability/focus windows, meeting goal, meeting cost, files on meeting | P+ | PP+, PPr |
| 5 | CALENDAR Business (sab kuch): meeting rooms/resources + sab upar wale; BP aur Enterprise ko bhi sab (kabhi kam nahi) | Bu+ | no |
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
| 21a | ANALYTICS: Response debt (kaun jawab ka intezar kar raha) | all (Basic ka hook) | all |
| 21b | Analytics: thread economics, deep work | P+ | PP+, PPr |
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
| 35 | Storage size (shared pool) / users cap | 15GB (3 mailboxes),5 / 300GB,20 / 1.5TB,60 / 10TB,570 / 15TB,unlimited | 5GB / 10GB / 1TB, 1 user |
| 36 | Bandwidth overage (hidden, bill-only) | fair-use / fair-use / 10TB@£12 / 30TB@£11 / 50TB@£10 | no |
| 37 | Priority Support (£790 add-on) | add-on / add-on / add-on / add-on / INCLUDED | no |
| 38 | CRDT collaborative docs (when built) | Bu+ | NO (CEO: Personal mein ek hi insaan, saath type karne wala koi nahi) |
| 39 | Founder/Admin/Perf/Launch | founder host only | -- |

## Code ghaltiyan jo gate unify karte waqt theek hongi (P5)
Video: DB chat_video_allowed (founder+BP) vs UI Pro+ vs chat Bu+ -> sab Bu+. Analytics: gate hai hi nahi. Work header Basic ko TaskBoard kehta hai lekin route Pro se neeche block karta hai. Enterprise rank code mein nahi. Mail features #8 abhi ungated (formula Pro+ kehta hai).
## Landing mistakes (INV-3 mein 23, file:line): index.tsx:49 "From £23 per user"; plans.tsx old prices+no Enterprise column; plans.ts monthly 23/46/97 "/user/month", Business 30 users, BP "unlimited users", AI £400/1500/4000; billing-platform.ts+app.billing.tsx price_per_seat; enterprise.tsx = £790 Priority Support page (clash); plans.tsx:233 Premium 5GB (founder: 4GB).

## Founder 04:39 PKT — jawab (CEO faisle)
- Calendar: Basic ko generous (Find-a-time + 1 booking link), Pro ko zyada, Business+ ko sab. Competitor check (Rule 54) landing copy se pehle baqi: Google/Zoho calendar ka free/paid hissa verify karna.
- Analytics: Basic = response debt; Pro = + thread economics + deep work; Business+ = baqi.
- CRDT docs Personal ko NAHI.
- 23 'ghaltiyan' ka matlab: purani qeematein/per-user lafz jo 2 ghantay pehle ke founder faislon se UPDATE hone baqi hain (P2/P3) -- ghalti nahi, update-list.
- Priority Support vs Enterprise: Priority Support = paid add-on 790 GBP/mo (tez insani support, named contact, 2-business-day response, quarterly review). Naya Enterprise = poora package 15,000 GBP. CEO faisla: purani /enterprise page ka naam 'Priority Support' (/priority-support), naya /enterprise page naye package ka; Enterprise mein Priority Support FREE included; baqi plans ke liye add-on rahe. (Founder veto.)
- Video unify (Bu+) aur booking: founder jawab baqi.

## Founder 04:48 PKT — video + booking links + KAAM KI TARTEEB
- **Video (CEO reading of founder, veto baqi):** Pro = standalone video call **720p** (ANEXOChat features ke baghair, takrao nahi); Business = 720p + ANEXOChat ke saath (group 8); Business Pro = **2K** + top-notch features (group 40); Enterprise = **poori website ka scale, sab kuch, 8K ladder tak** (group 60). Basic = video nahi. Personal Pro+ = Pro-jaisa 720p+chat, Premium = 2K.
- **Booking links:** Basic 1, Pro 3, Business 20, Business Pro unlimited, Enterprise unlimited (halki fair-use limit).
- **Tarteeb (founder rule): ek ek page.** Pehle Business ke package plans (monthly + yearly), pehle Basic phir Pro/Business/BP/Enterprise; phir Personal Basic/Pro+/Premium. Har package ke features pehle CHAT mein likho -> founder approve -> phir repo. Gates tab tak nahi jab tak puri website ke features read na hon (INV-1/2/3 se read ho chuki).
- Yearly rule (plans.ts): Basic/Pro = monthly x11, Business/BP = x10. Enterprise yearly: proposal x10 = 150,000 GBP (founder confirm).

## Founder 04:56 PKT — CORRECTIONS (meri ghalti: Pro aur Personal Pro+ mix kiye)
- **Business ke Pro mein ANEXOChat DOOR DOOR TAK NAHI. Pro mein video bhi NAHI** (video ANEXOChat ke saath aati hai). ANEXOChat + ANEXOVideoCall (720p) **Business se shuru**; Business Pro 2K; Enterprise baad mein. Upar ki 'Pro 720p standalone video' line VOID.
- **Personal HOLD**: Personal ke bohot masle; alag UI; Personal Gmail ke upar outbox pe bana hai; uske codes + 3 packages ki phases shuru se alag meeting mein, latest technology. Jab tak founder na kahe Personal par koi kaam/gate NAHI.
- **Enterprise abhi ZERO**: kuch likha nahi; codes duniya ki advanced technology par; bug nahi chalega; baad mein alag plan.
- **Business Basic APPROVED** (founder 04:56): 5 users, 3 mailboxes, 15GB shared (founder 05:45 correction, 25GB galat tha), 25MB attachment, 2 trusted devices, 1 booking link; company domain + undo send Basic mein rahein. Price per month (per-user nahi): £40/mo, yearly £440 (x11, 1 month free) -- founder approve baqi.
- Landing Basic features jo merge honge: 1 company domain, thread ownership, Cmd+K search, free aliases (no extra seat), human support 72h response.
