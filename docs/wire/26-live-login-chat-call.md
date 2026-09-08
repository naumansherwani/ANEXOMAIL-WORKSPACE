# 26 — Live login · ANEXOChat message · video call (proof book)

Status: TODO (kuch bhi DONE tab jab neeche ka verify command green ho)

## Step 0 — EK block: latest pull + poora deploy + real accounts/chat proof

```bash
cd /opt/anexomail-web && git pull && bun install \
 && bash server/deploy-all.sh \
 && bash server/accounts/create-accounts.sh
```

Phir SQL editor: `anexochat/sql/phase31c_file_download_manifest.sql` poora paste (Phase 31C download).

Teen passwords terminal par chhup kar type honge. Expected akhri line:
`ALL GREEN — website login + shared ANEXOChat ready`.
Yeh direct Auth ke saath website ke asli Brain login aur Rust chat bootstrap bhi test karta hai.

### Founder protocol (READY, live proof baqi)

Brain `/api/auth/session` + login result ab `is_founder` deta hai (authority `public.founder_accounts`).
Founder par `/claim` aur `/onboarding` ("Name your organisation") KABHI nahi — seedha `/app`.
Awam (anexomail.com / ai.anexomail.com signup) ka flow wahi: claim → onboarding → app.
Login response mein poora verified session aata hai; browser doosri session request ka wait nahi karta,
is liye auth → app jhatka/redirect race hata di gayi. Session apne mailbox ke operational
workspace ko `org_members` se ensure karta hai; naya awam onboarding `account_*` aur operational
workspace membership dono ek saath banata hai. Founder aur awam memberships merge nahi hotin.
Founder authority ka proof account script website ke login response par khud karta hai; `$FT` manually set karna zaroori nahi.

### Login + mail workspace regression (READY, live proof baqi)

Server terminal, deploy ke baad:

```bash
cd /opt/anexomail-web
bash server/deploy-brain.sh
bash server/mail/deploy-mail.sh
bash server/gates/ports-gate.sh
```

Expected: login ke baad `/app` ek hi transition mein khule; compose par `no_workspace` na aaye;
`Dovecot IMAP loopback 143` PASS ho. Purani DKIM key ka TXT dobara print nahi hoga.
DNS TXT dobara dekhna ho to sirf explicit command:

```bash
cd /opt/anexomail-web && SHOW_DKIM_TXT=1 bash server/mail/deploy-mail.sh
```

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

| Email                                  | Kaun                                                                                                |
| -------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `naumansherwani.founder@anexomail.com` | Founder (UID `3e3a60ea-1580-4443-94f6-b758de732dce` — agar row pehle se hai to sirf password reset) |
| `humzasherwani@anexomail.com`          | Family, aam user + AI Executive                                                                     |
| `raanasherwani@anexomail.com`          | Family, aam user + AI Executive                                                                     |

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

### Step B1 — automatic proof

`bash server/accounts/create-accounts.sh` teen website logins karta hai, shared family workspace
ensure karta hai, phir Rust par founder bootstrap mein 3 members aur 2 direct conversations verify karta hai.
Password/token kabhi print nahi hota. Is proof ke fail hone par `ALL GREEN` nahi aata.

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

| Dot                   | Status                                         |
| --------------------- | ---------------------------------------------- |
| A Login (3 accounts)  | TODO — account script ka website-login proof   |
| A5 Family entitlement | TODO — `family_grants_apply() = 2`             |
| B Shared chat         | TODO — 3 members + 2 direct chats + B3 message |
| C Video call 2-user   | TODO — gate GREEN + C2                         |

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
