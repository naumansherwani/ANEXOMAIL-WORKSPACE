# E22 — package badalna: naye plan ka poora price, purana plan band (14 Oct 2026)

**Founder rule:** jis package ke paise user ne diye hain, agar woh naye package
pe jana chahe to naye package ke paise **shuru se** dega. Purane ka credit /
prorate nahi. Purani subscription band.

## Kya banaya (sab additive — webhook / worker / reconcile / checkout path nahi chhua)

| Hissa | File | Kya |
|---|---|---|
| SQL | `docs/cursor-work/sql/E22_plan_replacement.sql` | Naya table `polar_plan_replacements` (pending/done/abandoned/failed) + `polar_billing_state()` ka sirf `order by` (active rows pehle) |
| Rust payment engine | `server/rust/polar-payment/main.rs` | Naya alag task `replace_loop` (har 30s): jab user ke NAYE product ki subscription `polar_subscriptions` mein `active` ho jaye, tab SIRF wahi ek purani subscription Polar se revoke (`DELETE /v1/subscriptions/{id}`). 48h tak naya active na aaye = `abandoned` |
| Bun (fallback checkout path) | `server/routes/billing-sync.ts` | `/change-plan` ab PATCH/prorate nahi karta: normal full-price checkout kholta hai aur URL dene se PEHLE replacement row likhta hai (na likh sake to URL nahi dete — warna double billing) |
| Frontend | `PlanCheckoutButton.tsx` | sirf comment/error text; behaviour same |

## Kyun `polar_billing_state()` badla gaya
Phase 50 ka function user ki sab se naye `updated_at` wali row dikhata tha.
Purani subscription revoke hone par uski row `revoked` ban kar sab se naye
`updated_at` par aa jati — billing page "purana plan, revoked" dikhata. Ab
`order by (status in ('active','past_due','grace')) desc, updated_at desc`.
Baqi function (signature, security definer, return shape, grants) akshar ba
akshar Phase 50 wala.

## Safety
- `replace_loop` payment path se alag tokio task hai; error = sirf log + attempts++;
  20 attempts ke baad `failed` (row mein `last_error`).
- Table na ho (SQL abhi run nahi hua) to engine sirf `warn` likhta hai.
- Sirf wahi subscription revoke hoti hai jo us user ki apni ho (`user_id` match) aur
  jis ke liye replacement row bani ho. Naya active na ho to kuch nahi chhua.
- `deploy.sh` `cargo build` fail ho to `pm2 restart` tak pohanchti hi nahi (`set -e`),
  yani purana chalta hua engine salamat. File badalne se pehle purani `.bak.<stamp>` banti hai.

## Zaroori: deploy se PEHLE (Rust code yahan compile NAHI hua)
Is session ki sandbox se crates.io blocked hai (403), isliye `cargo check` yahan
nahi chala. Code ko dhyan se parha, lekin compile ka asli test server pe `cargo build` hai.

1. Live engine aur repo ka farq:
```bash
diff /opt/polar-rust-payment/src/main.rs /opt/anexomail-web/server/rust/polar-payment/main.rs | head -80
```
   Farq sirf E22 ka naya code hona chahiye (`replace_loop` wagera). Agar live file mein
   KUCH AUR bhi ho jo repo mein nahi, deploy mat karo — pehle usay repo mein laao.
2. Live SQL function:
```sql
select pg_get_functiondef('public.polar_billing_state(uuid)'::regprocedure);
```
   Phase 50 jaisa hona chahiye (`order by s.updated_at desc limit 1`). Alag ho to E22 ke
   PART 2 ko paste karne se pehle mujhe dikhao.

## Deploy order
1. Supabase #4: E22 SQL paste -> Run (verify lines file ke aakhir mein).
2. Web pull (Rule 1 command).
3. Engine: `cd /opt/anexomail-web && git pull --rebase origin main && bash server/rust/polar-payment/deploy.sh`
   (`/health`, `/ready` green aane chahiye; log mein `replace:` warn nahi aani chahiye).

## Live verify (test account, active subscription)
1. Personal Pro pe active account -> `/app/billing` -> Personal Premium "Upgrade": Polar checkout
   **poore price** ka khule (credit / proration line nahi).
2. Pay karo -> ~30-60s mein purani subscription Polar dashboard mein `revoked`, naya `active`;
   `select * from polar_plan_replacements order by created_at desc limit 3;` -> `state = done`.
3. `/app/billing` naya plan dikhaye (purana "revoked" nahi).
4. Checkout beech mein chhodo -> purana plan `active` hi rahe, row `pending` (48h baad `abandoned`).
5. Business Pro: same flow, ab seat-based/flat ka masla nahi.

**Status:** READY — repo mein, SQL + Rust deploy + live verify baqi (Rule 5).
Rust compile server pe pehli baar hoga.
