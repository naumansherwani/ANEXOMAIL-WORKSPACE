# 01 — SAARI SQL EK COMMAND SE (copy-paste)

## Pehli dafa connection — sirf yeh ek line copy-paste karo

```bash
cd /opt/anexomail-web && git pull && bash sql/connect.sh
```

Terminal aap se database ka **connection URI** maangega. Database dashboard ke
**Connect → URI / Transaction pooler** se poori URI copy karke paste karein aur Enter
karein. Paste screen par nazar nahi aayega, shell history mein nahi jayega, repo mein
nahi jayega. Script pehle login test karegi; sirf GREEN par protected file mein save hoga.

## Apply — connection GREEN ke baad sirf yeh ek line copy-paste karo

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

Runner pehle database connection check karta hai. Connection fail ho to 59 jhoote RED
nahi deta; foran ruk kar asli error screen par dikhata hai. SQL error ho to pehli failing
phase aur us ka exact error screen par dikhata hai; baqi dependent phases run nahi hotin.
`connect.sh` ka login-verified URI hamesha purani app/mail environment files se pehle use hota hai.
