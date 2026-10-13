# 22 — MAIL QUEUE FIX (spf_result) (status: READY)

## Asli wajah (server log se sabit, andaza nahi)

```text
anexomail-deliver: supabase 400 {"code":"42703",
 "message":"column \"spf_result\" of relation \"mail_messages\" does not exist"}
status=deferred
```

Server par PURANI `mail_messages` table pehle se mojood thi. Phase 52 mein
`create table if not exists` hai — is liye woh table waisi hi rahi aur naye
column (`spf_result`, `dkim_result` …) usmein kabhi nahi bane. Aap ki mail **gum
nahi hui**: Postfix ne har mail queue mein rok li (`status=deferred`), column
banne ke baad ek `postqueue -f` se sab andar chali jayegi.

## Fix (ek dafa, tarteeb se)

```bash
cd /opt/anexomail-web && git pull
bash sql/run.sh sql/phase57_mail_schema_heal.sql     # missing column add (koi delete nahi)
bash sql/run.sh sql/phase56_mailbox_final.sql        # final address list
bash server/mail/deploy-mail.sh                      # mailbox/alias/password refresh
postqueue -f                                          # ruki hui saari mail andar
sleep 20
bash server/gates/mail-gate.sh
```

## Verify (asli sabooti)

```bash
bash sql/run.sh --query "select count(*) from public.mail_messages;"   # 0 se barhna chahiye
bash sql/run.sh --query "select mailbox_address, subject, last_message_at from public.mail_threads order by last_message_at desc limit 5;"
postqueue -p                                                           # "Mail queue is empty"
curl -s -o /dev/null -w '%{http_code}\n' https://anexomail.com/app/mail
```

Gate mein ab yeh dots hain: `mailboxes = 12` · `postmaster/abuse/dmarc sirf
forward` · `nauman/support/trials delete ho chuka` ·
`mail_messages.spf_result column maujood` · asli round-trip.

Status **DONE** sirf tab jab gate ka output PASS-only ho.
