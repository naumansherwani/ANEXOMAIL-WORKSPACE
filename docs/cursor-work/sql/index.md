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
| E31_calendar_v2.sql             | E-series — Calendar v2: invitation ledger, RSVP token + `calendar_rsvp_lookup/apply`, `calendar_busy` (Rust invitations/RSVP/find-a-time ke liye) | **aap Run** (`rust-calendar-install.sh` se pehle). **18 Oct: pehla version FK par fail hua — shuru se likha**, Part 1 schema / Part 2 self-test alag, asli org se test; 5 schema-variants + 8 mutation tests green |
| E32_tenant_lock.sql             | E-series — tenant lock: ~40 tables se anon/authenticated ki saari policies + grants hata kar service_role-only (pehle `rls-open-check.sh`) | **aap Run** (read-only check ke baad) |
| E33_team_invites.sql            | E-series — team invitations: `org_invitations` ledger (role honoured, token, expiry), atomic `team_invite_accept`, `org_teams`/`org_team_members`, `org_people_log`; all service_role-only (G17 / L32 / L33) | **aap Run** (`rust-engine-install.sh` se pehle). **18 Oct: pehla version `org_role` par fail hua — shuru se likha**: accept ab role/status ka asli type DB se dhoondh kar likhta hai; 5 schema-variants + 12 mutation tests green |
| E34_team_seats_chain_mailbox.sql | E-series — team seats counted by the database (`team_seat_state`, business_pro unlimited), `team_audit` feeds the tamper-evident `org_audit_chain`, optional work address (`mailbox_*`) created when the invitee joins via `org_address_create`; accept takes an advisory lock so two joins can never take the last seat; service_role only; 28-check self-test rolled back |
| E35_migration_walled_garden.sql | E-series — **migration walled garden** (G30): mailbox copy from an old provider. One-use DB-issued `migration_session_token` (only its SHA-256 is stored); `migration_ingest` is the ONLY writer and the trigger `mail_messages_mig_gate` blocks any other write marked as migration; when the session ends it is sealed + locked (read-only for good). Append-only per-email SHA-256 evidence chain (`mig_chain`, tamper-evident) with `migration_chain_verify/export`; resume (`migration_done`, `migration_release`, `migration_reopen`); service_role only; live inbound path (`mail_ingest`) untouched; 54-check self-test rolled back | **E35 PEHLE, phir `MODULES=mig` Rust installer** |
| E36_ensure_test_account.sql     | E-series — test account "ensure": account nahi to banata hai, kharab (password/confirm/ban/delete/NULL tokens/identity/plan/org/mailbox) to theek karta hai; password plain nahi, hash | **`bizpro-login-fix.sh` chalaye** (password silent prompt se) |
- E65 | RLS ON + advisor sweep + event trigger | CHECK_E65 | 22 Oct 20:30 READY (server par chalana baqi)
| E66 | identity vault (ek insaan ek account) | CHECK_E66 | 22 Oct 21:25 READY |
| E67 | passkey vault + authenticated select band | CHECK_E67 | 22 Oct 21:25 READY |
| E68 | identity vault: Block/Release/Appeal hook, raw HMAC wrappers, signup appeals, founder overview | CHECK_E68 | 22 Oct 21:45 READY |
| E69 | identity vault: ban feed (local mirror) + NOTIFY, health report, payment sweep source, deny-after-signup flag | CHECK_E69 | 22 Oct 22:20 READY |
