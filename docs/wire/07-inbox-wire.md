# Step 7 — Inbox UI asli rows par

Frontend `src/lib/mail.ts` pehle se sirf HTTP bolta hai (`/api/mail/threads`,
`/api/mail/thread/:id`, `/api/mail/send`) — browser mein koi threading/mock nahi.
Is step mein sirf yeh sabit karna hai ke woh endpoints **asli** Supabase rows deti hain.

## 7A. Endpoint truth check

```bash
# threads list
curl -s https://anexomail.com/api/mail/threads?folder=inbox \
  -H "Authorization: Bearer <SESSION_TOKEN>" | head -c 600; echo

# ek thread
curl -s https://anexomail.com/api/mail/thread/<THREAD_ID> \
  -H "Authorization: Bearer <SESSION_TOKEN>" | head -c 600; echo
```

`<THREAD_ID>` step 5 ke SQL se lo.

Agar response `404` ya khali `{"threads":[]}` hai lekin Supabase mein rows maujood hain, to
backend router purani table/shape par hai. Us soorat mein yeh do:

```bash
sed -n '1,120p' /opt/anexomail/src/routes/mail.ts
```

output mujhe do — main us file ka poora naya content dunga jo Phase 52 tables
(`mail_threads` · `mail_messages` · `mailboxes`) par seedha baitha ho.

## 7B. Browser check (asli gate)

1. `https://anexomail.com/app/mail` kholo (sign in ke baad).
2. Step 5 ka test mail (subject `WIRE TEST 05`) list mein dikhe.
3. Thread kholo — asli body dikhe.
4. Inline reply bhejo — Gmail mein pohnche, aur usi thread mein `direction='out'` row bane:

```sql
select direction, from_address, subject, sent_at
  from public.mail_messages where thread_id = '<THREAD_ID>' order by sent_at;
```

## 7C. Public pages ke addresses check

Har jagah wahi address ho jo mailbox list mein hai:

```bash
cd /opt/anexomail-web
rg -n "@anexomail\.com" src --no-heading | sed 's/:.*\(\S*@anexomail\.com\).*/ -> \1/' | sort -u | head -40
```

Expected mapping (`docs/wire/README.md` ki table):

- `hello@` — footer, get-started, AI page, checkout-done, trial-ended, AI top-up
- `moveyourbusiness@` — landing hero CTA, migration, enterprise, plans, LeadForm
- `support@` — `/status`, `/docs`
- `billing@` — `/docs`
- `noreply@` — sirf outbound (glitch alerts)
- `leo@` + founder addresses — `/app/founder`

Koi address list se bahar mila = wire loophole; usay theek karo ya list mein add karo.

## 7D. Har mailbox ka round-trip (13 dots)

Yeh loop chala kar khud ko mail bhejo, phir Supabase mein ginti karo:

```bash
cd /opt/anexomail-web
for A in hello moveyourbusiness support billing resolved trials abuse dmarc leo naumansherwani.founder nauman postmaster; do
  bun -e '
  import { sendMail } from "./server/mail/sendmail.ts";
  const to = process.argv[2];
  console.log(to, await sendMail({ from:"noreply@anexomail.com", to:[to],
    subject:"WIRE TEST 07 "+to, text:"round-trip check" }));
  ' "$A@anexomail.com"
done
```

```sql
select envelope_to, count(*) from public.mail_inbound_raw
 where created_at > now() - interval '15 min' group by 1 order by 1;
```

12 addresses aayein (aliases apne target par gine jayenge: `postmaster@`→`abuse@`,
`nauman@`→founder). `noreply@` par bhejo to woh **na** aaye — wahi sahi hai.
