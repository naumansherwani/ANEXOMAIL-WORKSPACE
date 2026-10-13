# E24 — Account delete system (14 Oct 2026, founder request)

**Status: READY** (repo mein; Supabase SQL run + deploy + live dry-run baqi — Rule 5).
Founder ne kaha: test accounts/orgs (axonetis samet) saaf karne ka system chahiye; **Ali ka account abhi delete nahi hoga** — baad mein founder kahega.

## Kya bana

| File | Kaam |
|---|---|
| `docs/cursor-work/sql/E24_account_deletion.sql` | `account_deletions` table + `account_deletion_blockers/state/request/cancel` + `account_purge` |
| `server/rust/main.rs` (`dispatch_account`) | **PRIMARY:** Rust :3200 tRPC `/rpc/account.delete.state` · `.request` · `.cancel` (+ E23 `account.signup.activate`, `billing.settle`) |
| `server/routes/account-deletion.ts` + `server/index.ts` (1 mount) | **Bun FALLBACK** (Rust 404/501/502/503 pe): `/api/account-deletion/{state,request,cancel}` |
| `src/routes/app.account.tsx` | "Delete account" section: typed-email confirm, blockers, cancel — `rpcOrRest` (Rust pehle, Bun fallback) |
| `server/mail/remove-address.sh` | purge ke baad Postfix se address hatata hai (cron sirf ADD karta hai) |

## Technology map (rules: AGENTS.md · MASTER-BUILD-PLAN "Async Tokio kahan aayega" · ANEXOMAIL-EXECUTE "pehle Rust, phir Bun fallback")

| Piece | Technology | Kyun |
|---|---|---|
| request / cancel / state | Rust :3200 tRPC `/rpc/*` (Axum+Tokio) -> Supabase RPC | command/query = tRPC PRIMARY; Bun sirf fallback |
| Truth + rules (blockers, grace, purge) | PostgreSQL (SQL functions) | data truth Supabase mein |
| Purge | SQL Editor only, **jaan-boojh ke Tokio loop/WT nahi** | destructive; founder-gated |
| WebTransport/QUIC push | **lagaya nahi** | push realtime ke liye hai (mail/chat/reminder/metrics); delete mein koi live stream nahi |
| Tokio background loop | **lagaya nahi** | auto-purge cron baad ka item, founder ke bharose ke baad |
| Postfix cleanup | bash script (Postfix/Dovecot pehle se installed) | mail server ka kaam |

## Kaise kaam karta hai

**User side (self-service):** Account page -> "Delete account" -> apna email type kare -> `scheduled_for = abhi + 7 din`. Beech mein "Cancel deletion". Kuch delete nahi hota, grace ke baad bhi nahi — purge sirf founder chalata hai.

**Founder side (purge):** `account_purge()` par **kisi role ka execute nahi** (service_role ka bhi nahi). Sirf SQL Editor. Default **dry-run**: asli deletes chalata hai, phir rollback — to har FK/trigger ki rukawat dry-run mein hi dikh jati hai. Asli run ya poora hota hai ya kuch bhi nahi (ek transaction).

**Blockers** (request bhi rokte hain, purge bhi): founder account · aise org ka owner jis mein dusre members hon · active/past_due/grace Polar subscription · Supabase Storage mein files (purge mein).

**Kya delete hota hai:** `auth.users` + uski cascade rows · `user_id/owner_id/owner_user_id` wali rows (FK ho ya na ho) · woh orgs jin mein user **akela** member hai, unki `org_id` rows (mail threads/messages, mail_accounts, domains...) samet · 7 immutable ledgers (trial_events, billing_event_receipts, ai_credit_ledger, movein_audit, mail_inbound_raw, mail_outbox_log, crm_evidence) sirf isi transaction ke liye unlock hote hain, sirf un tables par jin mein is user ki rows hon, aur auth user delete hote hi wapas lock.
**Kya delete nahi hota:** `ON DELETE SET NULL` tables (ai_credit_ledger, billing receipts, tickets...) — sirf `user_id` null (report mein `anonymised_rows`). Dusre ke org, dusre users.
**Handle:** `ali@anexomail.com` ka `ali` `reserved_handles` mein (reason `deleted`) — kisi aur ko nahi milta. Test accounts ke liye wapas kholna ho: purge mein `_release_handle => true`.
**Audit:** `account_deletions` mein row rehti hai (email scrub, sirf sha256 hash, report mein address nahi).

## Ali (ya koi bhi test account) baad mein kaise delete karna hai

Supabase #4 SQL Editor:

```sql
-- 0) kaun kaun hai
select u.id, u.email, u.created_at, t.status, t.plan
from auth.users u left join public.trial_accounts t on t.user_id = u.id
order by u.created_at desc;

-- 1) DRY-RUN (kuch delete nahi hota) — pehle yeh, result dekho
select jsonb_pretty(public.account_purge('<USER_UUID>'));

-- 2) asli (test account: grace chhod kar)
select jsonb_pretty(public.account_purge('<USER_UUID>', false, true));
```

Phir Hetzner par (report ke `mail_addresses` ke saath; pehle bina `--apply` ke dekho):

```bash
cd /opt/anexomail-web && bash server/mail/remove-address.sh ali@anexomail.com
bash server/mail/remove-address.sh --apply ali@anexomail.com
```

Report ke `ok:false` aaye to `error`/`detail` mujhe bhejo — user ko haath nahi lagta (rollback).

## Deploy order

1. Supabase #4: `E24_account_deletion.sql` poori paste -> Run.
2. **Rust engine (PRIMARY)** — pehle yeh check (live Rust file repo ke pichle version jaisi hai?):
   ```bash
   cd /opt/anexomail-web && git pull --rebase origin main && git show 14f051e:server/rust/main.rs | diff -q - /opt/anexomail-rust/src/main.rs && echo LIVE_MATCHES_REPO
   ```
   `LIVE_MATCHES_REPO` aaye to hi: `bash server/rust/deploy.sh` (backup `.bak.<stamp>` + `cargo build --release`; build fail ho to purani binary chalti rehti hai), phir `bash server/gates/rust-gate.sh`. Diff aaye to ruko — live-only code hai, pehle repo mein aana chahiye (Rule 14).
3. Web: Rule-1 command (frontend section).
4. Brain (Bun FALLBACK): `bash server/deploy-brain.sh` (naya route file + `index.ts` mount; `GREEN anexomail-leo :3100`).
5. `server/mail/remove-address.sh` repo se pull ke saath aa jata hai (kuch chalta nahi jab tak aap na chalao).
6. Live check: Account page -> "Delete account" status load ho; browser Network mein `/rpc/account.delete.state` 200 aaye (Rust se), `/api/account-deletion/*` nahi.

## Test evidence (agent ne kya check kiya — LIVE nahi)

Local Postgres 16 par repo ki asli SQL files (phase 31/32/37/50/52/54/59/60, E15, phase64 ledgers) load karke, fixtures ke saath:
- blockers: founder / owner-with-members / active subscription pakde gaye; normal user khali.
- request: ghalat email -> `email_mismatch`; case/space-insensitive match; dobara request `already_scheduled`; cancel; blocked users ko schedule nahi.
- purge: bina schedule -> `not_scheduled`; grace ke andar -> `grace_not_over`; Storage file -> `storage_objects_exist`; dry-run ke baad user/rows/triggers jaise the; asli purge: user + sole org + uski mail/domain/ledger rows gaye, dusre org/user salamat, set-null ledgers anonymised, handle reserved, audit row scrubbed.
- Testing mein ek bug pakda aur fix kiya: ledger triggers purge ke baad unlocked reh jate the -> ab usi transaction mein re-lock (test: `delete from trial_events` dobara fail).
- FK-order retry (parent/child bina cascade) theek; unknown blocking trigger -> `purge_failed`, kuch nahi badla.
- `remove-address.sh`: dry-run, DB-mein-maujood skip, apply (backup + line hata + Maildir move), WORKING_URL ke baghair refuse — stub postmap/postfix ke saath.
- Rust arms (`account.delete.*`, `account.signup.activate`, `billing.settle`): sirf `rustfmt` parse-check clean. **cargo build sandbox mein nahi chala** (crates.io blocked) — pehla compile server par `deploy.sh` mein hoga; fail hua to purani binary chalti rehti hai.
- Syntax: `tsc --noEmit --noResolve` mein koi syntax error nahi (poora typecheck sandbox mein nahi chalta — node_modules nahi).

## Jo verify NAHI hua / limits (sach)

- **Live schema:** live DB mein repo mein na likhi hui tables/triggers ho sakti hain. Isi liye pehla kaam Ali par **dry-run** hai — koi aur rukawat hui to `purge_failed` + `detail` aayega, kuch delete nahi hoga.
- **Server-side files:** Maildir (Hetzner) DB purge se nahi hatti — `remove-address.sh` MOVE karta hai (`_deleted/`), delete nahi. Dovecot ka alag userdb/passdb ho to woh alag. `valias` mein jo alias is address ki taraf point karte hain woh nahi hatte. Company-domain ke Postfix virtual-domain entries ko yeh nahi chhoota (report ke `domains` mein naam aate hain).
- **Supabase Storage:** SQL se files nahi hatti — blocker hai (pehle Dashboard se hatao).
- **Polar:** customer record Polar ke paas rehta hai; active subscription blocker hai (cancel + end hone ke baad hi). App mein user ke liye cancel button abhi nahi hai — paying user ko support chahiye.
- **ANEXOChat DB** agar alag Supabase hai to yeh usay nahi chhoota.
- Typed email "are you sure" hai, re-authentication nahi.
- `pending_plan` user (jaise Ali) `/app/account` tak pohanch hi nahi sakta (`/plans` par bounce) — unka delete founder purge se hoga.
- Auto-purge (cron) nahi banaya — founder-gated pehle; jab bharosa ho to alag item.
