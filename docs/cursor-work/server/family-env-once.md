# Family passwords — ek dafa /opt/anexomail/.env (no terminal ask)

**LOCK:** Founder password is script **kabhi nahi** touch karti. Lovable `read -s` ask **banned**.

## Nano (server pe ek dafa)

```bash
nano /opt/anexomail/.env
```

File ke **akhir** mein yeh teen lines (values aap ke — chat mein mat paste):

```
HUMZA_PASSWORD=
RAANA_PASSWORD=
MASOOD_PASSWORD=
```

Save: `Ctrl+O` Enter · `Ctrl+X`

Phir:

```bash
cd /opt/anexomail-web && git pull && bash server/deploy-brain.sh && bash server/accounts/create-accounts.sh
```

Expected pehli line: `GREEN create-accounts — no terminal password...`
Agar `Founder (...) password` poochhe → purani file; `git pull` incomplete.

SQL pehle: Supabase #4 → `docs/cursor-work/sql/phase63_f3a_passkey_family.sql`
