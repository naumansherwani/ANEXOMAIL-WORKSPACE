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
