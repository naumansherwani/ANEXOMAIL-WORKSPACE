# 01 — SAARI SQL EK COMMAND SE (copy-paste)

## Step A — sirf ek dafa: DB connection (agar server par pehle se nahi hai)

Yeh line paste karo, `PASSWORD` aur `HOST` ki jagah apna Supabase connection string
poora paste karo (Supabase → Project Settings → Database → Connection string → URI):

```bash
echo 'DATABASE_URL=postgresql://postgres:PASSWORD@HOST:5432/postgres' > /root/.anexomail.env && chmod 600 /root/.anexomail.env && echo SAVED
```

Agar server par pehle se `DATABASE_URL` / `PGHOST` set hai to yeh step chhor do.

## Step B — apply (yeh poora block copy-paste karo)

```bash
cd /opt/anexomail-web && git pull && bash sql/apply-all.sh
```

Output aisa aata hai:

```
GREEN  sql/phase12a_mail_prediction.sql
GREEN  anexochat/sql/phase13_15_file_engine.sql
...
GREEN=59  RED=0
ALL SQL GREEN
```

## Step C — RED aaye to (yeh command ka output mujhe do)

```bash
cat /root/anexomail-sql-apply.log | tail -n 80
```

Main usi waqt us file ko theek karunga; aap ko sirf Step B dobara chalana hoga.
