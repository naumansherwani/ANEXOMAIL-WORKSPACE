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
| `phase_wire_founder.sql` | wiring · page 1 | Founder Command Deck + AI Email Center: mailboxes registry (17 real addresses), mail_domains, ai_agents roster, leo_email_drafts, mail_outbox, founder_accounts |
| `phase_leo_memory.sql` | leo brain | LEO 3M-message memory: `leo_memory_vectors` (working/episodic/semantic + pgvector), `agent_memory_config` tiers (Jimmy 3M · Leo 3M · Sherlock 1M · Industry 100K), `leo_recall()` RPC, `leo_memory_prune()` cap |

Chalane ki tarteeb: file number ke hisaab se (17 phir 18), phir `phase_wire_*` files.