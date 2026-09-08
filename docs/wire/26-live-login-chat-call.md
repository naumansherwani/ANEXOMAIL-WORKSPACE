# 26 — Live login · ANEXOChat message · video call (proof book)

Status: TODO (kuch bhi DONE tab jab neeche ka verify command green ho)

## Step 0 — EK block: deploy + accounts (server terminal, copy-paste)

```bash
cd /opt/anexomail-web && git pull && bun install \
 && bash server/deploy-brain.sh \
 && bash server/rust/deploy.sh \
 && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save \
 && bash server/accounts/create-accounts.sh
```

Phir SQL editor: `anexochat/sql/phase31c_file_download_manifest.sql` poora paste (Phase 31C download).

Expected akhri line accounts script ki: `ALL GREEN`. Iske baad A3 → B1 → C1 neeche.

### Founder protocol (READY, live proof baqi)
Brain `/api/auth/session` + login result ab `is_founder` deta hai (authority `public.founder_accounts`).
Founder par `/claim` aur `/onboarding` ("Name your organisation") KABHI nahi — seedha `/app`.
Awam (anexomail.com / ai.anexomail.com signup) ka flow wahi: claim → onboarding → app.
Verify (A3 ke token se): `curl -sS http://127.0.0.1:3100/api/auth/session -H "authorization: Bearer $FT" | grep -o '"is_founder":true'` → print ho = PASS.


## A. Login chain (asli, repo se)

- Browser `/auth` → `src/routes/auth.tsx:211` → `POST /api/auth/login` (Brain :3100)
- Brain `server/routes/auth.ts:112` → Supabase `signInWithPassword` → token wapas
- Matlab: account **Supabase Auth (auth.users)** mein hona lazmi, password bhi wahi.

### Step A1 — accounts Supabase Auth mein (EK command — READY, live proof baqi)

Server terminal:

```bash
cd /opt/anexomail-web && git pull && bun install && bash server/accounts/create-accounts.sh
```

Teen password chhup ke type karo (founder ka `FOUNDER_MAIL_PASSWORD` `/opt/anexomail/.env` mein ho to woh khud le lega).
Script: user create/update + Auto Confirm · `founder_accounts` row · `family_grants_apply()` (expected 2) · teen asli login test.
Expected akhri line: `ALL GREEN`. Koi RED aaye to woh line chat mein paste karo (password kabhi nahi).

Manual raasta (agar script na chale):

Supabase → Authentication → Users → "Add user" → **Auto Confirm User = ON**:

| Email | Kaun |
|---|---|
| `naumansherwani.founder@anexomail.com` | Founder (UID `3e3a60ea-1580-4443-94f6-b758de732dce` — agar row pehle se hai to sirf password reset) |
| `humzasherwani@anexomail.com` | Family, aam user + AI Executive |
| `raanasherwani@anexomail.com` | Family, aam user + AI Executive |

Password founder khud set karta hai (chat mein kabhi nahi).

### Step A2 — SQL editor: founder authority + family entitlement check

```sql
select u.id, u.email, u.email_confirmed_at is not null as confirmed,
       exists(select 1 from public.founder_accounts f where f.user_id = u.id) as is_founder,
       public.chat_access(u.id) as chat_access
from auth.users u
where u.email in ('naumansherwani.founder@anexomail.com',
                  'humzasherwani@anexomail.com',
                  'raanasherwani@anexomail.com')
order by u.email;
```

Expected: 3 rows · `confirmed = true` · founder row `is_founder = true` · teeno `chat_access` allow.
Agar family `chat_access` deny → `sql/phase56_*` (family accounts) dobara run.

### Step A3 — server terminal: login proof

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3100/api/auth/session   # expected 401
curl -sS -X POST http://127.0.0.1:3100/api/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"naumansherwani.founder@anexomail.com","password":"<founder types here>"}' \
  | head -c 300; echo
```

Expected: JSON mein `"token":"..."` (ya `mfa_required`). `invalid_credentials` = password Supabase mein set nahi.

### Step A4 — browser

`https://founderworkspace.anexomail.com/auth` → email+password → `/app` khule, FOUNDER PREVIEW pill dikhe.
Family: `https://anexochat.anexomail.com/auth` (public host).

### Step A5 — SQL editor: family entitlement (Auth users banne ke BAAD, warna 0 return)

```sql
select public.family_grants_apply() as family_rows;   -- expected 2
select u.email, public.chat_access(u.id) as chat, public.chat_video_allowed(u.id) as video
from auth.users u where u.email like '%sherwani%@anexomail.com' order by 1;
```

Expected: `family_rows = 2`; teeno par chat + video allow. Founder par `chat_access` founder bypass se allow.

## B. Do-user ANEXOChat message (Rust :3200 PRIMARY)

Chain (repo): page `src/routes/anexochat.tsx` / `app.chat.tsx` → `src/lib/chat-transport.ts` → `POST /rpc/chat.*` (:3200)
→ Rust `main.rs:306 chat.bootstrap` · `:330 chat.conversations.direct` · `:363 chat.send` → SQL `public.chat_send()` → `chat_messages`.

### Step B1 — server terminal (do token, A3 se: founder + humza)

```bash
FT='<founder token>'; HT='<humza token>'
R=http://127.0.0.1:3200
curl -sS -X POST $R/rpc/chat.bootstrap -H "authorization: Bearer $FT" -H 'content-type: application/json' -d '{}' | head -c 300; echo
# direct conversation founder → humza (humza ka uid Step A2 se)
CONV=$(curl -sS -X POST $R/rpc/chat.conversations.direct -H "authorization: Bearer $FT" -H 'content-type: application/json' \
  -d '{"peer_id":"<humza uid>"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["conversation_id"])'); echo "CONV=$CONV"
curl -sS -X POST $R/rpc/chat.send -H "authorization: Bearer $FT" -H 'content-type: application/json' \
  -d "{\"conversation_id\":\"$CONV\",\"client_msg_id\":\"proof-$(date +%s)\",\"body\":\"live proof from founder\"}" | head -c 300; echo
# humza ki taraf se padho
curl -sS -X POST $R/rpc/chat.messages -H "authorization: Bearer $HT" -H 'content-type: application/json' \
  -d "{\"conversation_id\":\"$CONV\"}" | head -c 400; echo
```

Expected: bootstrap 200 JSON · `CONV=<uuid>` · send 200 with message id · humza ke `chat.messages` mein "live proof from founder" dikhe.
(Field names 400 dein to Rust `main.rs:330-395` ke exact keys paste karo — guess nahi.)

### Step B2 — SQL truth

```sql
select conversation_id, sender_id, left(body,40) body, created_at
from public.chat_messages order by created_at desc limit 5;
```

### Step B3 — browser (do alag browsers)

- Founder: `https://founderworkspace.anexomail.com/anexochat` (→ `/app/chat`)
- Humza: `https://anexochat.anexomail.com` login → same conversation → message dono taraf bina reload dikhe.
- Screenshot dono = DONE.

## C. Video call

Chain: `chat.turn.health` (public, `credential_ready` only) · `chat.turn.credentials` (auth, `chat_video_allowed`) · `call.start/join/signal/ice/leave` · coturn `anexovideocall.anexomail.com` · SFU :3500/:3501.

### Step C1 — server terminal

```bash
bash server/gates/videocall-gate.sh
curl -sS -X POST http://127.0.0.1:3200/rpc/chat.turn.credentials -H "authorization: Bearer $FT" \
  -H 'content-type: application/json' -d '{}' | python3 -c 'import sys,json;d=json.load(sys.stdin);print({k:(v if k not in ("password","credential") else "***") for k,v in d.items()})'
```

Expected: gate GREEN; credentials JSON mein `urls` + `username` + ttl (secret print nahi).

### Step C2 — browser

Founder `/anexovideocall` → humza ko call → humza browser par ringtone + accept → dono video tiles live 60s.
Founder view `/app/founder/calls` mein session row dikhe. SQL:

```sql
select id, started_at, ended_at, participants from public.chat_call_sessions order by started_at desc limit 3;
```

## Status board

| Dot | Status |
|---|---|
| A Login (founder) | TODO — Supabase Auth password set + A3 200 |
| A5 Family entitlement | TODO — `family_grants_apply() = 2` |
| B Chat message 2-user | TODO — B1 + B3 screenshot |
| C Video call 2-user | TODO — gate GREEN + C2 |

## Phase 31C — file download proof (TODO)

Server par (SQL editor):
```sql
-- anexochat/sql/phase31c_file_download_manifest.sql poora paste karo, phir:
select public.file_download_manifest('00000000-0000-0000-0000-000000000000'::uuid, gen_random_uuid());
-- expected: {"found":false,"ok":false,"reason":"not_found"}
```
Server terminal:
```bash
cd /opt/anexomail-web && git pull && bash server/rust/deploy.sh && bash server/deploy-brain.sh
curl -s -o /dev/null -w '%{http_code}\n' "https://anexochat.anexomail.com/file/download?version=$(uuidgen)"   # 401 bina token = PASS
```
Browser: `/app/chat` → Workspace file engine → ek file upload → version `ready` → **Download** → status "Downloaded · recorded".
SQL saboot: `select * from public.file_evidence where state='downloaded' order by created_at desc limit 1;`
