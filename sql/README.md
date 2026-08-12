# ANEXOMAIL — SQL blocks (Supabase #4)

Rule: har phase ka SQL isi folder mein rehta hai, repo ke andar. Founder Supabase
SQL editor mein poori file copy-paste karta hai. Koi migration tool nahi.

Har file locked rules follow karti hai:

- **Idempotent + self-healing** — purani conflicting table `_legacy_<ts>` ban jati hai,
  phir fresh create hoti hai. Sirf `if not exists` kaafi nahi (column mismatch).
- **Grants pehle, phir RLS** — `authenticated` + `service_role` grants, uske baad
  `enable row level security` aur `own_rows` policy (`user_id = auth.uid()`).
- **Supabase = source of truth** — table pehle yahan, phir code mein.

| File | Phase | Kya banata hai |
| --- | --- | --- |
| `phase17_ai_studio.sql` | 17 | AI Studio runs, recipes, recipe steps, batches |
| `phase18_ai_automation.sql` | 18 | Workflows, steps, runs, rules, variables, suggestions, email automations |
| `phase19_ai_billing.sql` | 19 | AI wallet, credit events ledger, top-up packs (£135/£300/£1000/£2000), sandbox checkouts |
| `phase20_ai_knowledge.sql` | 20 | Knowledge spaces, documents, chunks (pg_trgm), answers with citations, `knowledge_recall()` RPC |
| `phase21_billing_platform.sql` | 21 | Workspace plans (£20/£40/£85), subscriptions, invoices, tax profiles, payment methods |
| `phase22_integrations.sql` | 22 | Provider catalog (Gmail/Workspace/Outlook/M365/Zoho/Proton/IMAP/SMTP), connections, migration jobs + per-item log, delivery proof checks + blocklists, export jobs, Leo Actions, `founder_integrations_overview()` |
| `phase23_settings.sql` | 23 | Setting catalog + values, Time Machine versions (blast snapshot), scheduled change + auto-rollback, Leo explanations, 14 real seeded settings |
| `phase24_analytics.sql` | 24 | Cost rates (£/hour), response-debt daily snapshots, thread cost ledger, deep-work map, attention leaks, promise SLA, `founder_analytics_overview()` |
| `phase25_admin.sql` | 25 | Admin Center: self-healing health checks + heal proof runs, storage snapshots (forecast), incidents + timeline events, delivery watchtower events, log lens (pg_trgm), organisation reports, diagnostic runs + probes, `founder_admin_overview()` |
| `phase26_security.sql` | 26 | Security Platform: device trust registry (fingerprint + trust score, API keys retired), sessions, login replay events, anomalies (impossible travel freeze), encryption surfaces + key ledger, ownership proof packs + checks, kill switches, hash-chained `security_ledger`, `founder_security_overview()` |
| `phase27_perf.sql` | 27 | Performance Platform: speed budgets (7 real seeded budgets) + samples (p50/p95/p99), prefetch hit/miss + ms saved, cold-start surface map, query-lab stage traces, device performance twins, releases + regressions, `founder_perf_overview()` |
| `phase28_revenue.sql` | 28 | Revenue Engine (no AI): `revenue_leads` (public migration/partner/SLA requests with reference + quote), `revenue_accounts` (plan, seats, MRR, SLA add-on), `revenue_jobs` (migration one-off £500–£2,000 pipeline), `revenue_partners` (20/25/30% commission ladder, live seats), `revenue_targets` (monthly £ target, seeded £500) |
| `phase30_release.sql` | 30 | Production & Founder Lock: `release_runs` + `release_checks` (60+ live probes), `release_checklist` (24 real seeded items), `deployments` (commit sha, actor, rollback trail), `release_locks` (append-only signature ledger), `roadmap_items` (v2.0 board, 8 seeded), `mail_outbox` Phase 30 columns (user_id + idempotency_key, additive), `subscription_pipeline` (migration lead -> MRR) |
| `phase_wire_founder.sql` | wiring · page 1 | Founder Command Deck + AI Email Center: mailboxes registry (17 real addresses), mail_domains, ai_agents roster, leo_email_drafts, mail_outbox, founder_accounts |
| `phase_leo_memory.sql` | leo brain | LEO 3M-message memory: `leo_memory_vectors` (working/episodic/semantic + pgvector), `agent_memory_config` tiers (Jimmy 3M · Leo 3M · Sherlock 1M · Industry 100K), `leo_recall()` RPC, `leo_memory_prune()` cap |

Chalane ki tarteeb: file number ke hisaab se (17 → 18 → 19 → 20 → 21 → 22 → 23 → 24 → 25 → 26 → 27 → 28 → 30), phir `phase_wire_*` files.
| `phase31_ai_credits.sql` | 31 | AI Credit Engine: `ai_credit_wallets` (subscription/top-up/complimentary/reserved buckets), immutable `ai_credit_ledger` (update/delete blocked by trigger), locked `ai_credit_topup_products` (9 packs, £5,000 pack founder-only), `ai_credit_plans` (£135/400 · £300/1,200 · £1,000/5,000 · £2,000/10,000), `ai_actions` (pre-flight → reserve → settle, provider cost alag), `ai_credit_grants` (5+5 complimentary once per cycle), RPCs `ai_credits_reserve` / `ai_credits_settle` / `ai_credits_release` / `ai_credits_topup` / `ai_credits_complimentary` |
| `phase32_trial.sql` | 32 | Trial lifecycle: `trial_accounts` (48h timer, status trial|active|expired|frozen|released, plan, passkey/recovery flags, 30-day address reservation), immutable `trial_events` ledger with **idempotent** warn_24h/warn_2h/expired/frozen/released unique index, `reserved_handles` (awam ko admin/hello/billing/postmaster block), `trial_mail_holds` (frozen mailbox ki mail held/rejected — kabhi silently discard nahi), authority `account_state()` + `entitled_full()` + `ai_enabled()` (trial/expired/frozen = AI hard zero), RPCs `trial_start`/`trial_claim_address`/`trial_set_security`/`trial_subscribe`, hourly `trial_sweep()` + pg_cron job |
