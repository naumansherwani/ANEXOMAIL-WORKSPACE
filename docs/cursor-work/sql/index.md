# SQL — docs/cursor-work/sql/

Do tracks. Mix **banned**.

## Phase 60s — founder blueprint (NO TOUCH)

`sql/phase60*.sql` · `sql/phase61*.sql` · `sql/phase62*.sql`  
`docs/cursor-work/sql/phase63*.sql` · `phase64*.sql` · `phase65*.sql`

Agent inhein edit, rewrite, undo, ya “ek aur dafa paste” **nahi** kehta. Jo run ho chuka, woh founder ka hai.

## Agent — E-series only

Naya SQL yahan, naam: `E<n>_….sql` (execute board: `docs/cursor-work/ANEXOMAIL-EXECUTE.md`).  
Root `sql/` mein naya file **nahi**. Blueprint `docs/anexomail-blueprint.md` no-touch.

**Agar E-file fail ho:** usi file ko shuru se theek likho. Naya naam (`E4b`, `_fix`, `_v2`) **banned**.

| File                            | Track                                                              | Agent                   |
| ------------------------------- | ------------------------------------------------------------------ | ----------------------- |
| phase60 / 61 / 62 (root `sql/`) | founder                                                            | no-touch                |
| phase63_f3a_passkey_family.sql  | founder (already run)                                              | no-touch                |
| phase64_crm_locale.sql          | founder (already run)                                              | no-touch                |
| phase65_account_kind.sql        | founder (already run)                                              | no-touch                |
| E2_personal_polar.sql           | E-series — Personal Polar map only                                 | **aap Run**             |
| E13_personal_polar_products.sql | E-series — six separate Personal Polar prices + account-kind guard | **IDs ke baad aap Run** |
| E14_security_advisor_clean.sql  | E-series — RLS on, security_invoker views, function search_path     | **aap Run**             |
| E28_seed_buyer_test_account.sql | E-series — asli business buyer test account (payment ki jagah entitlement row), #20 | **aap Run** (variable ke saath) |
| E30_dashboard_truth.sql         | E-series — dashboard_summary / dashboard_analytics (Rust + Bun ka ek sach), plan-true storage, domain truth | **aap Run** (installer se pehle) |
| E31_calendar_v2.sql             | E-series — Calendar v2: invitation ledger, RSVP token + `calendar_rsvp_lookup/apply`, `calendar_busy` (Rust invitations/RSVP/find-a-time ke liye) | **aap Run** (`rust-calendar-install.sh` se pehle) |
| E32_tenant_lock.sql             | E-series — tenant lock: ~40 tables se anon/authenticated ki saari policies + grants hata kar service_role-only (pehle `rls-open-check.sh`) | **aap Run** (read-only check ke baad) |
| E33_team_invites.sql            | E-series — team invitations: `org_invitations` ledger (role honoured, token, expiry), atomic `team_invite_accept`, `org_teams`/`org_team_members`, `org_people_log`; all service_role-only (G17 / L32 / L33) | **aap Run** (`rust-engine-install.sh` se pehle) |
