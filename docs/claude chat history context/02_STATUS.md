Anexomail - Current Status (overwrite this file each session - reflects "now", not history)
Last updated: 2026-09-29

TOP PRIORITY OPEN ITEM: NONE - CRM Memory frontend confirmed LIVE on
anexomail.com (served by anexomail-web process) as of 2026-09-29.
Verified: "Refresh health" text present in built assets
(app.crm.relationships-*.js).

CRM - "Memory / Relationships" feature (7-point spec):
Backend: ALL 7 points DONE, confirmed via curl.
1. Unified per-person timeline - DONE - crm.person.timeline
2. Relationship health (Active/Cooling/Cold) - DONE - crm.contacts.recompute
3. Response-pace stats per person - DONE - same function as #2
4. Auto-extract phone/title from signature - DONE - crm.contacts.extractSignature
5. Team-wide shared context (Business only) - DONE - needed no code, org_id-scoped queries already shared by design
6. Person-level notes - DONE - crm.contacts.setNotes
7. Merge duplicate identities (aliases) - DONE - crm.contacts.addAlias

Frontend: hooks written (useRecomputeContactStats, useSetContactNotes,
useAddContactAlias, useExtractSignature) + UI card written - see top
priority item above for live-deploy status.

CRM - other features - DONE and confirmed live:
- Leads/Capture: crm_capture_suggestions() auto-detects leads from inbound
  mail (30-day window), confidence scoring, dedup, dismissal table. Rust:
  crm.leads.suggest, crm.leads.dismiss. Frontend confirmed working live.
- Follow-ups: crm_followups() SQL fn, configurable threshold (default 3
  days). Rust: crm.followups.list/setDays. Frontend card on CRM Overview.
- Promises: Rust crm.promises.list, real columns confirmed against
  work_promises table. Frontend card on CRM Overview.
- People list critical bug FIXED (both reference and live files): contacts
  table does not have health_score/last_contact_at columns (only
  contact_stats does) - this silently broke the People list for every
  user until fixed in CONTACT_SELECT.
- VERIFIED (2026-10-06): accepting a lead (POST /crm/leads) now also creates
  the contacts row. Tested on Humza's real account by the owner pressing
  Accept in the browser: crm_leads and contacts rows were created 0.27s
  apart, and no 'contacts insert failed' appeared in the logs. The fix lives
  in /opt/anexomail/src/routes/crm.ts (the file the /api server on port 3100
  actually runs). A copy of the patch also sits in
  /opt/anexomail-web/server/routes/crm.ts but that copy is NOT live.
- Note: contacts.display_name stays empty when the lead is accepted from a
  mail suggestion, because suggestions carry no name.

Account / billing:
- Personal Pro+ mapping bug FIXED: personal_polar_map had "Personal Pro+"
  wrongly mapped to business_pro power, corrected to business.
- Masood's test account converted to genuine Personal Pro+ shape
  (plan=business, account_kind=personal via account_profiles.preferences).

Mail:
- InlineReply.tsx: Reply AND Forward both collapsed by default (all
  plans) - was previously an always-expanded compose box.
- ComposeStudio.tsx: added initialBody prop (needed for Forward's quoted
  content).
- Quote-collapsing (details toggle) added to thread message view.
- mail_attachments select fixed to (*) with URL fallback chain.
- mail.thread migrated to Rust with automatic Bun fallback.
- Thread Insights Pro+ gate (Step 7): confirmed live.

Known past incident (context only, already resolved):
A live DB row was mistakenly deleted in an earlier session (organisations
table test row) during Masood-account testing - was a test org, not
customer data, already cleaned up. No outstanding data-integrity concern.

Loop status update (2026-10-08) - this replaces the 'page not built' and 'not applied' lines of any earlier Loop status section.
- Step 4 Promises page /app/crm/promises: built and deployed (build OK, 371 assets, site 200).
  The hook useCrmPromisesBoard is in lib/crm.ts. Loop step 4 links to the page.
  Browser check by the owner: pending.
- Loop steps 3 and 4 are now shown to every plan that can open CRM. The showCrmCollab filter
  was removed in CrmStage.tsx (backup: CrmStage.tsx.bak-loop-step4).
  Seen only on Humza's Business Pro account. NOT seen on a Pro account.
- Opening the Promises page runs the scan (scan true). It writes suggested rows from that
  user's own mail of the last 30 days. Nothing else writes to work_promises.
- Frontend builds now go through /root/bin/safe-build-web.sh (restores the old build if the new
  one fails).
- Still pending: owner checks that clicking a person on Timeline opens Relationships and that
  the Meeting filter shows the empty message; pressing the real Work board done button.

Step 5 Health (2026-10-08) - spec in 05_SPEC_CRM_LOOP.md
- The old recompute_contact_stats only looks at from_address, so it never counts mail you sent
  (messages_out is always 0, avg_reply_minutes empty, open_threads always 0). The Refresh health
  button still uses it.
- New SQL function crm_health computes health fresh from mail in BOTH directions, understands
  alias emails, writes nothing. Seen: rollback test on a fake org (5 people, right order, alias
  worked, a person with no mail excluded). Seen: Rust crm.health live, Humza got 1 row, active,
  waiting_on_me true, 12 days.
- Page /app/crm/health and hook useCrmHealth built and deployed (build OK, 372 assets, site 200).
  Loop step 5 links to the page. Ranking: waiting for your reply, then cooling (15-45 days), cold
  (over 45), active (14 or less). Browser check by the owner: pending.
- Still pending checks: Loop shows Timeline and Promises; Promises page empty message; Timeline
  person click and Meeting filter; real Work board done button.
- Not done yet: Step 6 Risk, Step 8 Graph, Step 9 Next.

Step 6 Risk (2026-10-08) - spec in 05_SPEC_CRM_LOOP.md
- New SQL function crm_risk builds three kinds of danger with a reason each: deal_cold (open deal
  whose person is cold, more than 45 days), promise_overdue (committed promise past its date and
  not done), reply_waiting (they wrote last and no reply for 3 days or more). It reuses crm_health
  and crm_promises_board and writes nothing. The thresholds are my choice, not the owner's.
- Seen: rollback test on a fake org returned exactly the three kinds in order; a won deal, a
  recent contact and a person I wrote to were correctly excluded. Seen: Rust crm.risk live, Humza
  got 1 risk (reply_waiting, 12 days).
- Page /app/crm/risk and hook useCrmRisk built and deployed; Loop step 6 links to it and the
  showCrmRisk gate was removed from the Loop filter, so it shows on every plan that can open CRM.
  Browser check by the owner: pending.
- The reason text is built in SQL in English only.
- Not done yet: Step 8 Graph, Step 9 Next (Next must be built from steps 4, 5 and 6).
