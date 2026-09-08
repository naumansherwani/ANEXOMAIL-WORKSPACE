# 23 — LAUNCH TODAY: proof order (status: READY)

Har dot ka apna sabooti command hai. Jo command green na ho, woh dot DONE nahi.

## 1. Mail andar aani chahiye (yahi asli rukawat thi)

```bash
cd /opt/anexomail-web && git pull
bash sql/run.sh sql/phase57_mail_schema_heal.sql
bash sql/run.sh sql/phase58_mail_contract_final.sql
bash sql/run.sh sql/phase56_mailbox_final.sql
bash server/mail/deploy-mail.sh
postqueue -f && sleep 20
bash sql/run.sh --query "select count(*) from public.mail_messages;"
postqueue -p
bash server/gates/mail-gate.sh
```

Sabooti: `mb.org_id`/`cc_addrs` error khatam + message count barha +
`Mail queue is empty` + gate PASS-only.

## 2. Website (awam ka har page)

```bash
bun install && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save
bash server/gates/web-gate.sh
```

## 3. Login + founder side

```bash
bash server/gates/rust-gate.sh        # /rpc/* engine
curl -s -o /dev/null -w '%{http_code}\n' https://anexomail.com/auth
for p in mail calendar chat crm people work storage analytics settings billing devices; do
  echo "$p $(curl -s -o /dev/null -w '%{http_code}' https://founderworkspace.anexomail.com/$p)"
done
```

## 4. ANEXOChat + call

```bash
bash server/gates/chat-gate.sh
bash server/gates/videocall-gate.sh
```

## 5. Paisa + storage + final

```bash
bash server/gates/payments-gate.sh
bash server/gates/storage-gate.sh
bash server/gates/all-gates.sh
```

## Yaad rahe

- `/app/*` ka har page **login ke peeche** hai. Bina session woh `/auth` par
  bhejta hai — yeh khali page nahi, yeh gate hai. Login ke baad andar asli
  panels hain jo asli API se data lete hain (koi dummy data nahi).
- Jo cheez server par sabit nahi hui, yahan READY likhi hai — DONE sirf green
  output ke baad.
