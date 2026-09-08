# 26 — Live login · ANEXOChat message · video call (proof book)

Status: TODO (kuch bhi DONE tab jab neeche ka verify command green ho)

## A. Login chain (asli, repo se)

- Browser `/auth` → `src/routes/auth.tsx:211` → `POST /api/auth/login` (Brain :3100)
- Brain `server/routes/auth.ts:112` → Supabase `signInWithPassword` → token wapas
- Matlab: account **Supabase Auth (auth.users)** mein hona lazmi, password bhi wahi.

### Step A1 — accounts Supabase Auth mein (dashboard, manual)

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

## B. Do-user ANEXOChat message — TODO (Section fill hoga jab Rust rpc list verify ho)

## C. Video call — TODO

```bash
bash server/gates/videocall-gate.sh
```
