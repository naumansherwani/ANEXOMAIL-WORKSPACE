# INV-1 Calendar + Mail + People + Search + Import inventory (read-only audit, 26 Oct 2026)

Method: read lib exports, component doc-headers, plan-surface.ts gates. 'Implemented' = real RPC/hook wiring found in client code; server side NOT re-verified here. Gate column = what code enforces today (not the proposal).

| Area | Feature | What | Evidence | Status | Existing gate |
|---|---|---|---|---|---|
| CAL | Month/Week/Day calendar grid | Month/Week/Day calendar grid (drag to move/resize, overlapping events pack side by side) | TimeGrid.tsx, WeekGrid.tsx, CalendarClassic.tsx, lib/time-grid.ts | Implemented | none (all plans) |
| CAL | Create / edit / delete meetings | Create / edit / delete meetings (title, time, place, notes, calendars, colours) | NewMeeting.tsx, EventDetail.tsx, lib/calendar.ts | Implemented | none |
| CAL | Repeating meetings | Repeating meetings (daily/weekly/monthly nth-weekday/custom, end never/date/count up to 500) | RepeatPicker.tsx, lib/recurrence.ts | Implemented (engine validates RRULE) | none ("every package") |
| CAL | Guests + email invitations with per-guest delivery status | Guests + email invitations with per-guest delivery status | Guests.tsx, lib/calendar-invites.ts, calendar.ts InviteResult | Implemented | none |
| CAL | RSVP | RSVP (accept / tentative / decline) from invite | calendar.ts RsvpResponse, routes/rsvp.tsx | Implemented | none |
| CAL | Guests' local time shown next to each attendee | Guests' local time shown next to each attendee | calendar.ts AttendeeLocalTime, Guests.tsx | Implemented | none |
| CAL | Find-a-time | Find-a-time (best slot across guests' zones, kind-hours scoring) | FindTime.tsx, lib/find-time.ts | Implemented (engine does busy/free) | none |
| CAL | Overlap Matrix | Overlap Matrix (who is working/off/busy per hour across time zones, best window) | OverlapMatrix.tsx, lib/overlap.ts | Implemented | none |
| CAL | Focus Ring | Focus Ring (how full a person's day is) | FocusRing.tsx | Implemented | none |
| CAL | Availability / free-busy + focus windows view | Availability / free-busy + focus windows view | Availability.tsx, calendar.ts useAvailability/useFocusWindows | Implemented (has NotWired fallback) | none |
| CAL | Working hours + out-of-office periods | Working hours + out-of-office periods (synced across devices) | CalSettings.tsx, lib/calprefs.ts | Implemented | none |
| CAL | Multiple calendars with name + colour palette | Multiple calendars with name + colour palette | CalSettings.tsx, calprefs.ts | Implemented | none |
| CAL | Reminders | Reminders (minutes before start) + in-app reminder pop-ups | ReminderWatcher.tsx, calprefs.ts REMINDER_CHOICES | Implemented | none |
| CAL | Public booking page | Public booking page (handle URL, visitor picks slot, no login) | BookingPage.tsx, routes/book.$handle.tsx, lib/booking.ts | Implemented (Rust E59) | none |
| CAL | Manage a booking | Manage a booking (visitor cancel / reschedule by token link) | routes/book.manage.tsx, booking.ts manage* | Implemented | none |
| CAL | Meeting rooms: create rooms, book/release a room for a meeting, double-booking blocked server-side | Meeting rooms: create rooms, book/release a room for a meeting, double-booking blocked server-side | EventRoom.tsx, RoomsSettings.tsx, lib/rooms.ts | Implemented | none |
| CAL | Files on a meeting | Files on a meeting (attach files; type check, virus scan, quota) | EventFiles.tsx, lib/calendar-files.ts | Implemented | none |
| CAL | Meeting cost | Meeting cost (attendee-time cost estimate) | calendar.ts MeetingCost | Implemented (engine-side) | none |
| CAL | Meeting goal + Achieved/Missed outcome colours | Meeting goal + Achieved/Missed outcome colours | lib/goal.ts, EventDetail.tsx | Implemented | none |
| CAL | Outside calendars | Outside calendars (subscribe to holiday / external iCal feeds, read-only, max 10) | OutsideCalendars.tsx, lib/calendar-subs.ts | Implemented | none |
| CAL | Phone/desktop calendar apps via CalDAV | Phone/desktop calendar apps via CalDAV (app keys, max 10; read-only) | PhoneCalendar.tsx, lib/caldav.ts | Implemented (read-only, E80) | none |
| CAL | Calendar feed links | Calendar feed links (subscribe URL, max 5) | PhoneFeed.tsx, caldav.ts MAX_FEED_LINKS | Implemented | none |
| CAL | Import .ics from Google/Zoho/Outlook/Apple | Import .ics from Google/Zoho/Outlook/Apple (last 30d / next 180d, max 500 events) | IcsImport.tsx, lib/ics.ts | Implemented | none |
| CAL | World clocks + globe with day/night | World clocks + globe with day/night | WorldClocks.tsx, GlobeView.tsx, lib/sun.ts, lib/places.ts | Implemented (no network) | none |
| CAL | Time bar | Time bar (clock strip across zones) | TimeBar.tsx | Implemented | none |
| CAL | Trip card | Trip card (travel mode: reminders held while in transit; mail never held) | TripCard.tsx, lib/travel.ts | Implemented | none |
| CAL | Device clock check + own connection speed | Device clock check + own connection speed | ClockHealth.tsx, lib/clock-sync.ts | Implemented (private to user) | none |
| CAL | Billing deadline line in clock popover | Billing deadline line in clock popover (trial/renewal date) | BillingDeadline.tsx, lib/deadline.ts | Implemented | none |
| CAL | Deep link into a meeting | Deep link into a meeting (/app/calendar?date=&event=) | lib/calendar-jump.ts | Implemented | none |
| CAL | History search over past meetings | History search over past meetings (years back) | app.search.tsx, HistoryResults.tsx, lib/history.ts | Implemented | none |
| MAIL | Inbox / folders list with counts, live updates | Inbox / folders list with counts, live updates (WebTransport, poll fallback) | routes/app.mail.$folder.tsx, mail.ts useThreads/useMailLive/useFolderCounts | Implemented | none |
| MAIL | Read thread | Read thread (conversation view) with safe HTML (sandboxed iframe) | app.mail.$folder.$threadId.tsx, SafeMailBody.tsx | Implemented | none |
| MAIL | Inbox categories | Inbox categories (Primary/Updates/People/Promotions) | mail.ts THREAD_CATEGORIES | Implemented | none |
| MAIL | Labels | Labels | mail.ts MailLabel/useLabels, MailRail.tsx | Implemented | none |
| MAIL | Multiple mailboxes/accounts + switch | Multiple mailboxes/accounts + switch | mail.ts useAccounts | Implemented | none |
| MAIL | Per-address colour identity chips | Per-address colour identity chips (domain colours) | lib/mail-identity.ts, AddressChip.tsx | Implemented | none |
| MAIL | Archive / delete / star / mark read / move | Archive / delete / star / mark read / move (thread actions) | mail.ts useThreadAction | Implemented | none |
| MAIL | Keyboard shortcuts in inbox | Keyboard shortcuts in inbox (j/k, actions) | app.mail.$folder.tsx L151-174 | Implemented | Pro+ (showProMailTools) |
| MAIL | Snooze thread to a time | Snooze thread to a time | ThreadHeaderActions.tsx, mail.ts snoozePresets | Implemented | Pro+ (FeatureGate requires=pro) |
| MAIL | Private note on a thread | Private note on a thread | ThreadNote.tsx | Implemented | Pro+ (showProMailTools) |
| MAIL | Per-thread analytics | Per-thread analytics (opens, reply rate, best send hour, recipient timezone) | ThreadInsights.tsx, compose.ts useThreadInsights | Implemented (server-truth) | Pro+ per formula; component gate not found |
| MAIL | Thread rescue | Thread rescue (revive stuck / unanswered threads) | ThreadRescue.tsx | Present; no doc header, wiring not verified | not found |
| MAIL | Thread header: link to Work item / Chat / Discuss in chat | Thread header: link to Work item / Chat / Discuss in chat | ThreadHeaderActions.tsx, DiscussInChat.tsx, QuoteInChat.tsx | Implemented | showWork + showChat |
| MAIL | Inline reply / reply-all / forward inside the thread | Inline reply / reply-all / forward inside the thread | InlineReply.tsx | Implemented | none |
| MAIL | Outbox | Outbox (queued/holding/scheduled mail) | routes/app.mail.outbox.tsx | Implemented | none |
| MAIL | Empty-inbox welcome | Empty-inbox welcome (copy address, first-mail, import prompts) | InboxWelcome.tsx | Implemented | none |
| MAIL | Compose studio | Compose studio (to/cc/bcc, subject, body, autosave drafts every 3s, versions) | ComposeStudio.tsx, compose.ts useSaveDraft/useDraftVersions | Implemented | none |
| MAIL | Undo send | Undo send (server-side hold, 30s) | compose.ts useScheduleSend/cancelScheduledSend | Implemented | none (all plans) |
| MAIL | Schedule send | Schedule send (pick date/time) | ComposeStudio.tsx L944-990 | Implemented | Pro+ (proMail) |
| MAIL | Templates with {{variables}} | Templates with {{variables}} | compose.ts useTemplates/useSaveTemplate | Implemented | Pro+ (proMail) |
| MAIL | Snippets | Snippets (shortcut text expansion) | compose.ts useSnippets/useDeleteSnippet | Implemented | Pro+ (proMail) |
| MAIL | Signatures | Signatures (per identity, default) | compose.ts useSignatures | Implemented | none found |
| MAIL | Pre-send confidence scan | Pre-send confidence scan (missing variable, forgotten attachment, external domain, risky tone, broken link, wrong identity) | compose.ts useSendConfidence | Implemented | none found |
| MAIL | Follow-up reminders | Follow-up reminders (promise tracker) | compose.ts useCreateFollowUp/useFollowUps | Implemented | none found |
| MAIL | Writing-style word prediction | Writing-style word prediction (ghost text) | GhostTextArea.tsx, lib/mail-predict.ts | Implemented (Rust primary) | none found |
| MAIL | Reading time / reading level meter | Reading time / reading level meter | compose.ts readingStats | Implemented | none |
| MAIL | Send from a chosen identity | Send from a chosen identity (multiple identities) | mail.ts useIdentities | Implemented | Pro+ (showMultipleIdentities) |
| MAIL | File attachments on send | File attachments on send (type block-list, virus scan, dedupe, quota, progress) | lib/mail-attachments*.ts | Implemented | per-plan size cap (25/35/45/60/100 MB in v6 - code still reads server limits) |
| MAIL | Cross-device draft handoff | Cross-device draft handoff (continue draft on another device) | lib/handoff.ts | Implemented in code, live test pending | none found |
| MAIL | AI compose: rewrite/tone/subject/translate/coach + Jimmy escalation | AI compose: rewrite/tone/subject/translate/coach + Jimmy escalation | compose.ts useLeoCompose/useAskJimmy | Implemented but hidden on workspace; shown only on ai host (leoUi = aiHost) | AI host only |
| PPL | People list with search + smart filters | People list with search + smart filters (Everyone/VIP/Customers/Vendors/Investors/At risk/Unanswered/Dormant) | routes/app.people.tsx, contacts.ts SMART_FILTERS | Implemented | none (CRM link needs showCrm) |
| PPL | Contacts auto-built from real mail | Contacts auto-built from real mail (derived, relationship health New/Growing/Stable/At risk/Dormant) | contacts.ts Relationship | Implemented | none |
| PPL | Contact profile | Contact profile (reply time, tags, edit, details) | ContactProfile.tsx, contacts.ts useUpdateContact | Implemented | none |
| PPL | Contact tags | Contact tags (add/remove, counts) | contacts.ts useContactTags/useContactTagAction | Implemented | none |
| PPL | Contact + company timelines | Contact + company timelines (every touch) | Timeline.tsx, useContactTimeline/useCompanyTimeline | Implemented | none |
| PPL | Companies | Companies (rolled up by domain) + company profile | CompanyProfile.tsx, contacts.ts useCompanies | Implemented | none |
| PPL | Contacts import CSV/vCard from Google/Outlook/Zoho/Apple/LinkedIn | Contacts import CSV/vCard from Google/Outlook/Zoho/Apple/LinkedIn (max 5000, batches 500) | ContactsImport.tsx, lib/contacts-import.ts | Implemented | none |
| PPL | Link to full CRM | Link to full CRM | routes/app.people.tsx L58 | Implemented | showCrm |
| SRCH | Universal search | Universal search (mail, people, more) + command palette | routes/app.search.tsx, contacts.ts useUniversalSearch, components/app/CommandPalette.tsx | Implemented | none |
| SRCH | Calendar history search | Calendar history search (jump to meeting) | HistoryResults.tsx, lib/history.ts | Implemented | none |
| MIG | Bring old mail via IMAP + app password | Bring old mail via IMAP + app password (live progress, cancel, report) | ImportMailPage.tsx, lib/migration.ts, migration-report.ts | Implemented (Rust engine only; needs E-series SQL) | none found |
| MIG | Import page | Import page (/app/import) entry for switching | routes/app.import.tsx | Implemented | none |
| MOVE | Move-In service request | Move-In service request (we move your company): capacity, request, status | routes/app.movein.tsx, routes/move-in.tsx, lib/movein.ts | Implemented | none (paid one-off) |
| DOM | Company domains + DNS records | Company domains + DNS records (TXT/MX/SPF/DKIM/DMARC), addresses (mailbox/shared/alias) | lib/domains.ts, routes/app.domains.tsx | Implemented (E15) | showDomains = Business account kind |

Rows: 74. Area keys: CAL calendar, MAIL mail+compose, PPL people, SRCH search, MIG migration, MOVE move-in, DOM domains.

## Notable
1. Calendar has NO plan gate anywhere (even says 'every package'); only Pro mail tools are gated.
2. AI compose (rewrite/tone/translate/Jimmy) exists in ComposeStudio but is hidden unless on ai host (leoUi = aiHost).
3. Several mail features (signatures, confidence scan, follow-ups, prediction, thread insights) have no gate found in components - ungated today though formula doc says Pro+.
