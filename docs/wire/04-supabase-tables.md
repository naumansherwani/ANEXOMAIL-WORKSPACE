# Step 4 — Supabase mail tables (truth)

Yeh step Supabase #4 mein mail ka source of truth banata hai. Koi dummy row nahi —
sirf 13 asli `anexomail.com` addresses seed hote hain.

## 4A. SQL chalao

1. Repo se file kholo: `sql/phase52_mail_launch.sql`
2. Poori file copy karo → Supabase #4 → **SQL Editor** → paste → **Run**

Kya banta hai:

- `mail_domains` · `mailboxes` (13 rows)
- `mail_threads` · `mail_messages` · `mail_attachments` (inbox truth)
- `mail_inbound_raw` — har aane wali mail ka raw proof (append-only, edit/delete trigger se band)
- `mail_outbox_log` — har outbound send ka proof (append-only)
- `mail_ingest(jsonb)` RPC — Postfix pipe isay call karta hai (sirf `service_role`)
- `mail_outbox_record(jsonb)` RPC — outbound proof (sirf `service_role`)

Threading, dedupe aur reply-chain ka faisla **Postgres** karta hai — browser ya script mein nahi
(NO DUPLICATE rule).

## 4B. Verify (gate)

SQL Editor mein:

```sql
select count(*) as mailboxes from public.mailboxes;                  -- 13
select address, box_type, is_public from public.mailboxes order by address;
select routine_name from information_schema.routines
 where routine_schema='public' and routine_name in ('mail_ingest','mail_outbox_record');  -- 2 rows
select relname, relrowsecurity from pg_class
 where relname in ('mail_threads','mail_messages','mail_inbound_raw','mail_outbox_log'); -- sab true
```

`13` · dono RPC · RLS `true` — tabhi step 5.

## 4C. Server par service key rakho

Pipe ko service_role key chahiye. Yeh file **sirf server par**, repo mein kabhi nahi:

```bash
nano /etc/anexomail/mail.env
```

Isme yeh do lines add karo (baqi mailbox passwords pehle se isi file mein hain):

```env
SUPABASE_URL='https://<PROJECT_REF>.supabase.co'
SUPABASE_SERVICE_ROLE_KEY='<SERVICE_ROLE_KEY>'
```

```bash
chmod 600 /etc/anexomail/mail.env
grep -c SUPABASE /etc/anexomail/mail.env   # 2
```
