# 01 — SAARI SQL EK COMMAND SE (copy-paste)

## Apply — sirf yeh ek line copy-paste karo

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
