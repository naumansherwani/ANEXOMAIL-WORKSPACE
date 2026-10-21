# 06 — Repo ki inventory (ginti + naam)

| Hissa | Ginti |
|---|---|
| src/routes | 170 |
| src/components (files) | 170 |
| src/lib | 112 |
| server/routes (Brain Bun) | 41 |
| server/rust (files) | 33 |
| SQL E-files | 43 |
| SQL CHECK files | 7 |
| server scripts .sh | 57 |
| python patch/proof scripts | 21 |
| tests *.test.ts(x) | 7 |

## Rust modules (server/rust)
- `attach_core.rs`
- `attach_glue.rs`
- `cal_core.rs`
- `cal_glue.rs`
- `deliver_bin.rs`
- `device_core.rs`
- `device_glue.rs`
- `dnsauth_core.rs`
- `dnsauth_glue.rs`
- `events_core.rs`
- `events_glue.rs`
- `export_core.rs`
- `export_glue.rs`
- `inbound_attach.rs`
- `jwt_core.rs`
- `locale_core.rs`
- `locale_glue.rs`
- `mail_core.rs`
- `mail_glue.rs`
- `main.rs`
- `mig_core.rs`
- `mig_glue.rs`
- `mig_imap.rs`
- `mig_mime.rs`
- `mig_run.rs`
- `passkey_core.rs`
- `passkey_glue.rs`
- `people_core.rs`
- `people_glue.rs`
- `security_core.rs`
- `security_glue.rs`
- `team_core.rs`
- `team_glue.rs`

## Brain routes (server/routes)
`account-deletion.ts`, `admin.ts`, `ai-automation.ts`, `ai-credits.ts`, `ai-studio.ts`, `ai.ts`, `auth-passkey.ts`, `auth.ts`, `billing-support.ts`, `billing-sync.ts`, `calendar.ts`, `chat.ts`, `contacts.ts`, `crm.ts`, `dashboard.ts`, `files.ts`, `founder.ts`, `glitch.ts`, `handoff.ts`, `integrations.ts`, `leo.ts`, `locale.ts`, `mail-compose.ts`, `mail-predict.ts`, `mail.ts`, `movein.ts`, `org.ts`, `people-import.ts`, `perf.ts`, `polar.ts`, `release.ts`, `revenue.ts`, `security.ts`, `settings.ts`, `storage.ts`, `support.ts`, `trial.ts`, `workspace.ts`

## SQL E-series
`E13_personal_polar_products.sql`, `E14_mail_thread_assign.sql`, `E14_security_advisor_clean.sql`, `E15_business_domains.sql`, `E17_trial_provision_workspace.sql`, `E18_signup_device_gate_nonblocking.sql`, `E19_password_reset_hardening.sql`, `E20_personal_plan_pending.sql`, `E22_plan_replacement.sql`, `E23_payment_activates_account.sql`, `E24_account_deletion.sql`, `E27_business_pro_mailboxes_unlimited.sql`, `E28_seed_buyer_test_account.sql`, `E2_personal_polar.sql`, `E30_dashboard_truth.sql`, `E31_calendar_v2.sql`, `E32_tenant_lock.sql`, `E33_team_invites.sql`, `E34_team_seats_chain_mailbox.sql`, `E35_migration_walled_garden.sql`, `E36_ensure_test_account.sql`, `E37_mail_ingest_no_stray_org.sql`, `E38_thread_message_count_truth.sql`, `E39_security_truth.sql`, `E40_billing_price_truth.sql`, `E41_family_real_buyer.sql`, `E42_device_hash_hmac.sql`, `E43_passkey_recovery_codes.sql`, `E44_account_export.sql`, `E45_integrity_purge.sql`, `E46_integrity_notices_appeal.sql`, `E47_device_revoke_real_sessions.sql`, `E48_outgoing_attachments.sql`, `E49_attach_ceiling_18mb.sql`, `E50_inbound_attachments.sql`, `E51_calendar_response_fix.sql`, `E52_alias_fair_use.sql`, `E52_calendar_response_values.sql`, `E53_auth_session_alive.sql`, `E54_mail_queue_claim.sql`, `E5_billing_subscription_api.sql`, `E6_companywide_delete.sql`, `E7_business_delete_48h.sql`

## Installers (docs/cursor-work/server/*install*.sh)
`brain-attach-install.sh`, `brain-auth-harden-install.sh`, `brain-crm-install.sh`, `brain-integrity-install.sh`, `brain-mail-install.sh`, `brain-org-install.sh`, `brain-passkey-harden-install.sh`, `brain-passkey-install.sh`, `brain-people-import-install.sh`, `brain-refresh-install.sh`, `rust-calendar-install.sh`, `rust-deliver-install.sh`, `rust-engine-install.sh`, `rust-events-install.sh`, `rust-inbound-attach-install.sh`, `rust-jwt-install.sh`, `rust-mail-install.sh`, `rust-passkey-install.sh`

## Founder routes (src/routes/app.founder*)
`app.founder.tsx`, `app.founder_.admin.tsx`, `app.founder_.ai.arena.tsx`, `app.founder_.ai.automation.tsx`, `app.founder_.ai.billing.tsx`, `app.founder_.ai.index.tsx`, `app.founder_.ai.knowledge.tsx`, `app.founder_.ai.memory.tsx`, `app.founder_.ai.prompts.tsx`, `app.founder_.ai.receipts.tsx`, `app.founder_.ai.studio.tsx`, `app.founder_.ai.tsx`, `app.founder_.analytics.tsx`, `app.founder_.billing.tsx`, `app.founder_.calls.tsx`, `app.founder_.crm.tsx`, `app.founder_.integrations.tsx`, `app.founder_.launch.checklist.tsx`, `app.founder_.launch.deployments.tsx`, `app.founder_.launch.index.tsx`, `app.founder_.launch.lock.tsx`, `app.founder_.launch.qa.tsx`, `app.founder_.launch.roadmap.tsx`, `app.founder_.launch.tsx`, `app.founder_.motion.tsx`, `app.founder_.movein.tsx`, `app.founder_.org.tsx`, `app.founder_.perf.tsx`, `app.founder_.revenue.tsx`, `app.founder_.revenue_.pipeline.tsx`, `app.founder_.safety.tsx`, `app.founder_.security.tsx`, `app.founder_.settings.tsx`