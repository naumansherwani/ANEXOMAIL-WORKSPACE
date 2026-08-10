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

Chalane ki tarteeb: file number ke hisaab se (17 phir 18).