# D5a-3b SCHEMA-FIRST READ (22 Nov 2026 21:5x PKT, his SQL schema-first law 20 Nov 20:35). Read BEFORE any responder code.
Responder = the Control Plane side of the Desk lookup (contract gates/DESK-LOOKUP-CONTRACT.json, 18 allowed fields). It reads the awam/Polar-fed data and answers; the Desk never sees money.
| Field(s) the contract allows | Source table (file that owns it) | Columns read | Gap |
|---|---|---|---|
| company (company_ref -> org) | public.orgs, public.org_members, public.mail_accounts (sql/phase60_org_identity_repair.sql; account_organisations in phase59) | orgs.id, name | which of the two org families is the real one is NOT proven: needs his read-only psql on the awam database |
| package_id, service_state, grace_days_left, payment_received_service_not_active, payment_flag_since | public.polar_subscriptions (sql/phase50_polar_rust_payment.sql: status active/past_due/grace/canceled/revoked, grace_until, current_period_end, seats) joined to the org by user_id/email (E5 shows the join) | status, grace_until, product_key, seats, updated_at | NO money column is read (amount fields are never selected) |
| limit_storage, limit_seats, limit_attachment | public.storage_plans (phase48: basic 5GB x 3 mailboxes, pro 10GB x 5, business 25GB x 30, business_pro pool 1TB) | plan_id, per_mailbox_bytes, mailbox_limit, pooled_bytes, max_send_bytes | CONFLICT: this old matrix differs from the landing page (plans.ts: pro 10 mailboxes + 300GB, business 1.5TB, business_pro 10TB). The Desk registry AD6b follows the landing page; the responder must say which source wins: QUESTION FOR HIM |
| usage_storage, usage_seats | public.mailbox_storage (used_*_bytes per mailbox, workspace_id) and public.org_members (count status=active) | used bytes sum, member count | workspace_id vs org_id link not proven |
| suspension_class, suspension_since | no table found. Classes SR1..SR8 exist only as a draft (RUNBOOK-LIBRARY-DRAFT-22NOV.md section B) | none | answer null until a table exists |
| package_version, package_effective_from, features_*, sla_target | Desk registry AD6/AD6b (desk.fadm_pkg_*) | read by the Desk itself | none |
| data_freshness | the responder's own read time | none | none |
RULE: a field whose source is unproven is sent as null ("not measured"), never invented.
NEXT: his ONE read-only command on the awam database for the real org/subscription/usage columns, then the D5a-3b contract block, then the crate.

## CORRECTIONS (his 22 Nov 2026 22:16 PKT)
1. His package caps are ALREADY decided (AWAM-PACKAGES-PROPOSAL-07NOV.md section 6 D: card values = repo/plans.ts stay exactly; storage_plans conflict question withdrawn). Business Premium (7,000 users, 70 TB, 100 MB, 4 GB) and Business Max (card unlimited, strict 125,000 backend cap, 90% yellow / 95% high, never blocked) are decided too but are added AFTER the founder lane; the responder must know them when they are added.
2. His rule F: the 48-hour trial is the only free entry. AD6b had trial 0: corrected by AD6c (version 2, trial_days 2).
3. "Family" accounts (Rule 40, unlimited) are a separate thing, not a package and not an org to look up: they never appear in the Desk lookup. My earlier word "org family" meant two groups of tables (orgs vs account_organisations), nothing to do with family accounts.
4. (his 22:19 word, awam blueprint read) The AI packages belong to the AI product (ai.anexomail.com, July 2027, AWAM-BLUEPRINT-ALPHABETIC section A.5) and were wrongly in my AD6b seed: AD6d retires them and adds Business Premium + Business Max with his FINAL caps. The Desk ladder is now Basic, Pro, Business, Business Pro, Business Premium, Business Max.
