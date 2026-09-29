Anexomail - Changelog (append-only, newest entries at the TOP)
Add one line per real change. Never delete old lines - archive them
into 03_CHANGELOG_ARCHIVE.md if this file gets too long.

---

2026-09-29 (later same day)
- Found and fixed a SECOND People-list bug: accepting a lead (POST
  /crm/leads) never wrote to the contacts table, only crm_leads - so
  Relationships page stayed empty for every user regardless of plan,
  even after accepting leads. Fixed in server/routes/crm.ts, built,
  deployed to anexomail-web, verified live via curl (accepted a lead,
  confirmed it now appears in /api/crm/live people array with correct
  health_score/open_threads).

2026-09-29
- Built the 3-file docs system (01_ARCHITECTURE.md, 02_STATUS.md,
  03_CHANGELOG.md) so context survives across non-compacting Claude
  sessions without re-pasting huge chat exports.
- CRM Memory frontend patch (Details card + 4 hooks) built successfully
  in /opt/anexomail-web/ (reference). Still needs confirming/applying
  to /opt/anexomail/ (LIVE) - not yet verified in browser.

2026-09-27 / 28 (approximate)
- CRM Memory backend: all 7 points (timeline, health/response-pace,
  signature extraction, notes, alias merge) implemented in Rust,
  confirmed green via curl for each crm.contacts.* / crm.person.timeline
  procedure.
- CRM Leads (Capture): crm_capture_suggestions() SQL fn added - auto
  lead detection with confidence scoring, dedup, dismissals. Confirmed
  working live via screenshot.
- CRM Follow-ups: crm_followups() SQL fn + configurable per-user days
  threshold added.
- CRM Promises: crm.promises.list added to Rust, column list corrected
  against real work_promises schema.
- Critical People-list bug fixed: contacts table doesn't have
  health_score/last_contact_at - was breaking loadPeople() for every
  user. Fixed in both reference AND live crm.ts (initially fixed in the
  wrong file first - live file needed a second pass).
- Personal Pro+ billing bug fixed: personal_polar_map had wrong power
  mapping (business_pro corrected to business).
- Masood's test account converted to genuine Personal Pro+ shape.
- Mail: Reply/Forward collapsed by default, quote-collapsing added,
  attachment URL fallback fixed, mail.thread migrated to Rust.
- Thread Insights Pro+ gate (Step 7) shipped and confirmed live.

Earlier (2026-06-18 to 2026-09-26)
- Full history exists in a large chat export but was NOT fully mined
  into this changelog - too large/broad to reliably summarize in one
  pass (covers the whole site: weather/cinema UI effects, mailbox/domain
  creation with plan caps, message-actions dropdown, Rust distributed
  systems work, etc, not just CRM). Going forward, this changelog is the
  source of truth.
