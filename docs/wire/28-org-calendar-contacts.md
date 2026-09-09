# WIRE 28 — org + calendar SQL (Supabase editor only)

Status: **READY**. **DONE** nahi jab tak paste green ho aur `/auth` se real session ke baad dashboard org dikhe.

Sirf **ek** raasta: GitHub se file kholo → poori copy → Supabase #4 SQL Editor → Run.
Server `sql/run.sh` is patch ke liye mat chalao.

Tarteeb (mix nahi):

1. `sql/phase60_org_identity_repair.sql`
2. `sql/phase61_calendar_work.sql`
3. `sql/phase62_contacts_intelligence.sql` (pehle wali file, schema naya nahi)

Verify:
- Phase 60: `orgs_rows` / `org_members_rows` numbers
- Phase 61: `calendar_status_ready` = true, `work_status_ready` = true
