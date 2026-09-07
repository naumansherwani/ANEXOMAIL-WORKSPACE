# WIRE STEP 09 — HAR SQL FILE SERVER PAR APPLY + VERIFY

Yeh step un SQL files ka hai jo repo mein hain. Rule wahi: file repo mein hona
"done" nahi hai. Dot GREEN sirf tab jab is step ka verify query us file ke saare
objects `t` return kare.

Kaise chalana hai (har file ke liye same 3 harkat):

1. `cd /opt/anexomail-web && git pull`
2. File ka poora content copy karo: `cat <file>` — Supabase SQL editor mein paste → Run.
3. Us file ke neeche diya verify query Supabase SQL editor mein chalao. Sab column `t` = GREEN.
   Koi bhi `f` aaye to us file ka apply dobara karo (saari files idempotent hain, dobara chalana safe hai).

Aakhir mein neeche wala MASTER VERIFY chalao — woh ek hi baar mein poori database ki
sachi haalat batata hai: kitne table/function missing hain.

Order maayne rakhta hai — neeche jo tarteeb hai, usi mein chalao (dependencies pehle).

## 01. `sql/phase_leo_memory.sql`
Tables: 2 · Functions: 2 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase_leo_memory.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.agent_memory_config') is not null) as tbl_agent_memory_config,
  (to_regclass('public.leo_memory_vectors') is not null) as tbl_leo_memory_vectors,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='leo_memory_prune') as fn_leo_memory_prune,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='leo_recall') as fn_leo_recall;
```

## 02. `sql/phase17_ai_studio.sql`
Tables: 4 · Functions: 0 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase17_ai_studio.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.ai_studio_batches') is not null) as tbl_ai_studio_batches,
  (to_regclass('public.ai_studio_recipe_runs') is not null) as tbl_ai_studio_recipe_runs,
  (to_regclass('public.ai_studio_recipes') is not null) as tbl_ai_studio_recipes,
  (to_regclass('public.ai_studio_runs') is not null) as tbl_ai_studio_runs;
```

## 03. `sql/phase18_ai_automation.sql`
Tables: 7 · Functions: 0 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase18_ai_automation.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.ai_email_automations') is not null) as tbl_ai_email_automations,
  (to_regclass('public.ai_rules') is not null) as tbl_ai_rules,
  (to_regclass('public.ai_suggestions') is not null) as tbl_ai_suggestions,
  (to_regclass('public.ai_variables') is not null) as tbl_ai_variables,
  (to_regclass('public.ai_workflow_runs') is not null) as tbl_ai_workflow_runs,
  (to_regclass('public.ai_workflow_steps') is not null) as tbl_ai_workflow_steps,
  (to_regclass('public.ai_workflows') is not null) as tbl_ai_workflows;
```

## 04. `sql/phase19_ai_billing.sql`
Tables: 4 · Functions: 0 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase19_ai_billing.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.ai_checkouts') is not null) as tbl_ai_checkouts,
  (to_regclass('public.ai_credit_events') is not null) as tbl_ai_credit_events,
  (to_regclass('public.ai_topup_packs') is not null) as tbl_ai_topup_packs,
  (to_regclass('public.ai_wallets') is not null) as tbl_ai_wallets;
```

## 05. `sql/phase20_ai_knowledge.sql`
Tables: 4 · Functions: 1 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase20_ai_knowledge.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.knowledge_answers') is not null) as tbl_knowledge_answers,
  (to_regclass('public.knowledge_chunks') is not null) as tbl_knowledge_chunks,
  (to_regclass('public.knowledge_documents') is not null) as tbl_knowledge_documents,
  (to_regclass('public.knowledge_spaces') is not null) as tbl_knowledge_spaces,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='knowledge_recall') as fn_knowledge_recall;
```

## 06. `sql/phase21_billing_platform.sql`
Tables: 5 · Functions: 0 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase21_billing_platform.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.billing_payment_methods') is not null) as tbl_billing_payment_methods,
  (to_regclass('public.billing_tax_profiles') is not null) as tbl_billing_tax_profiles,
  (to_regclass('public.workspace_invoices') is not null) as tbl_workspace_invoices,
  (to_regclass('public.workspace_plans') is not null) as tbl_workspace_plans,
  (to_regclass('public.workspace_subscriptions') is not null) as tbl_workspace_subscriptions;
```

## 07. `sql/phase22_integrations.sql`
Tables: 8 · Functions: 1 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase22_integrations.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.delivery_blocklists') is not null) as tbl_delivery_blocklists,
  (to_regclass('public.delivery_checks') is not null) as tbl_delivery_checks,
  (to_regclass('public.integration_connections') is not null) as tbl_integration_connections,
  (to_regclass('public.integration_exports') is not null) as tbl_integration_exports,
  (to_regclass('public.integration_migration_items') is not null) as tbl_integration_migration_items,
  (to_regclass('public.integration_migrations') is not null) as tbl_integration_migrations,
  (to_regclass('public.integration_providers') is not null) as tbl_integration_providers,
  (to_regclass('public.leo_actions') is not null) as tbl_leo_actions,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='founder_integrations_overview') as fn_founder_integrations_overview;
```

## 08. `sql/phase23_settings.sql`
Tables: 5 · Functions: 0 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase23_settings.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.setting_defs') is not null) as tbl_setting_defs,
  (to_regclass('public.setting_explanations') is not null) as tbl_setting_explanations,
  (to_regclass('public.setting_schedules') is not null) as tbl_setting_schedules,
  (to_regclass('public.setting_values') is not null) as tbl_setting_values,
  (to_regclass('public.setting_versions') is not null) as tbl_setting_versions;
```

## 09. `sql/phase24_analytics.sql`
Tables: 6 · Functions: 1 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase24_analytics.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.analytics_attention_leaks') is not null) as tbl_analytics_attention_leaks,
  (to_regclass('public.analytics_debt_daily') is not null) as tbl_analytics_debt_daily,
  (to_regclass('public.analytics_deep_work') is not null) as tbl_analytics_deep_work,
  (to_regclass('public.analytics_promises') is not null) as tbl_analytics_promises,
  (to_regclass('public.analytics_rates') is not null) as tbl_analytics_rates,
  (to_regclass('public.analytics_thread_cost') is not null) as tbl_analytics_thread_cost,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='founder_analytics_overview') as fn_founder_analytics_overview;
```

## 10. `sql/phase25_admin.sql`
Tables: 10 · Functions: 1 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase25_admin.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.admin_delivery_events') is not null) as tbl_admin_delivery_events,
  (to_regclass('public.admin_diagnostic_probes') is not null) as tbl_admin_diagnostic_probes,
  (to_regclass('public.admin_diagnostic_runs') is not null) as tbl_admin_diagnostic_runs,
  (to_regclass('public.admin_health_checks') is not null) as tbl_admin_health_checks,
  (to_regclass('public.admin_health_runs') is not null) as tbl_admin_health_runs,
  (to_regclass('public.admin_incident_events') is not null) as tbl_admin_incident_events,
  (to_regclass('public.admin_incidents') is not null) as tbl_admin_incidents,
  (to_regclass('public.admin_logs') is not null) as tbl_admin_logs,
  (to_regclass('public.admin_reports') is not null) as tbl_admin_reports,
  (to_regclass('public.admin_storage_snapshots') is not null) as tbl_admin_storage_snapshots,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='founder_admin_overview') as fn_founder_admin_overview;
```

## 11. `sql/phase26_security.sql`
Tables: 10 · Functions: 1 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase26_security.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.security_anomalies') is not null) as tbl_security_anomalies,
  (to_regclass('public.security_devices') is not null) as tbl_security_devices,
  (to_regclass('public.security_encryption_surfaces') is not null) as tbl_security_encryption_surfaces,
  (to_regclass('public.security_key_ledger') is not null) as tbl_security_key_ledger,
  (to_regclass('public.security_kill_switches') is not null) as tbl_security_kill_switches,
  (to_regclass('public.security_ledger') is not null) as tbl_security_ledger,
  (to_regclass('public.security_login_events') is not null) as tbl_security_login_events,
  (to_regclass('public.security_proof_checks') is not null) as tbl_security_proof_checks,
  (to_regclass('public.security_proofs') is not null) as tbl_security_proofs,
  (to_regclass('public.security_sessions') is not null) as tbl_security_sessions,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='founder_security_overview') as fn_founder_security_overview;
```

## 12. `sql/phase27_perf.sql`
Tables: 8 · Functions: 1 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase27_perf.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.perf_budgets') is not null) as tbl_perf_budgets,
  (to_regclass('public.perf_device_profiles') is not null) as tbl_perf_device_profiles,
  (to_regclass('public.perf_prefetch_events') is not null) as tbl_perf_prefetch_events,
  (to_regclass('public.perf_regressions') is not null) as tbl_perf_regressions,
  (to_regclass('public.perf_releases') is not null) as tbl_perf_releases,
  (to_regclass('public.perf_samples') is not null) as tbl_perf_samples,
  (to_regclass('public.perf_search_traces') is not null) as tbl_perf_search_traces,
  (to_regclass('public.perf_surface_starts') is not null) as tbl_perf_surface_starts,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='founder_perf_overview') as fn_founder_perf_overview;
```

## 13. `sql/phase28_revenue.sql`
Tables: 5 · Functions: 0 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase28_revenue.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.revenue_accounts') is not null) as tbl_revenue_accounts,
  (to_regclass('public.revenue_jobs') is not null) as tbl_revenue_jobs,
  (to_regclass('public.revenue_leads') is not null) as tbl_revenue_leads,
  (to_regclass('public.revenue_partners') is not null) as tbl_revenue_partners,
  (to_regclass('public.revenue_targets') is not null) as tbl_revenue_targets;
```

## 14. `sql/phase28_handoff.sql`
Tables: 2 · Functions: 0 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase28_handoff.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.device_handoff') is not null) as tbl_device_handoff,
  (to_regclass('public.user_devices') is not null) as tbl_user_devices;
```

## 15. `sql/phase30_release.sql`
Tables: 8 · Functions: 0 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase30_release.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.deployments') is not null) as tbl_deployments,
  (to_regclass('public.mail_outbox') is not null) as tbl_mail_outbox,
  (to_regclass('public.release_checklist') is not null) as tbl_release_checklist,
  (to_regclass('public.release_checks') is not null) as tbl_release_checks,
  (to_regclass('public.release_locks') is not null) as tbl_release_locks,
  (to_regclass('public.release_runs') is not null) as tbl_release_runs,
  (to_regclass('public.roadmap_items') is not null) as tbl_roadmap_items,
  (to_regclass('public.subscription_pipeline') is not null) as tbl_subscription_pipeline;
```

## 16. `sql/phase31_ai_credits.sql`
Tables: 6 · Functions: 6 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase31_ai_credits.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.ai_actions') is not null) as tbl_ai_actions,
  (to_regclass('public.ai_credit_grants') is not null) as tbl_ai_credit_grants,
  (to_regclass('public.ai_credit_ledger') is not null) as tbl_ai_credit_ledger,
  (to_regclass('public.ai_credit_plans') is not null) as tbl_ai_credit_plans,
  (to_regclass('public.ai_credit_topup_products') is not null) as tbl_ai_credit_topup_products,
  (to_regclass('public.ai_credit_wallets') is not null) as tbl_ai_credit_wallets,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='ai_credits_complimentary') as fn_ai_credits_complimentary,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='ai_credits_release') as fn_ai_credits_release,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='ai_credits_reserve') as fn_ai_credits_reserve,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='ai_credits_settle') as fn_ai_credits_settle,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='ai_credits_topup') as fn_ai_credits_topup,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='ai_ledger_immutable') as fn_ai_ledger_immutable;
```

## 17. `sql/phase32_trial.sql`
Tables: 4 · Functions: 9 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase32_trial.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.reserved_handles') is not null) as tbl_reserved_handles,
  (to_regclass('public.trial_accounts') is not null) as tbl_trial_accounts,
  (to_regclass('public.trial_events') is not null) as tbl_trial_events,
  (to_regclass('public.trial_mail_holds') is not null) as tbl_trial_mail_holds,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='account_state') as fn_account_state,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='ai_enabled') as fn_ai_enabled,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='entitled_full') as fn_entitled_full,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='trial_claim_address') as fn_trial_claim_address,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='trial_events_immutable') as fn_trial_events_immutable,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='trial_set_security') as fn_trial_set_security,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='trial_start') as fn_trial_start,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='trial_subscribe') as fn_trial_subscribe,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='trial_sweep') as fn_trial_sweep;
```

## 18. `sql/phase33_polar_checkout.sql`
Tables: 2 · Functions: 0 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase33_polar_checkout.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.polar_checkout_sessions') is not null) as tbl_polar_checkout_sessions,
  (to_regclass('public.polar_webhook_events') is not null) as tbl_polar_webhook_events;
```

## 19. `sql/phase34_billing_support.sql`
Tables: 2 · Functions: 4 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase34_billing_support.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.billing_event_receipts') is not null) as tbl_billing_event_receipts,
  (to_regclass('public.founder_reply_queue') is not null) as tbl_founder_reply_queue,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='block_billing_receipt_mutation') as fn_block_billing_receipt_mutation,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='close_founder_reply_clock') as fn_close_founder_reply_clock,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='enqueue_founder_reply') as fn_enqueue_founder_reply,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='queue_inbound_support_reply') as fn_queue_inbound_support_reply;
```

## 20. `sql/phase35_payment_safety.sql`
Tables: 2 · Functions: 4 · Views: 2
```bash
cd /opt/anexomail-web && git pull && cat sql/phase35_payment_safety.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.payment_alerts') is not null) as tbl_payment_alerts,
  (to_regclass('public.polar_webhook_raw') is not null) as tbl_polar_webhook_raw,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='webhook_capture_raw') as fn_webhook_capture_raw,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='webhook_claim_retries') as fn_webhook_claim_retries,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='webhook_mark_failed') as fn_webhook_mark_failed,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='webhook_mark_processed') as fn_webhook_mark_processed,
  (to_regclass('public.payment_health') is not null) as vw_payment_health,
  (to_regclass('public.payment_reconciliation_gaps') is not null) as vw_payment_reconciliation_gaps;
```

## 21. `sql/phase36_state_sync.sql`
Tables: 3 · Functions: 8 · Views: 2
```bash
cd /opt/anexomail-web && git pull && cat sql/phase36_state_sync.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.billing_intents') is not null) as tbl_billing_intents,
  (to_regclass('public.billing_state_log') is not null) as tbl_billing_state_log,
  (to_regclass('public.entitlement_state') is not null) as tbl_entitlement_state,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_apply_entitlement') as fn_billing_apply_entitlement,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_intent_attach_checkout') as fn_billing_intent_attach_checkout,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_intent_confirm') as fn_billing_intent_confirm,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_intent_open') as fn_billing_intent_open,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_sync_abandon_stale') as fn_billing_sync_abandon_stale,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_sync_claim') as fn_billing_sync_claim,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_sync_fail') as fn_billing_sync_fail,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_sync_touch') as fn_billing_sync_touch,
  (to_regclass('public.billing_state_health') is not null) as vw_billing_state_health,
  (to_regclass('public.billing_truth_gaps') is not null) as vw_billing_truth_gaps;
```

## 22. `sql/phase37_movein_ops.sql`
Tables: 11 · Functions: 19 · Views: 5
```bash
cd /opt/anexomail-web && git pull && cat sql/phase37_movein_ops.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.movein_audit') is not null) as tbl_movein_audit,
  (to_regclass('public.movein_capacity') is not null) as tbl_movein_capacity,
  (to_regclass('public.movein_deals') is not null) as tbl_movein_deals,
  (to_regclass('public.movein_dns_checks') is not null) as tbl_movein_dns_checks,
  (to_regclass('public.movein_exceptions') is not null) as tbl_movein_exceptions,
  (to_regclass('public.movein_mailboxes') is not null) as tbl_movein_mailboxes,
  (to_regclass('public.movein_payments') is not null) as tbl_movein_payments,
  (to_regclass('public.movein_rollback_points') is not null) as tbl_movein_rollback_points,
  (to_regclass('public.movein_runbook') is not null) as tbl_movein_runbook,
  (to_regclass('public.movein_transitions') is not null) as tbl_movein_transitions,
  (to_regclass('public.movein_waitlist') is not null) as tbl_movein_waitlist,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_arm_cutover') as fn_movein_arm_cutover,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_attach_intent') as fn_movein_attach_intent,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_audit_immutable') as fn_movein_audit_immutable,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_band_for') as fn_movein_band_for,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_book_slot') as fn_movein_book_slot,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_cockpit') as fn_movein_cockpit,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_customer_view') as fn_movein_customer_view,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_cutover_ready') as fn_movein_cutover_ready,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_dns_green') as fn_movein_dns_green,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_evidence_bundle') as fn_movein_evidence_bundle,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_health') as fn_movein_health,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_health_calc') as fn_movein_health_calc,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_leg_paid') as fn_movein_leg_paid,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_next_reference') as fn_movein_next_reference,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_open_deal') as fn_movein_open_deal,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_price_for') as fn_movein_price_for,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_seed_runbook') as fn_movein_seed_runbook,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_sync_payments') as fn_movein_sync_payments,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_transition') as fn_movein_transition,
  (to_regclass('public.movein_attention') is not null) as vw_movein_attention,
  (to_regclass('public.movein_capacity_state') is not null) as vw_movein_capacity_state,
  (to_regclass('public.movein_cash_clock') is not null) as vw_movein_cash_clock,
  (to_regclass('public.movein_dns_proof') is not null) as vw_movein_dns_proof,
  (to_regclass('public.movein_mailbox_gaps') is not null) as vw_movein_mailbox_gaps;
```

## 23. `sql/phase38_movein_hardening.sql`
Tables: 1 · Functions: 13 · Views: 2
```bash
cd /opt/anexomail-web && git pull && cat sql/phase38_movein_hardening.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.movein_reference_counter') is not null) as tbl_movein_reference_counter,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_attach_intent') as fn_movein_attach_intent,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_customer_view') as fn_movein_customer_view,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_cutover_ready') as fn_movein_cutover_ready,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_data_verified_ok') as fn_movein_data_verified_ok,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_dns_owner_fill') as fn_movein_dns_owner_fill,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_exception_blocks_fill') as fn_movein_exception_blocks_fill,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_is_deal_member') as fn_movein_is_deal_member,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_next_reference') as fn_movein_next_reference,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_promote_waitlist') as fn_movein_promote_waitlist,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_rollback_create') as fn_movein_rollback_create,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_rollback_use') as fn_movein_rollback_use,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_rollback_validate') as fn_movein_rollback_validate,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_transition') as fn_movein_transition,
  (to_regclass('public.movein_my_dns_proof') is not null) as vw_movein_my_dns_proof,
  (to_regclass('public.movein_my_mailbox_gaps') is not null) as vw_movein_my_mailbox_gaps;
```

## 24. `sql/phase39_movein_fixes.sql`
Tables: 0 · Functions: 1 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase39_movein_fixes.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_attach_intent') as fn_movein_attach_intent;
```

## 25. `sql/phase40_evidence_truth.sql`
Tables: 0 · Functions: 1 · Views: 1
```bash
cd /opt/anexomail-web && git pull && cat sql/phase40_evidence_truth.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_evidence_validate') as fn_movein_evidence_validate,
  (to_regclass('public.movein_evidence_violations') is not null) as vw_movein_evidence_violations;
```

## 26. `sql/phase43_annual_billing_lock.sql`
Tables: 1 · Functions: 4 · Views: 2
```bash
cd /opt/anexomail-web && git pull && cat sql/phase43_annual_billing_lock.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.billing_price_book') is not null) as tbl_billing_price_book,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_apply_entitlement') as fn_billing_apply_entitlement,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_intent_confirm') as fn_billing_intent_confirm,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_intent_open') as fn_billing_intent_open,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_sync_claim') as fn_billing_sync_claim,
  (to_regclass('public.billing_polar_id_gaps') is not null) as vw_billing_polar_id_gaps,
  (to_regclass('public.billing_price_audit') is not null) as vw_billing_price_audit;
```

## 27. `sql/phase44_polar_ids_v2.sql`
Tables: 0 · Functions: 0 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase44_polar_ids_v2.sql
```
Is file mein naya table/function nahi (data ya policy patch hai). Verify: apply ke baad `select 1;` error-free + file ke andar likha hua apna check.

## 28. `sql/phase45_founder_identity.sql`
Tables: 0 · Functions: 0 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase45_founder_identity.sql
```
Is file mein naya table/function nahi (data ya policy patch hai). Verify: apply ke baad `select 1;` error-free + file ke andar likha hua apna check.

## 29. `sql/phase46_pricing_v5.sql`
Tables: 0 · Functions: 1 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase46_pricing_v5.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='movein_price_for') as fn_movein_price_for;
```

## 30. `sql/phase47_glitch_whatsapp.sql`
Tables: 4 · Functions: 7 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase47_glitch_whatsapp.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.customer_glitch_logs') is not null) as tbl_customer_glitch_logs,
  (to_regclass('public.feedback_user_triggers') is not null) as tbl_feedback_user_triggers,
  (to_regclass('public.glitch_alerts') is not null) as tbl_glitch_alerts,
  (to_regclass('public.glitch_noise_rules') is not null) as tbl_glitch_noise_rules,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='glitch_alert_due') as fn_glitch_alert_due,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='glitch_alert_mark') as fn_glitch_alert_mark,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='glitch_health') as fn_glitch_health,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='glitch_is_noise') as fn_glitch_is_noise,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='glitch_log') as fn_glitch_log,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='glitch_trigger_log') as fn_glitch_trigger_log,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='greatest_severity') as fn_greatest_severity;
```

## 31. `sql/phase48_storage_quota.sql`
Tables: 4 · Functions: 9 · Views: 1
```bash
cd /opt/anexomail-web && git pull && cat sql/phase48_storage_quota.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.mailbox_storage') is not null) as tbl_mailbox_storage,
  (to_regclass('public.storage_events') is not null) as tbl_storage_events,
  (to_regclass('public.storage_plans') is not null) as tbl_storage_plans,
  (to_regclass('public.storage_volumes') is not null) as tbl_storage_volumes,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='storage_can_accept') as fn_storage_can_accept,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='storage_capacity_sweep') as fn_storage_capacity_sweep,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='storage_commit') as fn_storage_commit,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='storage_plan_of') as fn_storage_plan_of,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='storage_purge') as fn_storage_purge,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='storage_release') as fn_storage_release,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='storage_reserve') as fn_storage_reserve,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='storage_state') as fn_storage_state,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='storage_volume_register') as fn_storage_volume_register,
  (to_regclass('public.storage_capacity_health') is not null) as vw_storage_capacity_health;
```

## 32. `sql/phase49_absm_billing_mesh.sql`
Tables: 9 · Functions: 8 · Views: 2
```bash
cd /opt/anexomail-web && git pull && cat sql/phase49_absm_billing_mesh.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.billing_failures') is not null) as tbl_billing_failures,
  (to_regclass('public.billing_inbox') is not null) as tbl_billing_inbox,
  (to_regclass('public.billing_observations') is not null) as tbl_billing_observations,
  (to_regclass('public.billing_outbox') is not null) as tbl_billing_outbox,
  (to_regclass('public.billing_receipts') is not null) as tbl_billing_receipts,
  (to_regclass('public.billing_reconciliation_items') is not null) as tbl_billing_reconciliation_items,
  (to_regclass('public.billing_reconciliation_runs') is not null) as tbl_billing_reconciliation_runs,
  (to_regclass('public.billing_state_versions') is not null) as tbl_billing_state_versions,
  (to_regclass('public.billing_watermarks') is not null) as tbl_billing_watermarks,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_guest_intent_claim') as fn_billing_guest_intent_claim,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_guest_intent_open') as fn_billing_guest_intent_open,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_inbox_apply') as fn_billing_inbox_apply,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_outbox_ack') as fn_billing_outbox_ack,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_reconcile_begin') as fn_billing_reconcile_begin,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_reconcile_finish') as fn_billing_reconcile_finish,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_state_apply') as fn_billing_state_apply,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_state_hash') as fn_billing_state_hash,
  (to_regclass('public.billing_mesh_health') is not null) as vw_billing_mesh_health,
  (to_regclass('public.billing_reconcile_queue') is not null) as vw_billing_reconcile_queue;
```

## 33. `sql/phase49b_hotfix_random_token.sql`
Tables: 0 · Functions: 2 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase49b_hotfix_random_token.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_guest_intent_open') as fn_billing_guest_intent_open,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='billing_state_hash') as fn_billing_state_hash;
```

## 34. `sql/phase50_polar_rust_payment.sql`
Tables: 4 · Functions: 2 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase50_polar_rust_payment.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.polar_checkout_log') is not null) as tbl_polar_checkout_log,
  (to_regclass('public.polar_mail_outbox') is not null) as tbl_polar_mail_outbox,
  (to_regclass('public.polar_subscriptions') is not null) as tbl_polar_subscriptions,
  (to_regclass('public.polar_webhook_inbox') is not null) as tbl_polar_webhook_inbox,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='polar_billing_state') as fn_polar_billing_state,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='polar_inbox_apply') as fn_polar_inbox_apply;
```

## 35. `sql/phase51_polar_payment_hardening.sql`
Tables: 3 · Functions: 1 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase51_polar_payment_hardening.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.polar_payment_alerts') is not null) as tbl_polar_payment_alerts,
  (to_regclass('public.polar_reconcile_log') is not null) as tbl_polar_reconcile_log,
  (to_regclass('public.polar_signature_rejects') is not null) as tbl_polar_signature_rejects,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='polar_payment_pulse') as fn_polar_payment_pulse;
```

## 36. `sql/phase12a_mail_prediction.sql`
Tables: 2 · Functions: 3 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase12a_mail_prediction.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.mail_predict_events') is not null) as tbl_mail_predict_events,
  (to_regclass('public.mail_predict_phrases') is not null) as tbl_mail_predict_phrases,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='mail_predict') as fn_mail_predict,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='mail_predict_event') as fn_mail_predict_event,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='mail_predict_learn') as fn_mail_predict_learn;
```

## 37. `sql/phase52_mail_launch.sql`
Tables: 7 · Functions: 3 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase52_mail_launch.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.mail_attachments') is not null) as tbl_mail_attachments,
  (to_regclass('public.mail_domains') is not null) as tbl_mail_domains,
  (to_regclass('public.mail_inbound_raw') is not null) as tbl_mail_inbound_raw,
  (to_regclass('public.mail_messages') is not null) as tbl_mail_messages,
  (to_regclass('public.mail_outbox_log') is not null) as tbl_mail_outbox_log,
  (to_regclass('public.mail_threads') is not null) as tbl_mail_threads,
  (to_regclass('public.mailboxes') is not null) as tbl_mailboxes,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='mail_append_only') as fn_mail_append_only,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='mail_ingest') as fn_mail_ingest,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='mail_outbox_record') as fn_mail_outbox_record;
```

## 38. `sql/phase_wire_founder.sql`
Tables: 6 · Functions: 0 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat sql/phase_wire_founder.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.ai_agents') is not null) as tbl_ai_agents,
  (to_regclass('public.founder_accounts') is not null) as tbl_founder_accounts,
  (to_regclass('public.leo_email_drafts') is not null) as tbl_leo_email_drafts,
  (to_regclass('public.mail_domains') is not null) as tbl_mail_domains,
  (to_regclass('public.mail_outbox') is not null) as tbl_mail_outbox,
  (to_regclass('public.mailboxes') is not null) as tbl_mailboxes;
```

## 39. `anexochat/sql/anexochat_phase01_foundation.sql`
Tables: 11 · Functions: 11 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/anexochat_phase01_foundation.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_atmosphere_prefs') is not null) as tbl_chat_atmosphere_prefs,
  (to_regclass('public.chat_conversations') is not null) as tbl_chat_conversations,
  (to_regclass('public.chat_file_chunks') is not null) as tbl_chat_file_chunks,
  (to_regclass('public.chat_files') is not null) as tbl_chat_files,
  (to_regclass('public.chat_members') is not null) as tbl_chat_members,
  (to_regclass('public.chat_message_receipts') is not null) as tbl_chat_message_receipts,
  (to_regclass('public.chat_messages') is not null) as tbl_chat_messages,
  (to_regclass('public.chat_participants') is not null) as tbl_chat_participants,
  (to_regclass('public.chat_presence') is not null) as tbl_chat_presence,
  (to_regclass('public.chat_typing') is not null) as tbl_chat_typing,
  (to_regclass('public.chat_workspaces') is not null) as tbl_chat_workspaces,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_access') as fn_chat_access,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_conversation_list') as fn_chat_conversation_list,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_direct_conversation') as fn_chat_direct_conversation,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_ensure_workspace') as fn_chat_ensure_workspace,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_in_conversation') as fn_chat_in_conversation,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_is_member') as fn_chat_is_member,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_mark') as fn_chat_mark,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_messages_page') as fn_chat_messages_page,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_presence_ping') as fn_chat_presence_ping,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_send') as fn_chat_send,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_typing_ping') as fn_chat_typing_ping;
```

## 40. `anexochat/sql/anexochat_phase03_message_engine.sql`
Tables: 5 · Functions: 9 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/anexochat_phase03_message_engine.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_audit') is not null) as tbl_chat_audit,
  (to_regclass('public.chat_conversation_state') is not null) as tbl_chat_conversation_state,
  (to_regclass('public.chat_message_edits') is not null) as tbl_chat_message_edits,
  (to_regclass('public.chat_reactions') is not null) as tbl_chat_reactions,
  (to_regclass('public.chat_work_items') is not null) as tbl_chat_work_items,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_conversation_set_state') as fn_chat_conversation_set_state,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_delete_message') as fn_chat_delete_message,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_edit_message') as fn_chat_edit_message,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_log') as fn_chat_log,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_react') as fn_chat_react,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_unread_total') as fn_chat_unread_total,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_work_create') as fn_chat_work_create,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_work_list') as fn_chat_work_list,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_work_set_state') as fn_chat_work_set_state;
```

## 41. `anexochat/sql/anexochat_phase07_cinema_video.sql`
Tables: 2 · Functions: 11 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/anexochat_phase07_cinema_video.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_message_hidden') is not null) as tbl_chat_message_hidden,
  (to_regclass('public.chat_signals') is not null) as tbl_chat_signals,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_conversation_prefs') as fn_chat_conversation_prefs,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_delete_message') as fn_chat_delete_message,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_edit_message') as fn_chat_edit_message,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_message_hide') as fn_chat_message_hide,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_messages_page') as fn_chat_messages_page,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_pin_message') as fn_chat_pin_message,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_search_messages') as fn_chat_search_messages,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_send') as fn_chat_send,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_signal_poll') as fn_chat_signal_poll,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_signal_send') as fn_chat_signal_send,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_video_allowed') as fn_chat_video_allowed;
```

## 42. `anexochat/sql/anexochat_phase10a_call_engine.sql`
Tables: 2 · Functions: 6 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/anexochat_phase10a_call_engine.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_call_sessions') is not null) as tbl_chat_call_sessions,
  (to_regclass('public.chat_call_stats') is not null) as tbl_chat_call_stats,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_call_end') as fn_chat_call_end,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_call_health') as fn_chat_call_health,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_call_recent') as fn_chat_call_recent,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_call_start') as fn_chat_call_start,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_call_stat') as fn_chat_call_stat,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_is_founder') as fn_chat_is_founder;
```

## 43. `anexochat/sql/anexochat_phase10b_8k_video.sql`
Tables: 2 · Functions: 1 · Views: 1
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/anexochat_phase10b_8k_video.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_call_sessions') is not null) as tbl_chat_call_sessions,
  (to_regclass('public.chat_call_stats') is not null) as tbl_chat_call_stats,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_call_stat') as fn_chat_call_stat,
  (to_regclass('public.chat_call_resolution_truth') is not null) as vw_chat_call_resolution_truth;
```

## 44. `anexochat/sql/anexochat_phase11_attachments.sql`
Tables: 1 · Functions: 4 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/anexochat_phase11_attachments.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_attachments') is not null) as tbl_chat_attachments,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_attachment_attach') as fn_chat_attachment_attach,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_attachment_commit') as fn_chat_attachment_commit,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_attachment_new') as fn_chat_attachment_new,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_avatar_set') as fn_chat_avatar_set;
```

## 45. `anexochat/sql/anexochat_phase11b_attachment_flag.sql`
Tables: 0 · Functions: 1 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/anexochat_phase11b_attachment_flag.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_messages_page') as fn_chat_messages_page;
```

## 46. `anexochat/sql/anexochat_phase12_continuity.sql`
Tables: 3 · Functions: 5 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/anexochat_phase12_continuity.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_devices') is not null) as tbl_chat_devices,
  (to_regclass('public.chat_drafts') is not null) as tbl_chat_drafts,
  (to_regclass('public.chat_positions') is not null) as tbl_chat_positions,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_continuity') as fn_chat_continuity,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_device_seen') as fn_chat_device_seen,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_draft_save') as fn_chat_draft_save,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_position_save') as fn_chat_position_save,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_search_deep') as fn_chat_search_deep;
```

## 47. `anexochat/sql/phase13_15_file_engine.sql`
Tables: 6 · Functions: 9 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/phase13_15_file_engine.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_file_chunks') is not null) as tbl_chat_file_chunks,
  (to_regclass('public.chat_file_versions') is not null) as tbl_chat_file_versions,
  (to_regclass('public.chat_files') is not null) as tbl_chat_files,
  (to_regclass('public.chat_transfer_ledger') is not null) as tbl_chat_transfer_ledger,
  (to_regclass('public.chat_transfers') is not null) as tbl_chat_transfers,
  (to_regclass('public.file_plan_limits') is not null) as tbl_file_plan_limits,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_chunk_ack') as fn_file_chunk_ack,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_commit') as fn_file_commit,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_engine_state') as fn_file_engine_state,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_plan_for') as fn_file_plan_for,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_pool_state') as fn_file_pool_state,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_transfer_begin') as fn_file_transfer_begin,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_transfer_mark') as fn_file_transfer_mark,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_transfer_state') as fn_file_transfer_state,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_versions') as fn_file_versions;
```

## 48. `anexochat/sql/phase16_18_file_truth_safety.sql`
Tables: 6 · Functions: 9 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/phase16_18_file_truth_safety.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.file_downloads') is not null) as tbl_file_downloads,
  (to_regclass('public.file_enforcement') is not null) as tbl_file_enforcement,
  (to_regclass('public.file_evidence') is not null) as tbl_file_evidence,
  (to_regclass('public.file_safety_events') is not null) as tbl_file_safety_events,
  (to_regclass('public.file_scan_jobs') is not null) as tbl_file_scan_jobs,
  (to_regclass('public.file_type_policy') is not null) as tbl_file_type_policy,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_commit') as fn_file_commit,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_download_ack') as fn_file_download_ack,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_evidence_for_transfer') as fn_file_evidence_for_transfer,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_evidence_mark') as fn_file_evidence_mark,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_safety_state') as fn_file_safety_state,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_scan_claim') as fn_file_scan_claim,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_scan_report') as fn_file_scan_report,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_truth') as fn_file_truth,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_type_verdict') as fn_file_type_verdict;
```

## 49. `anexochat/sql/phase19_22_device_safety_work.sql`
Tables: 12 · Functions: 21 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/phase19_22_device_safety_work.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_message_stars') is not null) as tbl_chat_message_stars,
  (to_regclass('public.chat_phase_entitlements') is not null) as tbl_chat_phase_entitlements,
  (to_regclass('public.chat_work_events') is not null) as tbl_chat_work_events,
  (to_regclass('public.chat_work_evidence') is not null) as tbl_chat_work_evidence,
  (to_regclass('public.device_bans') is not null) as tbl_device_bans,
  (to_regclass('public.device_trust_events') is not null) as tbl_device_trust_events,
  (to_regclass('public.device_vault') is not null) as tbl_device_vault,
  (to_regclass('public.device_vault_policy') is not null) as tbl_device_vault_policy,
  (to_regclass('public.safety_enforcement') is not null) as tbl_safety_enforcement,
  (to_regclass('public.safety_report_events') is not null) as tbl_safety_report_events,
  (to_regclass('public.safety_reports') is not null) as tbl_safety_reports,
  (to_regclass('public.safety_reveal_log') is not null) as tbl_safety_reveal_log,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_feature_allowed') as fn_chat_feature_allowed,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_message_forward') as fn_chat_message_forward,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_message_star') as fn_chat_message_star,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_work_board') as fn_chat_work_board,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_work_chain') as fn_chat_work_chain,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_work_complete') as fn_chat_work_complete,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_work_depend') as fn_chat_work_depend,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_work_from_message') as fn_chat_work_from_message,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_work_parse_due') as fn_chat_work_parse_due,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_work_suggest') as fn_chat_work_suggest,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='device_signal_class') as fn_device_signal_class,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='device_trust_list') as fn_device_trust_list,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='device_trust_set') as fn_device_trust_set,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='device_vault_purge') as fn_device_vault_purge,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='device_vault_register') as fn_device_vault_register,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='safety_can_review') as fn_safety_can_review,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='safety_my_standing') as fn_safety_my_standing,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='safety_queue') as fn_safety_queue,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='safety_report_advance') as fn_safety_report_advance,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='safety_report_create') as fn_safety_report_create,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='safety_report_reveal') as fn_safety_report_reveal;
```

## 50. `anexochat/sql/phase23_promise_engine.sql`
Tables: 2 · Functions: 8 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/phase23_promise_engine.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.device_ban_appeals') is not null) as tbl_device_ban_appeals,
  (to_regclass('public.promise_recovery_log') is not null) as tbl_promise_recovery_log,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='device_appeal_decide') as fn_device_appeal_decide,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='device_appeal_open') as fn_device_appeal_open,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='device_appeal_queue') as fn_device_appeal_queue,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='promise_board') as fn_promise_board,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='promise_history') as fn_promise_history,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='promise_keep') as fn_promise_keep,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='promise_recover') as fn_promise_recover,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='promise_state_of') as fn_promise_state_of;
```

## 51. `anexochat/sql/phase24_decision_ledger.sql`
Tables: 4 · Functions: 10 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/phase24_decision_ledger.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_decision_impact_log') is not null) as tbl_chat_decision_impact_log,
  (to_regclass('public.chat_decision_links') is not null) as tbl_chat_decision_links,
  (to_regclass('public.chat_decision_versions') is not null) as tbl_chat_decision_versions,
  (to_regclass('public.chat_decisions') is not null) as tbl_chat_decisions,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_decision_log_immutable') as fn_chat_decision_log_immutable,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_decision_versions_immutable') as fn_chat_decision_versions_immutable,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_feature_ok') as fn_chat_feature_ok,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='decision_amend') as fn_decision_amend,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='decision_board') as fn_decision_board,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='decision_impact') as fn_decision_impact,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='decision_link') as fn_decision_link,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='decision_mark') as fn_decision_mark,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='decision_state') as fn_decision_state,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='decision_unlink') as fn_decision_unlink;
```

## 52. `anexochat/sql/phase24a_account_integrity.sql`
Tables: 3 · Functions: 9 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/phase24a_account_integrity.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.account_integrity') is not null) as tbl_account_integrity,
  (to_regclass('public.account_integrity_log') is not null) as tbl_account_integrity_log,
  (to_regclass('public.account_integrity_policy') is not null) as tbl_account_integrity_policy,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='account_integrity_block') as fn_account_integrity_block,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='account_integrity_evaluate') as fn_account_integrity_evaluate,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='account_integrity_export_ready') as fn_account_integrity_export_ready,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='account_integrity_log_immutable') as fn_account_integrity_log_immutable,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='account_integrity_purge_due') as fn_account_integrity_purge_due,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='account_integrity_queue') as fn_account_integrity_queue,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='account_integrity_release') as fn_account_integrity_release,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='account_integrity_state') as fn_account_integrity_state,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='account_integrity_warn') as fn_account_integrity_warn;
```

## 53. `anexochat/sql/phase25_27_timeline_health_provenance.sql`
Tables: 4 · Functions: 14 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/phase25_27_timeline_health_provenance.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_message_important') is not null) as tbl_chat_message_important,
  (to_regclass('public.chat_message_provenance') is not null) as tbl_chat_message_provenance,
  (to_regclass('public.commitment_collision_events') is not null) as tbl_commitment_collision_events,
  (to_regclass('public.commitment_collisions') is not null) as tbl_commitment_collisions,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_feature_ok') as fn_chat_feature_ok,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_provenance_backfill') as fn_chat_provenance_backfill,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_provenance_immutable') as fn_chat_provenance_immutable,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_provenance_on_message') as fn_chat_provenance_on_message,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_provenance_seal') as fn_chat_provenance_seal,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='collision_log_immutable') as fn_collision_log_immutable,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='commitment_collision_act') as fn_commitment_collision_act,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='commitment_collision_scan') as fn_commitment_collision_scan,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='conversation_chain_verify') as fn_conversation_chain_verify,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='conversation_health') as fn_conversation_health,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='conversation_health_board') as fn_conversation_health_board,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='conversation_timeline') as fn_conversation_timeline,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='message_mark_important') as fn_message_mark_important,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='message_provenance') as fn_message_provenance;
```

## 54. `anexochat/sql/phase28_receipts.sql`
Tables: 6 · Functions: 15 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/phase28_receipts.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_handover_items') is not null) as tbl_chat_handover_items,
  (to_regclass('public.chat_handover_log') is not null) as tbl_chat_handover_log,
  (to_regclass('public.chat_handover_packs') is not null) as tbl_chat_handover_packs,
  (to_regclass('public.chat_message_files') is not null) as tbl_chat_message_files,
  (to_regclass('public.chat_receipt_certificates') is not null) as tbl_chat_receipt_certificates,
  (to_regclass('public.chat_receipt_devices') is not null) as tbl_chat_receipt_devices,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_handover_log_immutable') as fn_chat_handover_log_immutable,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_receipt_cert_immutable') as fn_chat_receipt_cert_immutable,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_receipt_devices_immutable') as fn_chat_receipt_devices_immutable,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='handover_assign') as fn_handover_assign,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='handover_complete') as fn_handover_complete,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='handover_pack_board') as fn_handover_pack_board,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='handover_pack_build') as fn_handover_pack_build,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='handover_pack_get') as fn_handover_pack_get,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='message_attach_file') as fn_message_attach_file,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='message_receipt_pack') as fn_message_receipt_pack,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='read_without_response') as fn_read_without_response,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='receipt_certificate_issue') as fn_receipt_certificate_issue,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='receipt_certificate_verify') as fn_receipt_certificate_verify,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='receipt_device_record') as fn_receipt_device_record,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='receipt_replay') as fn_receipt_replay;
```

## 55. `anexochat/sql/phase29_email_to_chat.sql`
Tables: 2 · Functions: 9 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/phase29_email_to_chat.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_email_links') is not null) as tbl_chat_email_links,
  (to_regclass('public.chat_email_quotes') is not null) as tbl_chat_email_quotes,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_email_quotes_immutable') as fn_chat_email_quotes_immutable,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='email_chat_context') as fn_email_chat_context,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='email_discuss_in_chat') as fn_email_discuss_in_chat,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='email_discuss_presence') as fn_email_discuss_presence,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='email_quote_to_chat') as fn_email_quote_to_chat,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='email_quote_verify') as fn_email_quote_verify,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='email_thread_conversation') as fn_email_thread_conversation,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='mail_thread_subject_safe') as fn_mail_thread_subject_safe,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='silent_thread_rescue') as fn_silent_thread_rescue;
```

## 56. `anexochat/sql/phase30_chat_to_email.sql`
Tables: 4 · Functions: 8 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/phase30_chat_to_email.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_email_consent') is not null) as tbl_chat_email_consent,
  (to_regclass('public.chat_email_draft_citations') is not null) as tbl_chat_email_draft_citations,
  (to_regclass('public.chat_email_drafts') is not null) as tbl_chat_email_drafts,
  (to_regclass('public.chat_message_escalations') is not null) as tbl_chat_message_escalations,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_email_appendonly') as fn_chat_email_appendonly,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_email_draft_board') as fn_chat_email_draft_board,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_email_draft_consent') as fn_chat_email_draft_consent,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_email_draft_create') as fn_chat_email_draft_create,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_email_draft_get') as fn_chat_email_draft_get,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_email_draft_send') as fn_chat_email_draft_send,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='decision_to_email') as fn_decision_to_email,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='message_escalations') as fn_message_escalations;
```

## 57. `anexochat/sql/phase31_file_context.sql`
Tables: 3 · Functions: 8 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/phase31_file_context.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_file_link_log') is not null) as tbl_chat_file_link_log,
  (to_regclass('public.chat_file_links') is not null) as tbl_chat_file_links,
  (to_regclass('public.chat_file_version_text') is not null) as tbl_chat_file_version_text,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_file_link_log_immutable') as fn_chat_file_link_log_immutable,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_context_card') as fn_file_context_card,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_duplicates') as fn_file_duplicates,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_link') as fn_file_link,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_relationship_graph') as fn_file_relationship_graph,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_stale_check') as fn_file_stale_check,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_unlink') as fn_file_unlink,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='file_version_diff') as fn_file_version_diff;
```

## 58. `anexochat/sql/videocall_phase31_call_record.sql`
Tables: 4 · Functions: 7 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/videocall_phase31_call_record.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_call_events') is not null) as tbl_chat_call_events,
  (to_regclass('public.chat_call_files') is not null) as tbl_chat_call_files,
  (to_regclass('public.chat_call_transport_events') is not null) as tbl_chat_call_transport_events,
  (to_regclass('public.chat_call_work') is not null) as tbl_chat_call_work,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_event_record') as fn_call_event_record,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_file_share') as fn_call_file_share,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_record') as fn_call_record,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_record_board') as fn_call_record_board,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_transport_record') as fn_call_transport_record,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_work_link') as fn_call_work_link,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_call_events_immutable') as fn_chat_call_events_immutable;
```

## 59. `anexochat/sql/videocall_phase31a_lightspeed.sql`
Tables: 6 · Functions: 13 · Views: 0
```bash
cd /opt/anexomail-web && git pull && cat anexochat/sql/videocall_phase31a_lightspeed.sql
```
Verify (Supabase SQL editor — sab `t` hona chahiye):

```sql
select
  (to_regclass('public.chat_call_connect_marks') is not null) as tbl_chat_call_connect_marks,
  (to_regclass('public.chat_call_ring_log') is not null) as tbl_chat_call_ring_log,
  (to_regclass('public.chat_call_rings') is not null) as tbl_chat_call_rings,
  (to_regclass('public.chat_call_sfu_participants') is not null) as tbl_chat_call_sfu_participants,
  (to_regclass('public.chat_call_sfu_rooms') is not null) as tbl_chat_call_sfu_rooms,
  (to_regclass('public.chat_call_survival') is not null) as tbl_chat_call_survival,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_connect_health') as fn_call_connect_health,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_connect_mark') as fn_call_connect_mark,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_connect_report') as fn_call_connect_report,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_ring_settle') as fn_call_ring_settle,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_ring_start') as fn_call_ring_start,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_ring_state') as fn_call_ring_state,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_sfu_join') as fn_call_sfu_join,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_sfu_leave') as fn_call_sfu_leave,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_sfu_room_ensure') as fn_call_sfu_room_ensure,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_sfu_state') as fn_call_sfu_state,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='call_survival_record') as fn_call_survival_record,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_call_connect_marks_immutable') as fn_chat_call_connect_marks_immutable,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='chat_call_ring_log_immutable') as fn_chat_call_ring_log_immutable;
```

---

## MASTER VERIFY — poori database ki sachi haalat

Yeh ek query sab kuch check karti hai. `missing` column khali hona chahiye.

```sql
with expected(kind, name) as (values
  ('table','agent_memory_config'),
  ('table','leo_memory_vectors'),
  ('function','leo_memory_prune'),
  ('function','leo_recall'),
  ('table','ai_studio_batches'),
  ('table','ai_studio_recipe_runs'),
  ('table','ai_studio_recipes'),
  ('table','ai_studio_runs'),
  ('table','ai_email_automations'),
  ('table','ai_rules'),
  ('table','ai_suggestions'),
  ('table','ai_variables'),
  ('table','ai_workflow_runs'),
  ('table','ai_workflow_steps'),
  ('table','ai_workflows'),
  ('table','ai_checkouts'),
  ('table','ai_credit_events'),
  ('table','ai_topup_packs'),
  ('table','ai_wallets'),
  ('table','knowledge_answers'),
  ('table','knowledge_chunks'),
  ('table','knowledge_documents'),
  ('table','knowledge_spaces'),
  ('function','knowledge_recall'),
  ('table','billing_payment_methods'),
  ('table','billing_tax_profiles'),
  ('table','workspace_invoices'),
  ('table','workspace_plans'),
  ('table','workspace_subscriptions'),
  ('table','delivery_blocklists'),
  ('table','delivery_checks'),
  ('table','integration_connections'),
  ('table','integration_exports'),
  ('table','integration_migration_items'),
  ('table','integration_migrations'),
  ('table','integration_providers'),
  ('table','leo_actions'),
  ('function','founder_integrations_overview'),
  ('table','setting_defs'),
  ('table','setting_explanations'),
  ('table','setting_schedules'),
  ('table','setting_values'),
  ('table','setting_versions'),
  ('table','analytics_attention_leaks'),
  ('table','analytics_debt_daily'),
  ('table','analytics_deep_work'),
  ('table','analytics_promises'),
  ('table','analytics_rates'),
  ('table','analytics_thread_cost'),
  ('function','founder_analytics_overview'),
  ('table','admin_delivery_events'),
  ('table','admin_diagnostic_probes'),
  ('table','admin_diagnostic_runs'),
  ('table','admin_health_checks'),
  ('table','admin_health_runs'),
  ('table','admin_incident_events'),
  ('table','admin_incidents'),
  ('table','admin_logs'),
  ('table','admin_reports'),
  ('table','admin_storage_snapshots'),
  ('function','founder_admin_overview'),
  ('table','security_anomalies'),
  ('table','security_devices'),
  ('table','security_encryption_surfaces'),
  ('table','security_key_ledger'),
  ('table','security_kill_switches'),
  ('table','security_ledger'),
  ('table','security_login_events'),
  ('table','security_proof_checks'),
  ('table','security_proofs'),
  ('table','security_sessions'),
  ('function','founder_security_overview'),
  ('table','perf_budgets'),
  ('table','perf_device_profiles'),
  ('table','perf_prefetch_events'),
  ('table','perf_regressions'),
  ('table','perf_releases'),
  ('table','perf_samples'),
  ('table','perf_search_traces'),
  ('table','perf_surface_starts'),
  ('function','founder_perf_overview'),
  ('table','revenue_accounts'),
  ('table','revenue_jobs'),
  ('table','revenue_leads'),
  ('table','revenue_partners'),
  ('table','revenue_targets'),
  ('table','device_handoff'),
  ('table','user_devices'),
  ('table','deployments'),
  ('table','mail_outbox'),
  ('table','release_checklist'),
  ('table','release_checks'),
  ('table','release_locks'),
  ('table','release_runs'),
  ('table','roadmap_items'),
  ('table','subscription_pipeline'),
  ('table','ai_actions'),
  ('table','ai_credit_grants'),
  ('table','ai_credit_ledger'),
  ('table','ai_credit_plans'),
  ('table','ai_credit_topup_products'),
  ('table','ai_credit_wallets'),
  ('function','ai_credits_complimentary'),
  ('function','ai_credits_release'),
  ('function','ai_credits_reserve'),
  ('function','ai_credits_settle'),
  ('function','ai_credits_topup'),
  ('function','ai_ledger_immutable'),
  ('table','reserved_handles'),
  ('table','trial_accounts'),
  ('table','trial_events'),
  ('table','trial_mail_holds'),
  ('function','account_state'),
  ('function','ai_enabled'),
  ('function','entitled_full'),
  ('function','trial_claim_address'),
  ('function','trial_events_immutable'),
  ('function','trial_set_security'),
  ('function','trial_start'),
  ('function','trial_subscribe'),
  ('function','trial_sweep'),
  ('table','polar_checkout_sessions'),
  ('table','polar_webhook_events'),
  ('table','billing_event_receipts'),
  ('table','founder_reply_queue'),
  ('function','block_billing_receipt_mutation'),
  ('function','close_founder_reply_clock'),
  ('function','enqueue_founder_reply'),
  ('function','queue_inbound_support_reply'),
  ('table','payment_alerts'),
  ('table','polar_webhook_raw'),
  ('function','webhook_capture_raw'),
  ('function','webhook_claim_retries'),
  ('function','webhook_mark_failed'),
  ('function','webhook_mark_processed'),
  ('table','payment_health'),
  ('table','payment_reconciliation_gaps'),
  ('table','billing_intents'),
  ('table','billing_state_log'),
  ('table','entitlement_state'),
  ('function','billing_apply_entitlement'),
  ('function','billing_intent_attach_checkout'),
  ('function','billing_intent_confirm'),
  ('function','billing_intent_open'),
  ('function','billing_sync_abandon_stale'),
  ('function','billing_sync_claim'),
  ('function','billing_sync_fail'),
  ('function','billing_sync_touch'),
  ('table','billing_state_health'),
  ('table','billing_truth_gaps'),
  ('table','movein_audit'),
  ('table','movein_capacity'),
  ('table','movein_deals'),
  ('table','movein_dns_checks'),
  ('table','movein_exceptions'),
  ('table','movein_mailboxes'),
  ('table','movein_payments'),
  ('table','movein_rollback_points'),
  ('table','movein_runbook'),
  ('table','movein_transitions'),
  ('table','movein_waitlist'),
  ('function','movein_arm_cutover'),
  ('function','movein_attach_intent'),
  ('function','movein_audit_immutable'),
  ('function','movein_band_for'),
  ('function','movein_book_slot'),
  ('function','movein_cockpit'),
  ('function','movein_customer_view'),
  ('function','movein_cutover_ready'),
  ('function','movein_dns_green'),
  ('function','movein_evidence_bundle'),
  ('function','movein_health'),
  ('function','movein_health_calc'),
  ('function','movein_leg_paid'),
  ('function','movein_next_reference'),
  ('function','movein_open_deal'),
  ('function','movein_price_for'),
  ('function','movein_seed_runbook'),
  ('function','movein_sync_payments'),
  ('function','movein_transition'),
  ('table','movein_attention'),
  ('table','movein_capacity_state'),
  ('table','movein_cash_clock'),
  ('table','movein_dns_proof'),
  ('table','movein_mailbox_gaps'),
  ('table','movein_reference_counter'),
  ('function','movein_data_verified_ok'),
  ('function','movein_dns_owner_fill'),
  ('function','movein_exception_blocks_fill'),
  ('function','movein_is_deal_member'),
  ('function','movein_promote_waitlist'),
  ('function','movein_rollback_create'),
  ('function','movein_rollback_use'),
  ('function','movein_rollback_validate'),
  ('table','movein_my_dns_proof'),
  ('table','movein_my_mailbox_gaps'),
  ('function','movein_evidence_validate'),
  ('table','movein_evidence_violations'),
  ('table','billing_price_book'),
  ('table','billing_polar_id_gaps'),
  ('table','billing_price_audit'),
  ('table','customer_glitch_logs'),
  ('table','feedback_user_triggers'),
  ('table','glitch_alerts'),
  ('table','glitch_noise_rules'),
  ('function','glitch_alert_due'),
  ('function','glitch_alert_mark'),
  ('function','glitch_health'),
  ('function','glitch_is_noise'),
  ('function','glitch_log'),
  ('function','glitch_trigger_log'),
  ('function','greatest_severity'),
  ('table','mailbox_storage'),
  ('table','storage_events'),
  ('table','storage_plans'),
  ('table','storage_volumes'),
  ('function','storage_can_accept'),
  ('function','storage_capacity_sweep'),
  ('function','storage_commit'),
  ('function','storage_plan_of'),
  ('function','storage_purge'),
  ('function','storage_release'),
  ('function','storage_reserve'),
  ('function','storage_state'),
  ('function','storage_volume_register'),
  ('table','storage_capacity_health'),
  ('table','billing_failures'),
  ('table','billing_inbox'),
  ('table','billing_observations'),
  ('table','billing_outbox'),
  ('table','billing_receipts'),
  ('table','billing_reconciliation_items'),
  ('table','billing_reconciliation_runs'),
  ('table','billing_state_versions'),
  ('table','billing_watermarks'),
  ('function','billing_guest_intent_claim'),
  ('function','billing_guest_intent_open'),
  ('function','billing_inbox_apply'),
  ('function','billing_outbox_ack'),
  ('function','billing_reconcile_begin'),
  ('function','billing_reconcile_finish'),
  ('function','billing_state_apply'),
  ('function','billing_state_hash'),
  ('table','billing_mesh_health'),
  ('table','billing_reconcile_queue'),
  ('table','polar_checkout_log'),
  ('table','polar_mail_outbox'),
  ('table','polar_subscriptions'),
  ('table','polar_webhook_inbox'),
  ('function','polar_billing_state'),
  ('function','polar_inbox_apply'),
  ('table','polar_payment_alerts'),
  ('table','polar_reconcile_log'),
  ('table','polar_signature_rejects'),
  ('function','polar_payment_pulse'),
  ('table','mail_predict_events'),
  ('table','mail_predict_phrases'),
  ('function','mail_predict'),
  ('function','mail_predict_event'),
  ('function','mail_predict_learn'),
  ('table','mail_attachments'),
  ('table','mail_domains'),
  ('table','mail_inbound_raw'),
  ('table','mail_messages'),
  ('table','mail_outbox_log'),
  ('table','mail_threads'),
  ('table','mailboxes'),
  ('function','mail_append_only'),
  ('function','mail_ingest'),
  ('function','mail_outbox_record'),
  ('table','ai_agents'),
  ('table','founder_accounts'),
  ('table','leo_email_drafts'),
  ('table','chat_atmosphere_prefs'),
  ('table','chat_conversations'),
  ('table','chat_file_chunks'),
  ('table','chat_files'),
  ('table','chat_members'),
  ('table','chat_message_receipts'),
  ('table','chat_messages'),
  ('table','chat_participants'),
  ('table','chat_presence'),
  ('table','chat_typing'),
  ('table','chat_workspaces'),
  ('function','chat_access'),
  ('function','chat_conversation_list'),
  ('function','chat_direct_conversation'),
  ('function','chat_ensure_workspace'),
  ('function','chat_in_conversation'),
  ('function','chat_is_member'),
  ('function','chat_mark'),
  ('function','chat_messages_page'),
  ('function','chat_presence_ping'),
  ('function','chat_send'),
  ('function','chat_typing_ping'),
  ('table','chat_audit'),
  ('table','chat_conversation_state'),
  ('table','chat_message_edits'),
  ('table','chat_reactions'),
  ('table','chat_work_items'),
  ('function','chat_conversation_set_state'),
  ('function','chat_delete_message'),
  ('function','chat_edit_message'),
  ('function','chat_log'),
  ('function','chat_react'),
  ('function','chat_unread_total'),
  ('function','chat_work_create'),
  ('function','chat_work_list'),
  ('function','chat_work_set_state'),
  ('table','chat_message_hidden'),
  ('table','chat_signals'),
  ('function','chat_conversation_prefs'),
  ('function','chat_message_hide'),
  ('function','chat_pin_message'),
  ('function','chat_search_messages'),
  ('function','chat_signal_poll'),
  ('function','chat_signal_send'),
  ('function','chat_video_allowed'),
  ('table','chat_call_sessions'),
  ('table','chat_call_stats'),
  ('function','chat_call_end'),
  ('function','chat_call_health'),
  ('function','chat_call_recent'),
  ('function','chat_call_start'),
  ('function','chat_call_stat'),
  ('function','chat_is_founder'),
  ('table','chat_call_resolution_truth'),
  ('table','chat_attachments'),
  ('function','chat_attachment_attach'),
  ('function','chat_attachment_commit'),
  ('function','chat_attachment_new'),
  ('function','chat_avatar_set'),
  ('table','chat_devices'),
  ('table','chat_drafts'),
  ('table','chat_positions'),
  ('function','chat_continuity'),
  ('function','chat_device_seen'),
  ('function','chat_draft_save'),
  ('function','chat_position_save'),
  ('function','chat_search_deep'),
  ('table','chat_file_versions'),
  ('table','chat_transfer_ledger'),
  ('table','chat_transfers'),
  ('table','file_plan_limits'),
  ('function','file_chunk_ack'),
  ('function','file_commit'),
  ('function','file_engine_state'),
  ('function','file_plan_for'),
  ('function','file_pool_state'),
  ('function','file_transfer_begin'),
  ('function','file_transfer_mark'),
  ('function','file_transfer_state'),
  ('function','file_versions'),
  ('table','file_downloads'),
  ('table','file_enforcement'),
  ('table','file_evidence'),
  ('table','file_safety_events'),
  ('table','file_scan_jobs'),
  ('table','file_type_policy'),
  ('function','file_download_ack'),
  ('function','file_evidence_for_transfer'),
  ('function','file_evidence_mark'),
  ('function','file_safety_state'),
  ('function','file_scan_claim'),
  ('function','file_scan_report'),
  ('function','file_truth'),
  ('function','file_type_verdict'),
  ('table','chat_message_stars'),
  ('table','chat_phase_entitlements'),
  ('table','chat_work_events'),
  ('table','chat_work_evidence'),
  ('table','device_bans'),
  ('table','device_trust_events'),
  ('table','device_vault'),
  ('table','device_vault_policy'),
  ('table','safety_enforcement'),
  ('table','safety_report_events'),
  ('table','safety_reports'),
  ('table','safety_reveal_log'),
  ('function','chat_feature_allowed'),
  ('function','chat_message_forward'),
  ('function','chat_message_star'),
  ('function','chat_work_board'),
  ('function','chat_work_chain'),
  ('function','chat_work_complete'),
  ('function','chat_work_depend'),
  ('function','chat_work_from_message'),
  ('function','chat_work_parse_due'),
  ('function','chat_work_suggest'),
  ('function','device_signal_class'),
  ('function','device_trust_list'),
  ('function','device_trust_set'),
  ('function','device_vault_purge'),
  ('function','device_vault_register'),
  ('function','safety_can_review'),
  ('function','safety_my_standing'),
  ('function','safety_queue'),
  ('function','safety_report_advance'),
  ('function','safety_report_create'),
  ('function','safety_report_reveal'),
  ('table','device_ban_appeals'),
  ('table','promise_recovery_log'),
  ('function','device_appeal_decide'),
  ('function','device_appeal_open'),
  ('function','device_appeal_queue'),
  ('function','promise_board'),
  ('function','promise_history'),
  ('function','promise_keep'),
  ('function','promise_recover'),
  ('function','promise_state_of'),
  ('table','chat_decision_impact_log'),
  ('table','chat_decision_links'),
  ('table','chat_decision_versions'),
  ('table','chat_decisions'),
  ('function','chat_decision_log_immutable'),
  ('function','chat_decision_versions_immutable'),
  ('function','chat_feature_ok'),
  ('function','decision_amend'),
  ('function','decision_board'),
  ('function','decision_impact'),
  ('function','decision_link'),
  ('function','decision_mark'),
  ('function','decision_state'),
  ('function','decision_unlink'),
  ('table','account_integrity'),
  ('table','account_integrity_log'),
  ('table','account_integrity_policy'),
  ('function','account_integrity_block'),
  ('function','account_integrity_evaluate'),
  ('function','account_integrity_export_ready'),
  ('function','account_integrity_log_immutable'),
  ('function','account_integrity_purge_due'),
  ('function','account_integrity_queue'),
  ('function','account_integrity_release'),
  ('function','account_integrity_state'),
  ('function','account_integrity_warn'),
  ('table','chat_message_important'),
  ('table','chat_message_provenance'),
  ('table','commitment_collision_events'),
  ('table','commitment_collisions'),
  ('function','chat_provenance_backfill'),
  ('function','chat_provenance_immutable'),
  ('function','chat_provenance_on_message'),
  ('function','chat_provenance_seal'),
  ('function','collision_log_immutable'),
  ('function','commitment_collision_act'),
  ('function','commitment_collision_scan'),
  ('function','conversation_chain_verify'),
  ('function','conversation_health'),
  ('function','conversation_health_board'),
  ('function','conversation_timeline'),
  ('function','message_mark_important'),
  ('function','message_provenance'),
  ('table','chat_handover_items'),
  ('table','chat_handover_log'),
  ('table','chat_handover_packs'),
  ('table','chat_message_files'),
  ('table','chat_receipt_certificates'),
  ('table','chat_receipt_devices'),
  ('function','chat_handover_log_immutable'),
  ('function','chat_receipt_cert_immutable'),
  ('function','chat_receipt_devices_immutable'),
  ('function','handover_assign'),
  ('function','handover_complete'),
  ('function','handover_pack_board'),
  ('function','handover_pack_build'),
  ('function','handover_pack_get'),
  ('function','message_attach_file'),
  ('function','message_receipt_pack'),
  ('function','read_without_response'),
  ('function','receipt_certificate_issue'),
  ('function','receipt_certificate_verify'),
  ('function','receipt_device_record'),
  ('function','receipt_replay'),
  ('table','chat_email_links'),
  ('table','chat_email_quotes'),
  ('function','chat_email_quotes_immutable'),
  ('function','email_chat_context'),
  ('function','email_discuss_in_chat'),
  ('function','email_discuss_presence'),
  ('function','email_quote_to_chat'),
  ('function','email_quote_verify'),
  ('function','email_thread_conversation'),
  ('function','mail_thread_subject_safe'),
  ('function','silent_thread_rescue'),
  ('table','chat_email_consent'),
  ('table','chat_email_draft_citations'),
  ('table','chat_email_drafts'),
  ('table','chat_message_escalations'),
  ('function','chat_email_appendonly'),
  ('function','chat_email_draft_board'),
  ('function','chat_email_draft_consent'),
  ('function','chat_email_draft_create'),
  ('function','chat_email_draft_get'),
  ('function','chat_email_draft_send'),
  ('function','decision_to_email'),
  ('function','message_escalations'),
  ('table','chat_file_link_log'),
  ('table','chat_file_links'),
  ('table','chat_file_version_text'),
  ('function','chat_file_link_log_immutable'),
  ('function','file_context_card'),
  ('function','file_duplicates'),
  ('function','file_link'),
  ('function','file_relationship_graph'),
  ('function','file_stale_check'),
  ('function','file_unlink'),
  ('function','file_version_diff'),
  ('table','chat_call_events'),
  ('table','chat_call_files'),
  ('table','chat_call_transport_events'),
  ('table','chat_call_work'),
  ('function','call_event_record'),
  ('function','call_file_share'),
  ('function','call_record'),
  ('function','call_record_board'),
  ('function','call_transport_record'),
  ('function','call_work_link'),
  ('function','chat_call_events_immutable'),
  ('table','chat_call_connect_marks'),
  ('table','chat_call_ring_log'),
  ('table','chat_call_rings'),
  ('table','chat_call_sfu_participants'),
  ('table','chat_call_sfu_rooms'),
  ('table','chat_call_survival'),
  ('function','call_connect_health'),
  ('function','call_connect_mark'),
  ('function','call_connect_report'),
  ('function','call_ring_settle'),
  ('function','call_ring_start'),
  ('function','call_ring_state'),
  ('function','call_sfu_join'),
  ('function','call_sfu_leave'),
  ('function','call_sfu_room_ensure'),
  ('function','call_sfu_state'),
  ('function','call_survival_record'),
  ('function','chat_call_connect_marks_immutable'),
  ('function','chat_call_ring_log_immutable')
)
select kind, name as missing from expected e
where (e.kind = 'table'    and to_regclass('public.'||e.name) is null)
   or (e.kind = 'function' and not exists (
        select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname = e.name))
order by kind, name;
```

Zero row = saari SQL wired. Jo row aaye, wahi file dobara apply karo.

### GRANT check (PostgREST ke liye lazmi)

```sql
select c.relname as table_without_grants
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r'
   and not has_table_privilege('authenticated', c.oid, 'SELECT')
   and not has_table_privilege('service_role', c.oid, 'SELECT')
 order by 1;
```

Zero row chahiye. Row aaye to us table ki file mein `grant` block missing hai — batao, main add karunga.

### RLS check

```sql
select c.relname as table_without_rls
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity = false
 order by 1;
```
