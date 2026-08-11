# ANEXOMAIL — Server 2 (Brain, port 3100) route files

Rule (locked, SQL folder ki tarah): backend ki har file isi repo folder mein rehti hai.
Backend `/opt/anexomail` git repo nahi hai, is liye founder yahan se **poori file copy**
karta hai aur server par `nano` mein overwrite karta hai (select all -> paste).
Kabhi line-patch, sed ya python patch nahi.

| Repo file | Server path | Phase |
| --- | --- | --- |
| `index.ts` | `/opt/anexomail/src/index.ts` | main entry (mount order) |
| `routes/integrations.ts` | `/opt/anexomail/src/routes/integrations.ts` | 22 |
| `routes/settings.ts` | `/opt/anexomail/src/routes/settings.ts` | 23 |

## Env naam (Server 2 par asli naam)

Supabase #4 ke naam **`SUPABASE4_URL`** aur **`SUPABASE4_SERVICE_ROLE_KEY`** hain.
Nayi file mein hamesha yeh naam pehle aur `SUPABASE_URL` fallback ho.
Aur `createClient` boot par throw na kare — warna poora Brain crash hota hai
(port 3100 dead, curl `000`). Missing env = sirf us router ka `503`.

## Copy + restart tareeqa

### 1) Main entry overwrite (mount order critical)

```bash
cd /opt/anexomail
cp src/index.ts src/index.ts.bak.$(date +%s)
nano /opt/anexomail/src/index.ts   # select all -> paste repo/server/index.ts -> Ctrl+O, Ctrl+X
pm2 restart anexomail-leo && sleep 3
```

### 2) Phase 22 — Integrations Platform

```bash
cd /opt/anexomail
cp src/routes/integrations.ts src/routes/integrations.ts.bak.$(date +%s)
nano /opt/anexomail/src/routes/integrations.ts   # select all -> paste repo/server/routes/integrations.ts -> Ctrl+O, Ctrl+X
pm2 restart anexomail-leo && sleep 3
for p in providers connections migrations delivery/health exports leo-actions; do
  printf "/api/integrations/%s -> " "$p"
  curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:3100/api/integrations/$p"
done
```

### 3) Phase 23 — Settings Center

```bash
cd /opt/anexomail
cp src/routes/settings.ts src/routes/settings.ts.bak.$(date +%s)
nano /opt/anexomail/src/routes/settings.ts   # select all -> paste repo/server/routes/settings.ts -> Ctrl+O, Ctrl+X
pm2 restart anexomail-leo && sleep 3
for p in list save history blast-radius drift scheduled simulate explain revert; do
  printf "/api/settings/%s -> " "$p"
  curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:3100/api/settings/$p"
done
printf "/api/founder/settings/overview -> "
curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:3100/api/founder/settings/overview"
```

### 4) Phase 25 — Admin Center

```bash
cd /opt/anexomail
cp src/routes/admin.ts src/routes/admin.ts.bak.$(date +%s) 2>/dev/null
nano /opt/anexomail/src/routes/admin.ts   # select all -> paste repo/server/routes/admin.ts -> Ctrl+O, Ctrl+X
# phir src/index.ts bhi repo/server/index.ts se overwrite karo (admin mount uske andar hai)
pm2 restart anexomail-leo && sleep 3
for p in health storage incidents monitoring logs reports diagnostics; do
  printf "/api/admin/%s -> " "$p"
  curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:3100/api/admin/$p"
done
printf "/api/founder/admin/overview -> "
curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:3100/api/founder/admin/overview"
```

SQL: `sql/phase25_admin.sql` (Supabase #4 mein chalao).

`401` = green (guarded). `200` = public/health ok. `000` = server down. `404` = mount missing.
