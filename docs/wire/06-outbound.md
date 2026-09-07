# Step 6 — Outbound: ANEXOMAIL → local Postfix → Internet

Chain (app mein koi SMTP username/password nahi):

```text
ANEXOMAIL app → 127.0.0.1:25 (local Postfix) → OpenDKIM sign → Internet
                                              → mail_outbox_log (proof)
```

Code repo mein hai: `server/mail/sendmail.ts` (`sendMail()`).

## 6A. Sender module server par le jao

Backend `/opt/anexomail` git repo **nahi** hai, is liye file copy karni hai:

```bash
cd /opt/anexomail-web && git pull
mkdir -p /opt/anexomail/src/mail
cp /opt/anexomail-web/server/mail/sendmail.ts /opt/anexomail/src/mail/sendmail.ts
ls -l /opt/anexomail/src/mail/
```

Backend `.env` mein (agar pehle se nahi):

```bash
grep -q SUPABASE_SERVICE_ROLE_KEY /opt/anexomail/.env && echo "already set" || nano /opt/anexomail/.env
```

`SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` hone chahiye (outbound proof ke liye).

## 6B. `/api/mail/send` ko asli sender par lagao

Yahan andaza nahi lagana. Pehle current file dikhao:

```bash
sed -n '1,80p' /opt/anexomail/src/routes/mail.ts
grep -n "send" /opt/anexomail/src/routes/mail.ts | head -20
```

Yeh output mujhe do — main us file ka **poora** naya content dunga (nano select-all → overwrite),
jisme `/api/mail/send`:

1. `sendMail()` se asli mail bhejta hai,
2. `mail_threads` / `mail_messages` mein `direction='out'` row likhta hai,
3. fail hone par honest 502 deta hai (kabhi fake success nahi).

## 6C. Direct test (route se pehle bhi chal sakta hai)

```bash
cd /opt/anexomail-web
bun -e '
import { sendMail } from "./server/mail/sendmail.ts";
const r = await sendMail({
  from: "hello@anexomail.com", fromName: "ANEXOMAIL",
  to: ["<TUMHARA_GMAIL>"],
  subject: "WIRE TEST 06 outbound",
  text: "ANEXOMAIL outbound wire test — local Postfix, no external SMTP."
});
console.log(r);
'
```

`{ ok: true, smtpResponse: "... 250 2.0.0 Ok: queued as ..." }` aana chahiye.

```bash
tail -n 20 /var/log/mail.log | grep -E 'status=(sent|bounced|deferred)'
```

`status=sent` chahiye. `deferred` + "connect to ... port 25" = Hetzner ka port 25 block
(step 0 dekho, unblock request).

## 6D. Verify (gate)

Gmail mein mail aaye aur **Show original** mein SPF/DKIM/DMARC teeno `PASS`.

Supabase:

```sql
select created_at, from_address, to_addresses, ok, smtp_response, error
  from public.mail_outbox_log order by created_at desc limit 5;
```

`ok = true` — tabhi green.

## 6E. Route ke baad ka test

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://anexomail.com/api/mail/send \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer <SESSION_TOKEN>" \
  -d '{"to":"<TUMHARA_GMAIL>","subject":"WIRE TEST 06 route","body":"via /api/mail/send"}'
```

`200` aur mail Gmail mein — dono chahiye. Sirf `200` kaafi nahi.
