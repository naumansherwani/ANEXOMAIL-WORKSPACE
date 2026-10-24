- 22 Oct 2026: #3 iMIP code written (imip_core.rs, deliver hook, rsvp_via in cal_glue, Guests label). NOT green until server output + live Gmail test.
- 22 Oct 06:53: #3 iMIP E60 SQL + Rust cal + Rust deliver + web = server par INSTALLED (founder output). Dobara install mat karwana. Baaki: live Gmail Yes test. Rule: records likhne ke BAAD manifest-sync dobara (pull "KUCH GALAT" ki wajah).
- 22 Oct 06:56 founder correction: G16 billing portal (B6 Rust billing.portal) kal shaam bana hua hai, GREEN — ledger D6 theek kiya. Dobara 'baqi' mat likhna.
- 22 Oct 06:57 GALTI: maine G16 ko 'GREEN' likh diya tha — founder: portal bana nahi. Sach: sirf B6a (Manage billing -> Polar-hosted portal). In-app portal ka scope founder se pakka hone tak 'BANA NAHI'.
- 22 Oct 07:00 G16 = docs/claude/BILLING-PORTAL-BLUEPRINT.md (founder ne kal diya). Bana sirf P0+P1 (+B6a Polar-hosted button). P2–P8 BANA NAHI. 'Rust billing.portal GREEN' ko G16 ka poora kaam mat samajhna.
- 22 Oct 07:20 BUG (Rule 29): live calendar_attendees mein created_at column NAHI (CHECK_CAL_GUESTS ne saboot diya) — cal_glue attendee_rows/attendees_of_many 'order=created_at.asc' PostgREST error deta tha, .ok() ne chhupa diya => guest list khali. Fix: order=address.asc + error log. Rust cal reinstall baaki, phir iMIP test dobara.
- 22 Oct 07:30: #3 ka asli-pipe saboot script imip-reply-proof.sh push; founder ka output aane par GREEN. Gmail RSVP-bar sharT nahi.
- 22 Oct 07:47 #3 iMIP = GREEN (imip-reply-proof.sh founder output A/B/C/D sab theek). Dobara test mat mangna. Agla: founder ka naya hukm — Outlook-jaisa mail UI/feature map (kaun si feature kis package, kahan).
- 23 Oct 08:30 CalDAV #6 C1 BANA (server par BAAQI): dav_core.rs (14 tests pass sandbox), dav_glue.rs (compile server par hoga; installer build fail par rollback), installer module `dav`, caddy-caldav.sh (plan/apply/rollback; insert snapshot par dry-run OK), PhoneCalendar.tsx + lib/caldav.ts (2 bun tests; 367 total pass). E80 sandbox GREEN. Founder ne abhi KUCH NAHI chalaya. C2 (likhna, sync-collection) BANA NAHI. Live check baaki: curl PROPFIND + phone.
- 23 Oct 08:25 CalDAV C1 server par: E80 GREEN, Rust dav module build+health OK, Caddy apply OK (301/401). Dobara mat chalana. Baaki: Caddy re-apply (DAV header), Settings password, phone test.
- 23 Oct 08:30 CalDAV Caddy DAV header re-apply GREEN (OPTIONS dav: 1, calendar-access). Server taraf mukammal; baaki phone test.
- 23 Oct 08:40 Classic calendar phone overflow fix (rows wrap, Panel overflow-x-hidden). Live phone check baaki (founder).
- 23 Oct 08:55 Mail-open crash hardening: normalizeThread + retry (useThread). Asli error founder ke account se baaki.
- 23 Oct 09:00 Calendar phone toolbar redesign (⋯ menu, 44px targets, full-width view switch). Live phone check baaki (founder screenshot).
- 23 Oct 09:05 Phone calendar toolbar GREEN (founder screenshot); ListPanel w-full fix pushed, live check baaki.
- 23 Oct 09:15 App pull-to-refresh (PullRefresh.tsx, data-only, no reload). Live phone check baaki (founder).
- 23 Oct 09:40 MOBILE-CONTRACT.md + Text size (lib/text-size.ts, Appearance) + touch scrollbar + pull-refresh pinch guard. Phone live check baaki.
- 23 Oct 09:30 In-context zoom: mail body (READ_ZOOM) + calendar hour height (GRID_HOUR) via lib/zoom-prefs.ts. Phone live check baaki.

- 23 Oct: Pull-to-refresh asli `location.reload()` (draft ho to sirf refetch) — `lib/pull-refresh.ts hasDraft`, `PullRefresh.tsx`. Dobara data-only mat banao.

- 23 Oct: GlobeView touch-none -> touch-pan-y (popover scroll globe par atakta tha). Wapas touch-none mat karo.

- 23 Oct: useSettingHistory(key, enabled) — row history sirf open par fetch (N+1 hata). Wapas bina enabled mat lagao.

- 23 Oct: TouchScrollbar (draggable handle, coarse pointer) — lib/touch-scroll.ts + components/app/TouchScrollbar.tsx in AppShell. Dobara na banao.

- 23 Oct: SettingRow text column basis-[15rem] (buttons wrap) — wapas bina basis mat karo.

- 23 Oct: Calendar toolbar = Meeting + ek "⋯" menu (Calendar settings andar, label ke saath), sab screens par. Alag slider icon wapas mat lagao.

- 23 Oct: PhoneCalendar HowTo tabs (Android DAVx5 / iPhone / Computer) + DAV_URL. /dav/ ka browser mein "Sign in..." text normal hai — bug nahi.

- 23 Oct: DAVx5 Play Store par PAID (~1800), F-Droid par free. Founder paid app nahi lega. Guide text theek kiya. Agla option: no-install "Google Calendar subscribe" feed (secret ICS link, Rust route /dav/feed/<key>.ics; Google ka refresh 12-24h). Founder ka faisla baaki.

- 23 Oct: CalDAV B (Calendar link / feed): SQL E81 (kind dav|feed, CHECK_E81, proof) + Rust (dav_core Route::Feed/feed_ics/etag, dav_glue feed handler, procs caldav.feed.*) + Web PhoneFeed + Caddy log_skip. Local Postgres + asli handler harness (rust-harness/dav-feed-harness.sh) GREEN; server deploy baaki (founder). Dobara na banao.

- 23 Oct: DAV/feed load() paginated (sb_all, 1000/page) + chunked in.() + HashMap — 2000/1000 cap khatam. Dobara limit=2000 mat lagao. Deploy GREEN (SQL E81, Rust, Caddy log_skip, Web) founder ne 10:43 tak chalaya.

- 23 Oct: CalDAV B (Calendar link) LIVE GREEN: Google ne link kabool kiya, meetings dikhe. Dobara test/banana nahi.
- Calendar #8 Rooms: code complete 23 Oct 14:30 (deploy + live test baaki)
- Calendar GREEN 23 Oct 11:05: #8 Rooms green; #7 Google sync DROPPED/parked by founder
- Rooms deployed on server 24 Oct (SQL+Rust+Web all OK)
- CALENDAR GREEN HANDOVER 24 Oct 14:25 (12 green, #7 deferred)
- Rooms live test 24 Oct: create OK, book OK, release OK; bug: location rehti thi -> E82 release fix (14:35)
- Rule: har message ke baad context update (founder 24 Oct)
- 24 Oct 14:30 context checkpoint: rooms live-tested, release-location fix pending server SQL
- 24 Oct 14:45 rooms: Busy live OK; bug2 guest-list fix (Web)
- 24 Oct 15:05 E83 room DB guard written+proved (deploy baaki)
- 24 Oct 15:30 rooms fix4 (manual guest message) written; E83 live-verified (DB refused)
- 24 Oct 15:00 ROOMS LIVE-VERIFIED: hint, room_busy reschedule 409, release clears location
- 24 Oct 16:05 E84 series room check written (Rust, deploy baaki); web sweep: tsc/388 tests OK, lint 14 non-format items noted
- RULE: Nauman bhai ko hamesha 'aap' kehna, 'tum' nahi (24 Oct 15:17)
- 24 Oct 15:50 PRO audit start: templates UI, thread notes, domains plural (push baaki)
- 24 Oct 16:25 PRO fix: Snooze enum bug fixed (Rust+Bun), Snoozed view, templates UI, thread notes (push done, deploy baaki)
- 24 Oct 16:45 RULE: Rust PRIMARY, Bun fallback only; Pro snooze/templates ab Rust procs (mail.snooze, mail.templates.save/delete), deploy baaki
- 24 Oct 17:05 TECH AUDIT doc written; Pro server gates (snooze/schedule/templates) Rust+Bun; deploy baaki
- 24 Oct 17:30 M1: thread labels/status/move/assign/snooze Rust primary (client+Bun validation); deploy baaki
- 24 Oct 17:50 MIGRATION-PHASES-24OCT.md written (11 phases, lanes A/B/C); code deploy M1 baaki
- 24 Oct 18:00 M1 deployed by founder (Rust+restart+Web); live test pending
- 24 Oct 18:20 M1 fix: mailx module (Rust procs ab asli deploy path se), main.rs reverted; deploy pending
- 24 Oct 18:35 brain-pro-install.sh (Bun fallback Pro fixes) written; Bun live purana tha; deploy pending
- 24 Oct 18:50 brain-drift-check.sh (read-only) added; rule: har batch mein Bun command bhi
