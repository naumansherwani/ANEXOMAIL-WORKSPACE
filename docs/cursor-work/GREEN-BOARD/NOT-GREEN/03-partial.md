# NOT-GREEN 3 — PARTIAL (aadha green)

21 Oct 2026, asli ghadi ~06:50 PKT · repo HEAD b18c4b9+ · source: MASTER-BUILD-PLAN.md, MASTER-GAP-LEDGER.md, loophole-ledger.md, blueprint G-table, DONE-DO-NOT-REPEAT.md, PROMISES.md, TECH-MAP.md + repo grep (src/, server/).

| Item | Kaam | Kya hai | Baqi |
|---|---|---|---|
| Plan P2 | Real mail counters (unread/starred/today) | Panels.tsx/Greeting.tsx; Basic dashboard live dekha (20 Oct 22:00). 'starred/today' counters ka live saboot nahi | Pro/Business/Business Pro par dashboard numbers check (G41) |
| Plan P3 | Read receipts (open tracking) | ThreadInsights.tsx (opens/response rate server se) maujood; per-message 'kab/kahan khola' receipt UI ka saboot nahi | scope tay karna + live test |
| Plan P3 | Thread intelligence auto-labels | server/routes/mail-predict.ts (word prediction) hai; Receipt/Newsletter/Important auto-label ka alag code nahi mila | TODO decide |
| Plan P3 | Keyboard-first (har action) | ⌘K CommandPalette + keydown handlers app.mail.$folder.tsx; single-key map (c r f e s # / g i g s g d ?) ka poora saboot nahi | map audit + live test |
| Plan P4 | Rich text editor (bold/italic/lists/links) | ComposeStudio.tsx mein formatting hai (plain/HTML compose); full rich editor ka alag saboot nahi | live compose test |
| Plan P4 | Cinematic send animation (sweep) | blueprint ka sweep effect: MessageStream/WorkspaceLoader mein animations; Compose send sweep ka alag saboot nahi | live dekhna |
| Plan P5 | Attachment preview inline (PDF/image) | SafeMailBody.tsx images; G38b download chip GREEN; inline PDF preview nahi mila | build/decide |
| Plan P5 | Thread actions: star/archive/snooze/delete/print | ThreadHeaderActions.tsx (Done/Archive/Meeting/Snooze/Label HScroll live); print nahi mila; star/delete ka live saboot nahi | audit |
| Plan P6 | Relationship intelligence ('30 din se baat nahi') | Profile/Timeline mein hai; 30-day nudge ka alag saboot nahi | decide + test |
| Plan P7 | Month view (toggle) | TimeGrid/WeekGrid mein month hits; live toggle saboot nahi | live check |
| Plan P7 | Attendees + RSVP | Guests.tsx + /rsvp link; guest ka Gmail/Outlook 'Yes' reply (iMIP) = G26 TODO (B7) | B7 |
| Plan P7 | Email → Calendar (meeting request detect) | IcsImport.tsx (.ics) hai; mail se meeting-request auto-detect ka saboot nahi | decide |

| G | Kaam | Kya hai / baqi |
|---|---|---|
| G1 | Attachments bhejna | Rust attach 12 tests + E48/E49 GREEN (23:50); Brain attach installed; Compose attach SEND live test baqi (C3) |
| G4 | R1 mail.send / R3 typed contract / R4 direct pool / R5 push | R1 GREEN (B3 06:00); R5 READY (B4, install baqi); R3 + R4 TODO |
| G5 | /api/mail/send Bun fallback identity ignore | Rust send identity-checked (GREEN); Bun fallback par identity check = CHECK |
| G14 | SECURITY L25 crm tenant isolation live | Brain CRM tenant isolation installed (02:00, health 200, unauth 401); crm-tenant-check.sh live baqi |
| G18 | Founder workspace Rust-only (Rule 22) | B5 se 15 procs Rust; baqi: AI chat (B8) |
| G19 | Switch-journey gaps (a Integrations migrate, b…) | G19a = G30 worker (code+installer; 'Import mail' screen dikhi); baqi parts audit |
| G30 | Gmail/Outlook IMAP import worker | code+installer; live saboot ka record CHECK; OAuth app = Phase 2 founder |
| G33 | Wade ka audit (PROMISES.md) | 12 rows + #13/#14; 'VERIFY' rows baqi (3,5,6,7,9 …) |
| G34 | HMAC device hash | E42 SQL GREEN; purane hash migrate (device-hash-migrate.sh) chala ya nahi = CHECK (C5) |
| G35 | Passkey lazmi + recovery codes | B2 Rust GREEN; E43 live; banner/gate live check + 27 Oct deadline (test accounts exempt: brain-passkey-exempt.sh) |
| G38 | Compose attachments bhejna | see G1 |
| G39 | Family = real buyer / lifetime label | E41 GREEN; 'Lifetime access' label live check (Humza) C8 |
| G41 | Har package par 390/820/1440 live test | Basic GREEN (04:30). Pro/Business/Business Pro TODO |
