Anexomail - Current Status (overwrite this file each session - reflects "now", not history)
Last updated: 2026-09-29

TOP PRIORITY OPEN ITEM:
CRM Memory frontend patch (Details card: Refresh health / Extract signature /
Notes / Add-alias, in app.crm.relationships.tsx + 4 new hooks in lib/crm.ts)
was built and deployed successfully in /opt/anexomail-web/ (reference copy).
It has NOT been confirmed applied to /opt/anexomail/ (the LIVE codebase).
Until it is, it will not appear on the real website.
Next action: run the same patch against /opt/anexomail/, rebuild, restart
anexomail-leo, and verify in-browser on the Relationships page.

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
