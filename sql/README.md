# ANEXOMAIL — SQL blocks (Supabase #4)

Rule: har phase ka SQL isi folder mein rehta hai, repo ke andar. Founder Supabase
SQL editor mein poori file copy-paste karta hai. Koi migration tool nahi.

Har file locked rules follow karti hai:

- **Idempotent + self-healing** — purani conflicting table `_legacy_<ts>` ban jati hai,
  phir fresh create hoti hai. Sirf `if not exists` kaafi nahi (column mismatch).
- **Grants pehle, phir RLS** — `authenticated` + `service_role` grants, uske baad
  `enable row level security` aur `own_rows` policy (`user_id = auth.uid()`).
- **Supabase = source of truth** — table pehle yahan, phir code mein.

| File                           | Phase           | Kya banata hai                                                                                                                                                                                                                                                                                                                                                                               |
| ------------------------------ | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `phase17_ai_studio.sql`        | 17              | AI Studio runs, recipes, recipe steps, batches                                                                                                                                                                                                                                                                                                                                               |
| `phase18_ai_automation.sql`    | 18              | Workflows, steps, runs, rules, variables, suggestions, email automations                                                                                                                                                                                                                                                                                                                     |
| `phase19_ai_billing.sql`       | 19              | AI wallet, credit events ledger, top-up packs (£135/£300/£1000/£2000), sandbox checkouts                                                                                                                                                                                                                                                                                                     |
| `phase20_ai_knowledge.sql`     | 20              | Knowledge spaces, documents, chunks (pg_trgm), answers with citations, `knowledge_recall()` RPC                                                                                                                                                                                                                                                                                              |
| `phase21_billing_platform.sql` | 21              | Workspace plans (£20/£40/£85), subscriptions, invoices, tax profiles, payment methods                                                                                                                                                                                                                                                                                                        |
| `phase22_integrations.sql`     | 22              | Provider catalog (Gmail/Workspace/Outlook/M365/Zoho/Proton/IMAP/SMTP), connections, migration jobs + per-item log, delivery proof checks + blocklists, export jobs, Leo Actions, `founder_integrations_overview()`                                                                                                                                                                           |
| `phase23_settings.sql`         | 23              | Setting catalog + values, Time Machine versions (blast snapshot), scheduled change + auto-rollback, Leo explanations, 14 real seeded settings                                                                                                                                                                                                                                                |
| `phase24_analytics.sql`        | 24              | Cost rates (£/hour), response-debt daily snapshots, thread cost ledger, deep-work map, attention leaks, promise SLA, `founder_analytics_overview()`                                                                                                                                                                                                                                          |
| `phase25_admin.sql`            | 25              | Admin Center: self-healing health checks + heal proof runs, storage snapshots (forecast), incidents + timeline events, delivery watchtower events, log lens (pg_trgm), organisation reports, diagnostic runs + probes, `founder_admin_overview()`                                                                                                                                            |
| `phase26_security.sql`         | 26              | Security Platform: device trust registry (fingerprint + trust score, API keys retired), sessions, login replay events, anomalies (impossible travel freeze), encryption surfaces + key ledger, ownership proof packs + checks, kill switches, hash-chained `security_ledger`, `founder_security_overview()`                                                                                  |
| `phase27_perf.sql`             | 27              | Performance Platform: speed budgets (7 real seeded budgets) + samples (p50/p95/p99), prefetch hit/miss + ms saved, cold-start surface map, query-lab stage traces, device performance twins, releases + regressions, `founder_perf_overview()`                                                                                                                                               |
| `phase28_revenue.sql`          | 28              | Revenue Engine (no AI): `revenue_leads` (public migration/partner/SLA requests with reference + quote), `revenue_accounts` (plan, seats, MRR, SLA add-on), `revenue_jobs` (migration one-off £500–£2,000 pipeline), `revenue_partners` (20/25/30% commission ladder, live seats), `revenue_targets` (monthly £ target, seeded £500)                                                          |
| `phase30_release.sql`          | 30              | Production & Founder Lock: `release_runs` + `release_checks` (60+ live probes), `release_checklist` (24 real seeded items), `deployments` (commit sha, actor, rollback trail), `release_locks` (append-only signature ledger), `roadmap_items` (v2.0 board, 8 seeded), `mail_outbox` Phase 30 columns (user_id + idempotency_key, additive), `subscription_pipeline` (migration lead -> MRR) |
| `phase_wire_founder.sql`       | wiring · page 1 | Founder Command Deck + AI Email Center: mailboxes registry (17 real addresses), mail_domains, ai_agents roster, leo_email_drafts, mail_outbox, founder_accounts                                                                                                                                                                                                                              |
| `phase_leo_memory.sql`         | leo brain       | LEO 3M-message memory: `leo_memory_vectors` (working/episodic/semantic + pgvector), `agent_memory_config` tiers (Jimmy 3M · Leo 3M · Sherlock 1M · Industry 100K), `leo_recall()` RPC, `leo_memory_prune()` cap                                                                                                                                                                              |

Chalane ki tarteeb: file number ke hisaab se (17 → 18 → 19 → 20 → 21 → 22 → 23 → 24 → 25 → 26 → 27 → 28 → 30), phir `phase_wire_*` files.
| `phase31_ai_credits.sql` | 31 | AI Credit Engine: `ai_credit_wallets` (subscription/top-up/complimentary/reserved buckets), immutable `ai_credit_ledger` (update/delete blocked by trigger), locked `ai_credit_topup_products` (9 packs, £5,000 pack founder-only), `ai_credit_plans` (£135/400 · £300/1,200 · £1,000/5,000 · £2,000/10,000), `ai_actions` (pre-flight → reserve → settle, provider cost alag), `ai_credit_grants` (5+5 complimentary once per cycle), RPCs `ai_credits_reserve` / `ai_credits_settle` / `ai_credits_release` / `ai_credits_topup` / `ai_credits_complimentary` |
| `phase32_trial.sql` | 32 | Trial lifecycle: `trial_accounts` (48h timer, status trial|active|expired|frozen|released, plan, passkey/recovery flags, 30-day address reservation), immutable `trial_events` ledger with **idempotent** warn_24h/warn_2h/expired/frozen/released unique index, `reserved_handles` (awam ko admin/hello/billing/postmaster block), `trial_mail_holds` (frozen mailbox ki mail held/rejected — kabhi silently discard nahi), authority `account_state()` + `entitled_full()` + `ai_enabled()` (trial/expired/frozen = AI hard zero), RPCs `trial_start`/`trial_claim_address`/`trial_set_security`/`trial_subscribe`, hourly `trial_sweep()` + pg_cron job |
| `phase33_polar_checkout.sql` | 33 | Polar Checkout + Webhook: `polar_checkout_sessions` (created sessions per user, product key, status), `polar_webhook_events` (immutable verified event log), backend routes `/api/billing/checkout` + `/api/public/polar/webhook` |
| `phase34_billing_support.sql` | 34 | Polar billing truth + founder reply clock: subscription mein plan/customer/Polar IDs, immutable billing receipts, aur Basic 72h · Pro 48h · Business 24h `founder_reply_queue` |

| `phase35_payment_safety.sql` | 35 | Payment Safety Net (ek bhi payment zaya nahi): `polar_webhook_raw` (har hit ka raw payload, signature fail ho to bhi), `payment_alerts` (3 fail par founder alert), retry state on `polar_webhook_events` (state/attempts/next_retry_at, exponential backoff 1m→6h, 8 ke baad dead-letter), RPCs `webhook_capture_raw` / `webhook_mark_processed` / `webhook_mark_failed` / `webhook_claim_retries`, views `payment_reconciliation_gaps` (paid order jiska invoice/subscription missing) + `payment_health` |

## phase36_state_sync.sql — State Sync Engine (NO PAYMENT FAILURE)

Supabase #4 = source of truth, Polar sirf messenger.

- `billing_intents` — checkout se PEHLE banti hai, is liye koi payment orphan nahi
- `entitlement_state` — authoritative entitlement (sirf `billing_apply_entitlement` likhta hai)
- `billing_state_log` — har transition ka immutable log
- `billing_intent_confirm()` — idempotent, webhook ya pull dono se
- `billing_sync_claim/touch/fail/abandon_stale()` — backoff sweep; paid kabhi abandon nahi
- `billing_truth_gaps` + `billing_state_health` — founder ke liye gap radar

## phase37_movein_ops.sql — MOVE-IN OPERATIONS & REVENUE COCKPIT (money machine)

Poora £500–£3,000 Managed Move-In operation, sirf SQL ki authority pe (no hard-coded logic):

- `movein_deals` + `movein_transitions` — legal state machine (22 states), gates DB decide karti hai
- `movein_audit` — append-only (update/delete trigger se blocked)
- `movein_mailboxes` + `movein_mailbox_gaps` — per-mailbox handover evidence
- `movein_capacity` / `movein_waitlist` / `movein_book_slot()` — 2 per month, advisory lock se race-proof
- `movein_dns_checks` + `movein_dns_proof` + `movein_dns_green()` — MX/SPF/DKIM/DMARC pre+post proof
- `movein_runbook` + `movein_seed_runbook()` + `movein_cutover_ready()` + `movein_arm_cutover()`
- `movein_rollback_points` — rollback first-class, arm ke liye lazmi
- `movein_payments` + `movein_sync_payments()` + `movein_attach_intent()` — 50/50 cash clock, Phase 36 `billing_intents` truth se linked
- `movein_exceptions` — WARNING/BLOCKED/FAILED/CUSTOMER_ACTION_REQUIRED, cutover block
- `movein_health_calc()` (stable) + `movein_health()` (persist) — deterministic score, no AI
- `movein_open_deal()` / `movein_transition()` — band+price ladder (1-5 £500 · 6-15 £1,500 · 16-29 £2,000 · 30+ £3,000)
- `movein_evidence_bundle()` / `movein_customer_view()` / `movein_cockpit()` + `movein_cash_clock` / `movein_attention`

## phase38_movein_hardening.sql — Move-In Security & Integrity (Phase 38)

Phase 37 ke saath complement karta hai (rewrite nahi, surgical fixes). Phase 37 pehle, Phase 38 baad mein chalao.

P0

- Har `movein_*` SECURITY DEFINER function ka EXECUTE `public`/`anon`/`authenticated` se revoke; sirf `service_role` (+ 2 customer RPC) ko grant
- `movein_customer_view(deal)` ab `movein_is_deal_member()` se verify karta hai (`auth.uid()` = deal ka user/owner), warna `not_authorized_for_deal`
- `movein_evidence_bundle()` + `movein_cockpit()` = founder/service-role only
- Global views (`movein_cash_clock`, `movein_attention`, `movein_mailbox_gaps`, `movein_dns_proof`) authenticated se revoke; customer ke liye user-filtered `movein_my_mailbox_gaps` / `movein_my_dns_proof`
- `movein_attach_intent()` binding: intent ka `user_id` = deal ka user · `kind='movein'` · `currency='GBP'` · amount exact leg amount · ek intent do jagah attach nahi (unique index) · leg sirf deposit/final
- `movein_data_verified_ok()` gate: mailbox rows > 0 · rows = deal ka expected `mailbox_count` · sab VERIFIED · `messages_source > 0` · `messages_verified >= messages_source`. Zero-mailbox kabhi pass nahi

P1

- `movein_next_reference()` ab atomic `movein_reference_counter` (yearly) se — `count(*)+1` khatam, concurrent duplicate nahi
- Waitlist integrity: ek deal ki ek hi active position; month+position unique
- `movein_promote_waitlist(month)` — slot free hote hi pehla waitlisted deal promote (CANCELLED/CLOSED transition se auto-call)
- Rollback: `movein_rollback_create()` / `movein_rollback_validate()` / `movein_rollback_use()` (arm reset + ROLLBACK_REQUIRED exception + ON_HOLD)
- Mailbox counts constraint: `verified <= copied <= source`, sab non-negative

Small hardening

- `movein_dns_checks`: `phase in (PRE,POST)`, `record in (MX,SPF,DKIM,DMARC)`, `owner_id` column + auto-fill trigger + backfill
- `blocks_cutover` ab `movein_cutover_ready()` ka hissa; high severity par trigger se auto-true

## phase39_movein_fixes.sql — Move-In surgical fixes (Phase 39)

Phase 37 + 38 ka complement (kuch touch nahi hua). Tarteeb: 37 → 38 → 39.

- **Intent binding (P0)**: `billing_intents.movein_deal_id` + `movein_leg` columns, unique bind index, backfill. `movein_attach_intent()` ab reject karta hai: doosre deal/leg ka bound intent · pehle se paid/entitled unbound intent · deal se purana intent.
- **Rollback transitions (P0)**: `CUTOVER_EXECUTED` / `POST_CUTOVER_VERIFIED` / `FINAL_50_INVOICED` → `ON_HOLD` legal; recovery raaste `ON_HOLD` → DATA_COPY / DATA_VERIFIED / CUTOVER_READY (gates ke saath).
- **Reference counter (P1)**: `count(*)` khatam — asli `MOVE-IN-YYYY-NNN` ka highest NNN parse kar ke counter set.
- **Constraints (P2)**: mailbox counts clamp (verified ≤ copied ≤ source, no negatives) + DNS phase/record normalise, phir `VALIDATE CONSTRAINT`.

## phase40_evidence_truth.sql — EVIDENCE TRUTH (Phase 40)

Phase 39 ka FIX 4 replace karta hai. Historical evidence kabhi mutate nahi:

- `movein_mailboxes` counts aur `movein_dns_checks` phase/record par koi UPDATE nahi (no clamp, no PRE/MX default)
- Constraints NOT VALID rehti hain -> future writes enforce, purani rows waisi hi
- `movein_evidence_violations` view — har invalid row jaisi hai waisi (observed values ke saath)
- `movein_evidence_validate()` — VALIDATE CONSTRAINT sirf tab jab us table ka data genuinely clean ho
- File ke end par report: kitni invalid rows remaining hain (operator manually correct karta hai)

## phase43_annual_billing_lock.sql — Annual Billing Lock

- Exact monthly/yearly product selection ke liye `billing_cycle` intent par persist hota hai
- Client ka amount reject: expected amount server registry se aata hai
- Paid webhook/pull par product ID, GBP currency aur exact amount validate hota hai
- Mismatch par entitlement nahi milta; payment safety retry/alert path handle karta hai
- v3 purani `billing_sync_claim(integer)` ko transaction ke andar drop/recreate karta hai, is liye OUT return-type upgrade fail nahi hota
- Phase 44 ke tamam real Polar IDs isi file mein merged hain; ab **sirf Phase 43** Supabase #4 SQL Editor mein run hoti hai

## phase44_polar_ids_v2.sql — RETIRED compatibility guard

- Iska poora kaam Phase 43 v3 mein merge ho gaya hai
- Ghalti se run ho to fail nahi hoti; sirf notice deti hai

## phase45_founder_identity.sql — Founder identity lock (Phase 45)

Kahan chalti hai: **Supabase #4 -> SQL Editor** (Hetzner par nahi).

- Mojooda Auth user `naumansherwani.founder@anexomail.com` / `3e3a60ea-1580-4443-94f6-b758de732dce` ko founder map karti hai (naya user NAHI banati)
- `founder_accounts` = founder role ki authority (role kabhi profile/users par nahi)
- `trial_accounts` status `active` + 10 saal — founder trial/freeze mein kabhi nahi phansta
- `entitlement_state` = `business_pro`, support on, charge zero
- End par 4 VERIFY queries: auth uid ↔ founder role match, account state, entitlement, aur founder count = 1

## anexochat_phase01_foundation.sql — ANEXOChat Phase 1 slice (Phases 1-5)

Kahan chalti hai: **Supabase #4 -> SQL Editor**.

- Tables: `chat_workspaces` · `chat_members` · `chat_conversations` · `chat_participants` ·
  `chat_messages` (unique `client_msg_id` = idempotent send, per-conversation `seq` = ordering) ·
  `chat_message_receipts` (append-only delivered/read) · `chat_presence` · `chat_typing` ·
  `chat_files` + `chat_file_chunks` (sha256 + resume truth) · `chat_atmosphere_prefs`
- GRANTs + RLS: har object workspace membership ke peeche; `chat_access()` gate =
  founder_accounts YA entitlement `business | business_pro | ai_*`. Basic/Pro = zero access
- Functions: `chat_ensure_workspace` · `chat_direct_conversation` · `chat_send` (idempotent) ·
  `chat_mark` · `chat_conversation_list` (truthful health + reason) · `chat_messages_page` ·
  `chat_presence_ping` · `chat_typing_ping`
- ATMOSPHERE LOCK: Dawn/Day/Dusk/Night device clock se; Rain/Storm/Snow/Sunny sirf manual.
  Koi weather API, koi temperature — kahin store bhi nahi hota
- End par 2 VERIFY queries (chat tables + chat functions count)

## anexochat_phase03_message_engine.sql — ANEXOChat Phases 3-6

Kahan chalti hai: **Supabase #4 -> SQL Editor** (pehle `anexochat_phase01_foundation.sql`).

- **Phase 3 (message engine):** `chat_reactions` · `chat_message_edits` (append-only history,
  purana body kabhi gum nahi) · soft delete tombstone · `chat_work_items` (task/promise/decision)
  · `chat_conversation_state` (active/waiting/blocked/closed) · `chat_audit`
- **Phase 4 (SB4):** har naye object par `workspace_id` — workspace isolation mandatory
- **Phase 5 (RLS):** har table par RLS + participant/membership policy; security DB boundary par
- **Phase 6 (ANEXOMAIL integration):** `chat_unread_total(_user)` = sidebar badge ka asli sach
- Functions: `chat_log` · `chat_react` · `chat_edit_message` · `chat_delete_message` ·
  `chat_work_create` · `chat_work_list` · `chat_work_set_state` ·
  `chat_conversation_set_state` · `chat_unread_total`
- VERIFY: chat tables **16**, chat functions **19**

## ANEXOChat Phase 7–10 — Cinema + ANEXOVideoChat
- `sql/anexochat_phase07_cinema_video.sql` — reply_to + pinned_at on `chat_messages`,
  mute/archive on `chat_participants`, `chat_message_hidden` (delete for me),
  `chat_signals` (WebRTC signalling, 2-min TTL), `chat_video_allowed()`
  (founder + business_pro only), 5-minute edit window, 1-hour delete-for-everyone
  window, `chat_messages_page` with reactions + reply quote, `chat_search_messages`.
- Verify: `select count(*) from information_schema.tables where table_schema='public' and table_name like 'chat\_%';` → 18
- Verify: `select count(*) from information_schema.routines where routine_schema='public' and routine_name like 'chat\_%';` → 27
- `phase46_pricing_v5.sql` — PRICING v5: Basic £23/£253 · Pro £46/£506 · Business £97/£970 · Business Pro £2,850/£28,500 · Priority Support £790 · Move-In £568/£1,670/£2,210/£3,350
